"""Atividade 4: comunicação segura (HTTPS com AC fixada) e logs sem localização.

Cada teste sobe a API de verdade com o uvicorn, como na apresentação.
"""

import os
import socket
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import pytest
from cryptography import x509
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import ExtensionOID

from app.tls_setup import generate

BACKEND = Path(__file__).resolve().parent.parent
LOCATION = "latitude=-5.7945&longitude=-35.2110"


def free_port():
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


class Server:
    def __init__(self, tls_dir=None, access_log=False, require_https=False):
        self.port = free_port()
        args = [sys.executable, "-m", "uvicorn", "app.main:app"]
        args += ["--host", "127.0.0.1", "--port", str(self.port)]
        if not access_log:
            args.append("--no-access-log")
        if tls_dir:
            args += ["--ssl-certfile", str(Path(tls_dir) / "server.crt")]
            args += ["--ssl-keyfile", str(Path(tls_dir) / "server.key")]
        env = dict(os.environ, DATABASE_URL="sqlite:///:memory:", APP_ENV="test")
        env["REQUIRE_HTTPS"] = "true" if require_https else "false"
        env["PYTHONUNBUFFERED"] = "1"
        self.process = subprocess.Popen(
            args,
            cwd=BACKEND,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            if self.process.poll() is not None:
                raise RuntimeError("A API não iniciou:\n" + self.process.stdout.read())
            with socket.socket() as probe:
                if probe.connect_ex(("127.0.0.1", self.port)) == 0:
                    return
            time.sleep(0.2)
        self.stop()
        raise RuntimeError("A API não abriu a porta a tempo.")

    def stop(self):
        if self.process.poll() is None:
            self.process.terminate()
        try:
            return self.process.communicate(timeout=15)[0]
        except subprocess.TimeoutExpired:
            self.process.kill()
            return self.process.communicate()[0]

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.stop()


def pinned_context(ca_file):
    """Mesma regra do aplicativo: confiar somente na AC do Zé Resolve."""
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_verify_locations(cafile=str(ca_file))
    return context


def get(url, context=None):
    with urllib.request.urlopen(url, context=context, timeout=10) as response:
        return response.status, dict(response.headers), response.read()


@pytest.fixture(scope="module")
def tls(tmp_path_factory):
    directory = tmp_path_factory.mktemp("tls")
    generate(directory)
    return directory


def test_certificado_da_api_assinado_pela_ac_e_valido_para_o_app(tls):
    ca = x509.load_pem_x509_certificate((tls / "ca.crt").read_bytes())
    server = x509.load_pem_x509_certificate((tls / "server.crt").read_bytes())
    assert server.issuer == ca.subject
    ca.public_key().verify(
        server.signature,
        server.tbs_certificate_bytes,
        ec.ECDSA(server.signature_hash_algorithm),
    )
    names = server.extensions.get_extension_for_oid(
        ExtensionOID.SUBJECT_ALTERNATIVE_NAME
    ).value
    addresses = {str(ip) for ip in names.get_values_for_type(x509.IPAddress)}
    assert {"127.0.0.1", "10.0.2.2"} <= addresses
    assert ca.extensions.get_extension_for_oid(
        ExtensionOID.BASIC_CONSTRAINTS
    ).value.ca
    assert not server.extensions.get_extension_for_oid(
        ExtensionOID.BASIC_CONSTRAINTS
    ).value.ca


def test_https_com_ac_fixada_funciona_e_envia_hsts(tls):
    with Server(tls, require_https=True) as api:
        status, headers, body = get(
            f"https://127.0.0.1:{api.port}/health", pinned_context(tls / "ca.crt")
        )
    assert status == 200 and b"ok" in body
    assert headers["strict-transport-security"].startswith("max-age=")


def test_http_sem_criptografia_e_recusado(tls):
    with Server(tls, require_https=True) as api:
        with pytest.raises((urllib.error.URLError, ConnectionError, OSError)):
            get(f"http://127.0.0.1:{api.port}/health")


def test_api_sem_tls_recusa_trafego_quando_https_e_obrigatorio():
    with Server(require_https=True) as api:
        with pytest.raises(urllib.error.HTTPError) as refused:
            get(f"http://127.0.0.1:{api.port}/health")
    assert refused.value.code == 400


def test_certificado_falso_de_atacante_e_rejeitado(tls, tmp_path):
    """Simula um "homem no meio": servidor com certificado de outra AC."""
    attacker = tmp_path / "atacante"
    generate(attacker, ca_name="AC do atacante")
    with Server(attacker) as impostor:
        with pytest.raises(urllib.error.URLError) as refused:
            get(
                f"https://127.0.0.1:{impostor.port}/health",
                pinned_context(tls / "ca.crt"),
            )
    assert isinstance(refused.value.reason, ssl.SSLCertVerificationError)


def test_log_de_acesso_nao_grava_a_localizacao_do_usuario():
    with Server(access_log=True) as api:
        try:
            get(f"http://127.0.0.1:{api.port}/professionals?{LOCATION}")
        except urllib.error.HTTPError:
            pass
        output = api.stop()
    assert "GET /professionals" in output
    assert "latitude" not in output and "-5.7945" not in output
