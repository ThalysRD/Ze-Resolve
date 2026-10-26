"""Verifica arquivos locais elegíveis ao Git sem imprimir conteúdos sensíveis."""

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SIGNATURES = [
    re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE" + rb" KEY-----"),
    re.compile(rb'"private_key"\s*:\s*"-----BEGIN'),
    re.compile(rb"\bAKIA[0-9A-Z]{16}\b"),
    re.compile(rb"\b(?:ghp|glpat)_[A-Za-z0-9_-]{20,}\b"),
    re.compile(rb"\bpostgres(?:ql)?(?:\+psycopg)?://[^\s:/]+:[^\s@]{8,}@"),
]


def check():
    result = subprocess.run(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        cwd=ROOT,
        capture_output=True,
        check=True,
    )
    names = set(n.decode("utf-8") for n in result.stdout.split(b"\0") if n)
    failures = set()
    for name in names:
        path = ROOT / name
        if not path.is_file():
            continue
        parts = set(path.parts)
        forbidden = (
            path.name == ".env"
            or (path.name.startswith(".env.") and not path.name.endswith(".example"))
            or path.suffix.lower()
            in {".key", ".pem", ".p12", ".pfx", ".jks", ".keystore", ".db"}
            or "secrets" in parts
            or "firebase-admin" in path.name
            or path.name == "google-services.json"
            or path.name == "key.properties"
        )
        if forbidden:
            failures.add(name)
            continue
        if path.stat().st_size > 5_000_000:
            continue
        content = path.read_bytes()
        if any(pattern.search(content) for pattern in SIGNATURES):
            failures.add(name)
    if failures:
        print("Arquivos bloqueados pela verificação de segredos:")
        for name in sorted(failures):
            print(name)
        raise SystemExit(1)
    print(
        "Verificação concluída: nenhum segredo detectado nos arquivos elegíveis ao Git."
    )


if __name__ == "__main__":
    check()
