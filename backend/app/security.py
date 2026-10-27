import bcrypt


class Passwords:
    """bcrypt com custo 12 e salt individual; nunca trunca a senha."""

    @staticmethod
    def hash(password: str) -> str:
        return bcrypt.hashpw(
            password.encode("utf-8"), bcrypt.gensalt(rounds=12)
        ).decode("ascii")

    @staticmethod
    def verify(password: str, encoded: str) -> bool:
        try:
            return bcrypt.checkpw(password.encode("utf-8"), encoded.encode("ascii"))
        except ValueError:
            return False


passwords = Passwords()
