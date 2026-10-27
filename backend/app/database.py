import os
from contextlib import contextmanager
from pathlib import Path

from sqlalchemy import create_engine, event, inspect, text
from sqlalchemy.engine import URL, Connection, make_url
from sqlalchemy.orm import DeclarativeBase, sessionmaker
from sqlalchemy.pool import StaticPool


class Base(DeclarativeBase):
    pass


def normalize_database_url(url: str | URL) -> URL:
    parsed = make_url(url)
    if parsed.drivername != "sqlite":
        raise ValueError("A apresentação local utiliza SQLite com SQLAlchemy.")
    return parsed


def make_database(url: str | URL):
    parsed = normalize_database_url(url)
    if parsed.database and parsed.database != ":memory:":
        Path(parsed.database).parent.mkdir(parents=True, exist_ok=True)
    engine = create_engine(
        parsed,
        pool_pre_ping=True,
        hide_parameters=True,
        connect_args={"check_same_thread": False, "timeout": 15},
        **(
            {"poolclass": StaticPool}
            if parsed.database in {None, "", ":memory:"}
            else {}
        ),
    )

    @event.listens_for(engine, "connect")
    def enable_integrity(connection, _):
        connection.execute("PRAGMA foreign_keys=ON")
        connection.execute("PRAGMA busy_timeout=15000")
        connection.execute("PRAGMA journal_mode=WAL")

    return engine, sessionmaker(bind=engine, expire_on_commit=False)


DEFAULT_DATABASE = Path(__file__).resolve().parents[1] / "data" / "apresentacao.db"


def database_url():
    """Arquivo persistente local; testes podem escolher outro SQLite explícito."""
    configured = os.getenv("DATABASE_URL")
    if configured:
        normalize_database_url(configured)
        return configured
    return "sqlite:///" + DEFAULT_DATABASE.as_posix()


@contextmanager
def schema_transaction(bind):
    """Reutilize a transação de inicialização sem abrir outra conexão do pool."""
    if isinstance(bind, Connection):
        yield bind
    else:
        with bind.begin() as connection:
            yield connection


def initialize_schema(engine):
    """Serialize criação e upgrades numa única transação, inclusive entre workers."""
    with schema_transaction(engine) as connection:
        connection.exec_driver_sql("BEGIN IMMEDIATE")
        Base.metadata.create_all(connection)
        migrate_location(connection)
        migrate_agenda(connection)
        migrate_production_controls(connection)
        for version in ("20261016_agenda", "20261025_production"):
            connection.execute(
                text(
                    "INSERT INTO schema_revisions (version, applied_at) VALUES (:version, CURRENT_TIMESTAMP) ON CONFLICT (version) DO NOTHING"
                ),
                {"version": version},
            )
        connection.execute(
            text(
                "INSERT INTO data_protection_metadata (key, value) VALUES ('schema_revision', '20261025') ON CONFLICT (key) DO UPDATE SET value = '20261025'"
            )
        )


def validate_schema(engine):
    from .data_protection import decrypt, DataProtectionError

    with engine.connect() as connection:
        revision = connection.scalar(
            text(
                "SELECT value FROM data_protection_metadata WHERE key = 'schema_revision'"
            )
        )
        if revision != "20261025":
            raise RuntimeError(
                "Execute python -m app.migrate antes de iniciar esta versão em produção."
            )
        marker = connection.scalar(
            text("SELECT value FROM data_protection_metadata WHERE key='key_check'")
        )
        if (
            not marker
            or decrypt(marker, "metadata.key_check") != "ze-resolve:data-protection:v1"
        ):
            raise DataProtectionError("Chave de proteção incompatível com este banco.")
        if not connection.scalar(text("SELECT COUNT(*) FROM categories")):
            raise RuntimeError("Prepare o catálogo usando python -m app.migrate.")


def migrate_production_controls(connection):
    additions = {
        "users": {
            "is_active": "BOOLEAN NOT NULL DEFAULT TRUE",
            "email_verified_at": "TIMESTAMP WITH TIME ZONE",
            "closed_at": "TIMESTAMP WITH TIME ZONE",
            "terms_version": "VARCHAR(30)",
            "terms_accepted_at": "TIMESTAMP WITH TIME ZONE",
        },
        "service_requests": {
            "hold_expires_at": "TIMESTAMP WITH TIME ZONE",
            "cancellation_reason": "VARCHAR(300)",
            "cancelled_by": "INTEGER REFERENCES users(id)",
        },
    }
    for table_name, fields in additions.items():
        columns = {
            column["name"] for column in inspect(connection).get_columns(table_name)
        }
        for name, sql_type in fields.items():
            if name not in columns:
                connection.execute(
                    text(f"ALTER TABLE {table_name} ADD COLUMN {name} {sql_type}")
                )
    connection.execute(
        text(
            "CREATE INDEX IF NOT EXISTS ix_service_requests_hold_expires_at ON service_requests (hold_expires_at)"
        )
    )


def migrate_location(engine):
    """Migração aditiva e idempotente: preserva perfis, sessões e mensagens existentes."""
    columns = {c["name"] for c in inspect(engine).get_columns("professionals")}
    additions = {
        "latitude": "FLOAT",
        "longitude": "FLOAT",
        "is_available": "BOOLEAN NOT NULL DEFAULT TRUE",
    }
    with schema_transaction(engine) as connection:
        for name, sql_type in additions.items():
            if name not in columns:
                connection.execute(
                    text(f"ALTER TABLE professionals ADD COLUMN {name} {sql_type}")
                )
        connection.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_professionals_latitude ON professionals (latitude)"
            )
        )
    request_columns = {
        c["name"] for c in inspect(engine).get_columns("service_requests")
    }
    if "duration_minutes" not in request_columns:
        with schema_transaction(engine) as connection:
            connection.execute(
                text(
                    "ALTER TABLE service_requests ADD COLUMN duration_minutes INTEGER NOT NULL DEFAULT 60"
                )
            )
    from .data_protection import migrate_private_data

    migrate_private_data(engine)


def migrate_agenda(engine):
    """Acrescente agenda e valor de visita sem reinterpretar preços antigos."""
    additions = {
        "professionals": {"visit_fee_cents": "INTEGER"},
        "service_requests": {
            "slot_id": "INTEGER REFERENCES availability_slots(id)",
            "visit_fee_cents": "INTEGER",
        },
    }
    with schema_transaction(engine) as connection:
        for table_name, fields in additions.items():
            columns = {c["name"] for c in inspect(connection).get_columns(table_name)}
            for name, sql_type in fields.items():
                if name not in columns:
                    connection.execute(
                        text(f"ALTER TABLE {table_name} ADD COLUMN {name} {sql_type}")
                    )
        connection.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_service_requests_occupied_slot "
                "ON service_requests (slot_id) WHERE slot_id IS NOT NULL "
                "AND status IN ('pendente','aceita','em_andamento','concluida')"
            )
        )
