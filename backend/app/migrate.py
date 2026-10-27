"""Atualização aditiva do SQLite local, preservando registros existentes."""

from .database import database_url, initialize_schema, make_database
from .reference_data import populate_categories


def main():
    engine, sessions = make_database(database_url())
    initialize_schema(engine)
    with sessions.begin() as db:
        populate_categories(db)
    engine.dispose()
    print("SQLite atualizado; registros existentes preservados.")


if __name__ == "__main__":
    main()
