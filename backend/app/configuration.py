"""Configuração validada antes de aceitar tráfego."""

import os


def production():
    value = os.getenv("APP_ENV", "development").strip().lower()
    if value not in {"development", "test", "production"}:
        raise RuntimeError("APP_ENV deve ser development, test ou production.")
    return value == "production"


def secure_transport():
    setting = os.getenv("REQUIRE_HTTPS", "false").lower()
    if setting not in {"true", "false"}:
        raise RuntimeError("REQUIRE_HTTPS deve ser true ou false.")
    return production() or setting == "true"


def validate_settings():
    secure_transport()
    try:
        minutes = int(os.getenv("BOOKING_HOLD_MINUTES", "30"))
        port = int(os.getenv("SMTP_PORT", "587"))
    except ValueError:
        raise RuntimeError(
            "Configure prazo da reserva e porta SMTP como números inteiros."
        ) from None
    if not 5 <= minutes <= 1440 or not 1 <= port <= 65535:
        raise RuntimeError(
            "Prazo de reserva ou porta SMTP fora do intervalo permitido."
        )


def trusted_hosts():
    hosts = [
        item.strip()
        for item in os.getenv("TRUSTED_HOSTS", "").split(",")
        if item.strip()
    ]
    if production() and (not hosts or "*" in hosts):
        raise RuntimeError(
            "Produção exige TRUSTED_HOSTS explícito, sem curinga global."
        )
    return hosts
