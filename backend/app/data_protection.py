"""Authenticated encryption for private values; the key never belongs to the database."""

import base64
import hashlib
import hmac
import os
import secrets
from functools import lru_cache
from pathlib import Path

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from sqlalchemy import Text, inspect, text
from sqlalchemy.engine import Connection
from sqlalchemy.types import TypeDecorator

PREFIX = "enc:v1:"
DEFAULT_KEY_FILE = (
    Path(__file__).resolve().parents[1] / "secrets" / "data-encryption.key"
)


class DataProtectionError(RuntimeError):
    pass


@lru_cache(maxsize=8)
def _configured_key(encoded, path):
    if not encoded:
        try:
            encoded = Path(path).read_text(encoding="ascii").strip()
        except (OSError, UnicodeError):
            raise DataProtectionError(
                "Chave de proteção ausente. Configure DATA_ENCRYPTION_KEY ou DATA_ENCRYPTION_KEY_FILE; preserve a chave existente."
            ) from None
    try:
        key = base64.b64decode(encoded, altchars=b"-_", validate=True)
        if len(key) != 32:
            raise ValueError()
    except (ValueError, TypeError):
        raise DataProtectionError(
            "Chave de proteção inválida: informe 32 bytes em base64url. A chave não será substituída automaticamente."
        ) from None
    return key


def encryption_key():
    return _configured_key(
        os.getenv("DATA_ENCRYPTION_KEY", ""),
        os.getenv("DATA_ENCRYPTION_KEY_FILE", str(DEFAULT_KEY_FILE)),
    )


def encrypt(value, purpose):
    if value is None:
        return None
    nonce = secrets.token_bytes(12)
    payload = AESGCM(encryption_key()).encrypt(
        nonce, str(value).encode("utf-8"), purpose.encode("ascii")
    )
    return PREFIX + base64.urlsafe_b64encode(nonce + payload).decode("ascii")


def decrypt(value, purpose):
    if value is None:
        return None
    try:
        if not value.startswith(PREFIX):
            raise ValueError()
        payload = base64.b64decode(value[len(PREFIX) :], altchars=b"-_", validate=True)
        return (
            AESGCM(encryption_key())
            .decrypt(payload[:12], payload[12:], purpose.encode("ascii"))
            .decode("utf-8")
        )
    except (InvalidTag, ValueError, TypeError, UnicodeError):
        raise DataProtectionError(
            "Não foi possível autenticar os dados protegidos. Verifique a chave original e a integridade do banco; nenhum valor será substituído."
        ) from None


def private_digest(value, purpose):
    lookup_key = hmac.new(
        encryption_key(), b"ze-resolve:blind-index:v1", hashlib.sha256
    ).digest()
    return hmac.new(
        lookup_key, (purpose + "\0" + value).encode("utf-8"), hashlib.sha256
    ).hexdigest()


def email_lookup(email):
    return private_digest(str(email).strip().lower(), "email")


