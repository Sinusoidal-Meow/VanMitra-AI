"""
Seed demo data for local development: Ozhar village, its Gram Sabha and one
demo user per role. Safe to run twice (existing rows are left alone).

    python -m scripts.seed_demo

Run it yourself, after `alembic upgrade head`. It writes to VANMITRA_DATABASE_URL.
Demo phones are fake (9000000001-4). Every demo PIN is 123456: development only.
"""

import sys

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth.security import hash_pin
from app.config import get_settings
from app.db import get_engine
from app.models import AppUser, ConsolidationStatus, GramSabha, Role, UserRole, Village

DEMO_PIN = "123456"

DEMO_USERS: list[tuple[str, str, Role | None]] = [
    ("9000000001", "Demo Facilitator (NGO)", Role.FACILITATOR),
    ("9000000002", "Demo FRC Member", Role.FRC_MEMBER),
    ("9000000003", "Demo Gram Sabha Secretary", Role.GS_SECRETARY),
    ("9000000004", "Demo Admin (back-office)", None),
]


def seed(db: Session) -> None:
    village = db.scalar(
        select(Village).where(Village.name_en == "Ozhar", Village.taluka == "Jawhar")
    )
    if village is None:
        village = Village(
            name_mr="ओझर",
            name_en="Ozhar",
            gram_panchayat="Ozhar",  # TODO: confirm the Gram Panchayat name and LGD code
            taluka="Jawhar",
            district="Palghar",
            state="Maharashtra",
            consolidation_status=ConsolidationStatus.RECOGNISED,
        )
        db.add(village)
        db.flush()
        db.add(GramSabha(village_id=village.id))
        print(f"created village Ozhar ({village.id})")

    for phone, name, role in DEMO_USERS:
        user = db.scalar(select(AppUser).where(AppUser.phone == phone))
        if user is None:
            user = AppUser(
                phone=phone, name=name, pin_hash=hash_pin(DEMO_PIN), is_admin=role is None
            )
            db.add(user)
            db.flush()
            if role is not None:
                db.add(UserRole(user_id=user.id, village_id=village.id, role=role))
            print(f"created user {phone}  {name}")
        else:
            print(f"exists  user {phone}  {name}")

    db.commit()


def main() -> None:
    if get_settings().env == "production":
        sys.exit("Refusing to seed demo users in production.")
    with Session(get_engine()) as db:
        seed(db)
    print(f"\nDone. Log in with any demo phone and PIN {DEMO_PIN}.")


if __name__ == "__main__":
    main()
