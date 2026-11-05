"""Gera a autoridade certificadora local e o certificado TLS da API.

Execute: python -m app.tls_setup [--force]

Arquivos em backend/secrets/tls/ (fora do Git):
- ca.crt / ca.key: autoridade certificadora (AC) local do Zé Resolve.
- server.crt / server.key: certificado da API, assinado pela AC, válido
  para localhost, 127.0.0.1 e 10.0.2.2 (emulador Android).

O aplicativo confia somente em ca.crt (fixação de certificado). A chave
privada da AC nunca sai desta pasta e nunca é enviada ao aplicativo.
"""

import argparse
import hashlib
import ipaddress
from datetime import datetime, timedelta, timezone
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID

DEFAULT_DIR = Path(__file__).resolve().parent.parent / "secrets" / "tls"
HOSTS = ["localhost"]
ADDRESSES = ["127.0.0.1", "10.0.2.2"]


def _name(common_name):
    return x509.Name(
        [
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Zé Resolve"),
            x509.NameAttribute(NameOID.COMMON_NAME, common_name),
        ]
    )


def _write_key(path, key):
    path.write_bytes(
        key.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8,
            serialization.NoEncryption(),
        )
    )


def generate(directory=DEFAULT_DIR, *, force=False, ca_name="Zé Resolve AC local"):
    directory = Path(directory)
    files = [directory / n for n in ("ca.crt", "ca.key", "server.crt", "server.key")]
    if not force and any(f.exists() for f in files):
        raise RuntimeError(
            "Certificados já existem. Use --force para substituí-los "
            "(o aplicativo precisará ser instalado de novo com a nova AC)."
        )
    directory.mkdir(parents=True, exist_ok=True)
    now = datetime.now(timezone.utc) - timedelta(minutes=5)

    ca_key = ec.generate_private_key(ec.SECP256R1())
    ca_cert = (
        x509.CertificateBuilder()
        .subject_name(_name(ca_name))
        .issuer_name(_name(ca_name))
        .public_key(ca_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now)
        .not_valid_after(now + timedelta(days=730))
        .add_extension(x509.BasicConstraints(ca=True, path_length=0), critical=True)
        .add_extension(
            x509.KeyUsage(
                digital_signature=False,
                content_commitment=False,
                key_encipherment=False,
                data_encipherment=False,
                key_agreement=False,
                key_cert_sign=True,
                crl_sign=True,
                encipher_only=False,
                decipher_only=False,
            ),
            critical=True,
        )
        .add_extension(
            x509.SubjectKeyIdentifier.from_public_key(ca_key.public_key()),
            critical=False,
        )
        .sign(ca_key, hashes.SHA256())
    )

    server_key = ec.generate_private_key(ec.SECP256R1())
    names = [x509.DNSName(h) for h in HOSTS] + [
        x509.IPAddress(ipaddress.ip_address(a)) for a in ADDRESSES
    ]
    server_cert = (
        x509.CertificateBuilder()
        .subject_name(_name("API Zé Resolve"))
        .issuer_name(ca_cert.subject)
        .public_key(server_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now)
        .not_valid_after(now + timedelta(days=397))
        .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
        .add_extension(x509.SubjectAlternativeName(names), critical=False)
        .add_extension(
            x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]), critical=False
        )
        .add_extension(
            x509.AuthorityKeyIdentifier.from_issuer_public_key(ca_key.public_key()),
            critical=False,
        )
        .sign(ca_key, hashes.SHA256())
    )

    (directory / "ca.crt").write_bytes(ca_cert.public_bytes(serialization.Encoding.PEM))
    _write_key(directory / "ca.key", ca_key)
    (directory / "server.crt").write_bytes(
        server_cert.public_bytes(serialization.Encoding.PEM)
    )
    _write_key(directory / "server.key", server_key)
    return fingerprint(directory / "ca.crt")


def fingerprint(certificate_path):
    cert = x509.load_pem_x509_certificate(Path(certificate_path).read_bytes())
    digest = hashlib.sha256(cert.public_bytes(serialization.Encoding.DER)).hexdigest()
    return ":".join(digest[i : i + 2] for i in range(0, len(digest), 2)).upper()


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--dir", default=str(DEFAULT_DIR))
    args = parser.parse_args()
    print("AC gerada. Impressão digital SHA-256:", generate(args.dir, force=args.force))


if __name__ == "__main__":
    main()
