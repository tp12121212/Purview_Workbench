from dataclasses import dataclass


@dataclass
class DatabaseConfig:
    dsn: str = "postgresql://placeholder"


def get_database_config() -> DatabaseConfig:
    return DatabaseConfig()
