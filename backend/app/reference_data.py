"""Catálogo necessário ao produto, sem usuários ou credenciais fictícias."""

from sqlalchemy import select

from .models import Category

CATEGORY_NAMES = (
    "Eletricista",
    "Encanador",
    "Pintor",
    "Marceneiro",
    "Informática",
    "Mudanças",
    "Montagem",
    "Contabilidade",
)


def populate_categories(db):
    existing = set(db.scalars(select(Category.name)))
    for name in CATEGORY_NAMES:
        if name not in existing:
            db.add(Category(name=name))
    db.flush()
