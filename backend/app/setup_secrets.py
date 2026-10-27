"""Prepare uma chave de cifragem local sem sobrescrever chaves existentes."""

import base64
import secrets
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[1]
    target = root / "secrets" / "data-encryption.key"
    target.parent.mkdir(exist_ok=True)
    if target.exists():
        print("A chave local já existe e foi preservada.")
        return
    with target.open("xb") as stream:
        stream.write(base64.urlsafe_b64encode(secrets.token_bytes(32)))
    print(
        "Chave local criada em backend/secrets/data-encryption.key. Guarde uma cópia privada; nunca envie ao Git."
    )


if __name__ == "__main__":
    main()
