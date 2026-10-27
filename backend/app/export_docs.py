"""Exporta o contrato e DDL sem consultar/excluir dados do banco."""

import json
from pathlib import Path

from sqlalchemy.dialects.sqlite import dialect
from sqlalchemy.schema import CreateIndex, CreateTable

from .database import Base
from .main import app


def export():
    target = Path(__file__).resolve().parents[2] / "docs"
    target.mkdir(exist_ok=True)
    (target / "openapi.json").write_text(
        json.dumps(app.openapi(), indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    statements = [
        "-- Schema inicial SQLite, gerado do modelo SQLAlchemy. Não execute sobre um banco já populado."
    ]
    for table in Base.metadata.sorted_tables:
        statements.append(
            str(CreateTable(table).compile(dialect=dialect())).strip() + ";"
        )
        for index in sorted(table.indexes, key=lambda idx: idx.name):
            statements.append(str(CreateIndex(index).compile(dialect=dialect())) + ";")
    statements.append(
        "-- Marcador auxiliar autenticado de migração; nunca contém a chave.\nCREATE TABLE data_protection_metadata (key VARCHAR(64) PRIMARY KEY, value TEXT NOT NULL);"
    )
    (target / "schema.sql").write_text("\n\n".join(statements) + "\n", encoding="utf-8")
    print("Exportados docs/openapi.json e docs/schema.sql")


if __name__ == "__main__":
    export()
