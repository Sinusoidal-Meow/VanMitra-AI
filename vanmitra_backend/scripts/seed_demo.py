"""
Seed demo data for local development: Ozhar village (Jawhar, Palghar), its Gram Sabha,
five fictional members and one demo login for every role of the three levels.
Safe to run again: existing rows are kept, demo users get their name and role synced.

    python -m scripts.seed_demo

Run it yourself, after `alembic upgrade head`. It writes to VANMITRA_DATABASE_URL.
Demo phones are fake (9000000001-8). Every demo PIN is 123456: development only.
"""

import sys

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth.security import hash_pin
from app.config import get_settings
from app.db import get_engine
from app.models import (
    AppUser,
    ConsolidationStatus,
    Gender,
    GramSabha,
    GsMember,
    MemberCategory,
    Role,
    UserRole,
    Village,
)

DEMO_PIN = "123456"
TALUKA, DISTRICT = "Jawhar", "Palghar"

# (phone, name, role or None for admin). Village roles get Ozhar; the SDO gets
# Jawhar/Palghar. District-level logins live on the district website, not here.
DEMO_USERS: list[tuple[str, str, Role | None]] = [
    ("9000000001", "Demo Village User", Role.VILLAGER),
    ("9000000002", "Demo Village User 2", Role.VILLAGER),
    ("9000000003", "Demo Gram Sabha (Ozhar)", Role.GRAM_SABHA),
    ("9000000004", "Demo Admin (back-office)", None),
    ("9000000005", "Demo SDO (Jawhar)", Role.SDO),
]

# Fictional demo members for the Form C member sheet (item 5).
DEMO_MEMBERS: list[tuple[str, Gender, MemberCategory]] = [
    ("Demo Member 1", Gender.FEMALE, MemberCategory.ST),
    ("Demo Member 2", Gender.MALE, MemberCategory.ST),
    ("Demo Member 3", Gender.FEMALE, MemberCategory.ST),
    ("Demo Member 4", Gender.MALE, MemberCategory.OTFD),
    ("Demo Member 5", Gender.FEMALE, MemberCategory.OTHER),
]


def _grant(user: AppUser, role: Role, village: Village) -> UserRole:
    if role in (Role.VILLAGER, Role.GRAM_SABHA):
        return UserRole(user_id=user.id, role=role, village_id=village.id)
    if role is Role.SDO:
        return UserRole(user_id=user.id, role=role, taluka=TALUKA, district=DISTRICT)
    return UserRole(user_id=user.id, role=role, district=DISTRICT)


def seed(db: Session) -> None:
    village = db.scalar(select(Village).where(Village.name_en == "Ozhar", Village.taluka == TALUKA))
    if village is None:
        village = Village(
            name_mr="ओझर",
            name_en="Ozhar",
            gram_panchayat="Ozhar",  # TODO: confirm the Gram Panchayat name and LGD code
            taluka=TALUKA,
            district=DISTRICT,
            state="Maharashtra",
            consolidation_status=ConsolidationStatus.RECOGNISED,
        )
        db.add(village)
        db.flush()
        db.add(GramSabha(village_id=village.id))
        db.flush()
        print(f"created village Ozhar ({village.id})")

    for phone, name, role in DEMO_USERS:
        user = db.scalar(select(AppUser).where(AppUser.phone == phone))
        if user is None:
            user = AppUser(
                phone=phone, name=name, pin_hash=hash_pin(DEMO_PIN), is_admin=role is None
            )
            db.add(user)
            db.flush()
            print(f"created user {phone}  {name}")
        elif user.name != name:
            user.name = name
            print(f"renamed user {phone}  {name}")
        if role is None:
            continue
        held = set(db.scalars(select(UserRole.role).where(UserRole.user_id == user.id)))
        if role not in held:
            db.add(_grant(user, role, village))
            print(f"granted   {phone}  {role.value}")

    gram_sabha = db.scalar(select(GramSabha).where(GramSabha.village_id == village.id))
    assert gram_sabha is not None
    existing = set(db.scalars(select(GsMember.name).where(GsMember.gram_sabha_id == gram_sabha.id)))
    for member_name, gender, category in DEMO_MEMBERS:
        if member_name not in existing:
            db.add(
                GsMember(
                    gram_sabha_id=gram_sabha.id, name=member_name, gender=gender, category=category
                )
            )
            print(f"created member {member_name}")

    db.commit()


def main() -> None:
    if get_settings().env == "production":
        sys.exit("Refusing to seed demo users in production.")
    with Session(get_engine()) as db:
        seed(db)
    print(f"\nDone. Log in with any demo phone and PIN {DEMO_PIN}.")


if __name__ == "__main__":
    main()
