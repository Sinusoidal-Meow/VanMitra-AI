"""The database dependency: one MongoDB unit of work per request (see app/mongo.py)."""

from .mongo import Store, ensure_indexes, get_client, get_database, get_db

__all__ = ["Store", "ensure_indexes", "get_client", "get_database", "get_db"]
