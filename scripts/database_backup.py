"""Backup e restauração do SQLite local, sem sobrescrever arquivos existentes."""

import argparse
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))

from app.backup import backup, restore
from app.database import database_url, normalize_database_url


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("backup", "restore"))
    parser.add_argument("--file", type=Path, required=True)
    parser.add_argument("--target-file", type=Path)
    args = parser.parse_args()
    environment = ROOT / "backend/.env"
    if environment.exists():
        for line in environment.read_text(encoding="utf-8").splitlines():
            if line.strip() and not line.lstrip().startswith("#"):
                key, value = line.split("=", 1)
                os.environ[key.strip()] = value.strip().strip('"').strip("'")
    if args.operation == "backup":
        path = normalize_database_url(database_url()).database
        if not path or path == ":memory:":
            raise RuntimeError("Backup exige um arquivo SQLite persistente.")
        backup(path, args.file)
    else:
        if not args.target_file:
            parser.error("A restauração exige --target-file com um caminho novo.")
        restore(args.file, args.target_file)
    print(
        "Operação concluída; integridade e chave verificadas, sem sobrescrever dados."
    )


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print(
            "Operação não concluída. Confira os caminhos, o manifesto e a chave original.",
            file=sys.stderr,
        )
        raise SystemExit(1) from None
