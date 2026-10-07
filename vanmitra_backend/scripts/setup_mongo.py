"""
Set up MongoDB collections and indexes for VanMitra.

    python -m scripts.setup_mongo

Safe to run multiple times: existing collections and indexes are kept.
"""

from app.db import ensure_indexes, get_database


def main() -> None:
    db = get_database()
    print("Ensuring collections and indexes...")
    made = ensure_indexes(db)
    print(f"Done. Processed indexes: {len(made)}")


if __name__ == "__main__":
    main()