class ProtectedText(TypeDecorator):
    impl = Text
    cache_ok = True

    def __init__(self, purpose, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.purpose = purpose

    def process_bind_param(self, value, dialect):
        return encrypt(value, self.purpose)

    def process_result_value(self, value, dialect):
        return decrypt(value, self.purpose)


class ProtectedFloat(ProtectedText):
    cache_ok = True

    def process_result_value(self, value, dialect):
        result = super().process_result_value(value, dialect)
        return float(result) if result is not None else None


PRIVATE_COLUMNS = {
    "users": ("name", "email", "phone"),
    "addresses": (
        "label",
        "postal_code",
        "street",
        "number",
        "complement",
        "neighborhood",
        "city",
        "state",
    ),
    "service_requests": ("title", "description", "address"),
    "messages": ("body",),
    "push_devices": ("token",),
}


def migrate_private_data(engine):
    """Additive, transactional encryption upgrade. Never deletes application records."""
    encryption_key()
    from .database import schema_transaction

    tables = set(inspect(engine).get_table_names())
    with schema_transaction(engine) as connection:
        if engine.dialect.name == "sqlite":
            if not isinstance(engine, Connection):
                connection.exec_driver_sql("BEGIN IMMEDIATE")
            connection.exec_driver_sql("PRAGMA secure_delete=ON")
        connection.execute(
            text(
                "CREATE TABLE IF NOT EXISTS data_protection_metadata (key VARCHAR(64) PRIMARY KEY, value TEXT NOT NULL)"
            )
        )
        marker = connection.execute(
            text("SELECT value FROM data_protection_metadata WHERE key='key_check'")
        ).scalar()
        if marker is not None:
            if decrypt(marker, "metadata.key_check") != "ze-resolve:data-protection:v1":
                raise DataProtectionError(
                    "Chave de proteção incompatível com este banco."
                )
            return
        if (
            "users" in tables
            and connection.execute(
                text("SELECT 1 FROM users WHERE email LIKE 'enc:v1:%' LIMIT 1")
            ).first()
        ):
            raise DataProtectionError(
                "O banco contém dados cifrados, mas o marcador de proteção está ausente. Restaure um backup completo; os dados não serão cifrados novamente."
            )
        additions = {
            "users": {"email_lookup": "VARCHAR(64)"},
            "professionals": {
                "public_name": "VARCHAR(100)",
                "latitude_private": "TEXT",
                "longitude_private": "TEXT",
            },
        }
        for table, fields in additions.items():
            if table not in tables:
                continue
            existing = {
                column["name"] for column in inspect(connection).get_columns(table)
            }
            for column, sql_type in fields.items():
                if column not in existing:
                    connection.execute(
                        text(f"ALTER TABLE {table} ADD COLUMN {column} {sql_type}")
                    )
        names = {}
        for table, columns in PRIVATE_COLUMNS.items():
            if table not in tables:
                continue
            identity = "digest" if table == "push_devices" else "id"
            rows = connection.execute(
                text(f"SELECT {identity}, {', '.join(columns)} FROM {table}")
            ).mappings()
            updates = []
            for row in rows:
                values = {"row_id": row[identity]}
                values.update(
                    {
                        column: encrypt(row[column], f"{table}.{column}")
                        for column in columns
                    }
                )
                if table == "users":
                    values["email_lookup"] = email_lookup(row["email"])
                    names[row[identity]] = row["name"]
                updates.append(values)
            if updates:
                fields = [key for key in updates[0] if key != "row_id"]
                connection.execute(
                    text(
                        f"UPDATE {table} SET "
                        + ", ".join(f"{field}=:{field}" for field in fields)
                        + f" WHERE {identity}=:row_id"
                    ),
                    updates,
                )
        if "users" in tables:
            connection.execute(
                text(
                    "CREATE UNIQUE INDEX IF NOT EXISTS ix_users_email_lookup ON users (email_lookup)"
                )
            )
        if "professionals" in tables:
            rows = connection.execute(
                text(
                    "SELECT id, latitude, longitude, latitude_private, longitude_private FROM professionals"
                )
            ).mappings()
            updates = []
            for row in rows:
                lat = (
                    decrypt(row["latitude_private"], "professionals.latitude")
                    if row["latitude_private"]
                    else row["latitude"]
                )
                lon = (
                    decrypt(row["longitude_private"], "professionals.longitude")
                    if row["longitude_private"]
                    else row["longitude"]
                )
                lat, lon = (float(lat) if lat is not None else None), (
                    float(lon) if lon is not None else None
                )
                updates.append(
                    {
                        "id": row["id"],
                        "public_name": names[row["id"]],
                        "latitude": round(lat, 2) if lat is not None else None,
                        "longitude": round(lon, 2) if lon is not None else None,
                        "latitude_private": row["latitude_private"]
                        or encrypt(lat, "professionals.latitude"),
                        "longitude_private": row["longitude_private"]
                        or encrypt(lon, "professionals.longitude"),
                    }
                )
            if updates:
                connection.execute(
                    text(
                        "UPDATE professionals SET public_name=:public_name, latitude=:latitude, longitude=:longitude, latitude_private=:latitude_private, longitude_private=:longitude_private WHERE id=:id"
                    ),
                    updates,
                )
        connection.execute(
            text(
                "INSERT INTO data_protection_metadata (key,value) VALUES ('key_check',:value)"
            ),
            {"value": encrypt("ze-resolve:data-protection:v1", "metadata.key_check")},
        )
