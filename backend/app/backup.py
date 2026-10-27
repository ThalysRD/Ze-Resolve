"""Backups consistentes do SQLite, incluindo dados ainda presentes no WAL."""

import hashlib
import json
from contextlib import closing
from pathlib import Path
import sqlite3

from .data_protection import decrypt


def readonly(path):
    return sqlite3.connect(Path(path).resolve().as_uri() + "?mode=ro", uri=True)


def validate(connection):
    if connection.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
        raise RuntimeError("O arquivo SQLite não passou na verificação de integridade.")
    if connection.execute("PRAGMA foreign_key_check").fetchall():
        raise RuntimeError("O banco contém relacionamentos inválidos.")
    marker = connection.execute(
        "SELECT value FROM data_protection_metadata WHERE key='key_check'"
    ).fetchone()
    if (
        not marker
        or decrypt(marker[0], "metadata.key_check") != "ze-resolve:data-protection:v1"
    ):
        raise RuntimeError("Preserve a chave original de proteção dos dados.")


def backup(source, target):
    source, target = Path(source).resolve(), Path(target).resolve()
    if target.exists() or target.with_suffix(target.suffix + ".json").exists():
        raise RuntimeError("Destino existente; nenhum arquivo será sobrescrito.")
    target.parent.mkdir(parents=True, exist_ok=True)
    with closing(readonly(source)) as origin:
        validate(origin)
        with target.open("xb"):
            pass
        with closing(sqlite3.connect(target)) as destination:
            origin.backup(destination)
            validate(destination)
    manifest = {
        "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        "format": "sqlite",
    }
    target.with_suffix(target.suffix + ".json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )


def restore(source, target):
    source = Path(source).resolve()
    manifest = json.loads(
        source.with_suffix(source.suffix + ".json").read_text(encoding="utf-8")
    )
    if hashlib.sha256(source.read_bytes()).hexdigest() != manifest["sha256"]:
        raise RuntimeError("O backup não confere com o manifesto.")
    backup(source, target)
