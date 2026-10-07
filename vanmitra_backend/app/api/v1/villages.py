"""
Village registry [Rule 2A], the Forest Rights Committee [Rule 3] and case claimants.

- Villages and hamlets are created by the admin (master data, not free text).
- The FRC is constituted by the Gram Sabha (the gram_sabha login records it); the
  Rule 3(1) arithmetic is checked and stored with the committee (BR-01).
- Claimants of a case are Gram Sabha members; they drive recusal (BR-02).
"""

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, status

from ...auth.deps import CurrentPrincipal, DbSession, require_admin, require_village_role
from ...auth.principal import Principal
from ...domain.frc import FrcCandidate, FrcCheck, check_frc
from ...errors import ApiError, RuleViolation
from ...models import GramSabha, GsMember, MemberCategory, Role, Village
from ...models.procedure import CaseClaimant, Frc, FrcMember
from ...schemas.procedure import (
    ClaimantOut,
    ClaimantsIn,
    FrcCheckIn,
    FrcCheckOut,
    FrcCreate,
    FrcIntimation,
    FrcMemberOut,
    FrcOut,
    VillageCreate,
    VillageOut,
    VillageUpdate,
)
from ...services.cases import ensure_editable, load_case

router = APIRouter(tags=["villages", "frc"])

AdminOnly = Annotated[Principal, Depends(require_admin)]
AnyRole = Annotated[tuple[Principal, Village], Depends(require_village_role())]
GramSabhaOnly = Annotated[tuple[Principal, Village], Depends(require_village_role(Role.GRAM_SABHA))]


def _gram_sabha(db: DbSession, village_id: uuid.UUID) -> GramSabha:
    gs = db.find_one(GramSabha, {"village_id": village_id})
    if gs is None:
        raise ApiError(409, "GRAM_SABHA_MISSING", "village.gram_sabha_missing")
    return gs


def _village_out(db: DbSession, v: Village) -> VillageOut:
    gs = db.find_one(GramSabha, {"village_id": v.id})
    gs_id = gs.id if gs else None
    return VillageOut(
        id=v.id,
        name_mr=v.name_mr,
        name_en=v.name_en,
        gram_panchayat=v.gram_panchayat,
        taluka=v.taluka,
        district=v.district,
        state=v.state,
        lgd_code=v.lgd_code,
        parent_village_id=v.parent_village_id,
        consolidation_status=v.consolidation_status,
        gram_sabha_id=gs_id,
    )


# ── Village registry ──────────────────────────────────────────────────────────


@router.post("/admin/villages", response_model=VillageOut, status_code=status.HTTP_201_CREATED)
def create_village(body: VillageCreate, db: DbSession, _: AdminOnly) -> VillageOut:
    """Admin adds a village or hamlet; its Gram Sabha is created with it."""
    if body.parent_village_id and db.get(Village, body.parent_village_id) is None:
        raise ApiError(422, "PARENT_VILLAGE_NOT_FOUND", "village.parent_not_found")
    if body.lgd_code and db.exists(Village, {"lgd_code": body.lgd_code}):
        raise ApiError(409, "LGD_CODE_TAKEN", "village.lgd_code_taken")
    village = Village(**body.model_dump())
    db.add(village)
    db.flush()
    db.add(GramSabha(village_id=village.id))
    db.commit()
    return _village_out(db, village)


@router.patch("/admin/villages/{village_id}", response_model=VillageOut)
def update_village(
    village_id: uuid.UUID, body: VillageUpdate, db: DbSession, _: AdminOnly
) -> VillageOut:
    village = db.get(Village, village_id)
    if village is None:
        raise ApiError(404, "VILLAGE_NOT_FOUND", "village.not_found")
    for key, value in body.model_dump(exclude_unset=True).items():
        if value is not None:
            setattr(village, key, value)
    db.commit()
    return _village_out(db, village)


@router.get("/villages/{village_id}", response_model=VillageOut)
def get_village(db: DbSession, scope: AnyRole) -> VillageOut:
    return _village_out(db, scope[1])


@router.get("/villages/{village_id}/hamlets", response_model=list[VillageOut])
def hamlets(db: DbSession, scope: AnyRole) -> list[VillageOut]:
    """Hamlets, padas and habitations listed under this village [Rule 2A]."""
    rows = db.find(Village, {"parent_village_id": scope[1].id}, sort=[("name_en", 1)])
    return [_village_out(db, v) for v in rows]


# ── Forest Rights Committee ───────────────────────────────────────────────────


def _check(db: DbSession, gs: GramSabha, body: FrcCheckIn) -> tuple[FrcCheck, list[GsMember]]:
    members = (
        db.find(GsMember, {"_id": {"$in": body.member_ids}, "active": True})
        if body.member_ids
        else []
    )
    foreign = [m for m in members if m.gram_sabha_id != gs.id]
    if foreign or len(members) != len(set(body.member_ids)):
        raise ApiError(
            422,
            "FRC_MEMBER_NOT_IN_ROSTER",
            "frc.member_not_in_roster",
            {"known": len(members), "given": len(set(body.member_ids))},
        )
    has_st = db.exists(
        GsMember,
        {
            "gram_sabha_id": gs.id,
            "active": True,
            "category": MemberCategory.ST.value,
        },
    )
    by_id = {m.id: m for m in members}
    result = check_frc(
        [FrcCandidate(str(i), by_id[i].gender, by_id[i].category) for i in body.member_ids],
        gram_sabha_has_st=has_st,
        chair_id=str(body.chair_id) if body.chair_id else None,
        secretary_id=str(body.secretary_id) if body.secretary_id else None,
    )
    return result, list(members)


def _check_out(c: FrcCheck) -> FrcCheckOut:
    return FrcCheckOut(**c.proof())


def _frc_out(db: DbSession, frc: Frc) -> FrcOut:
    members_out = []
    for fm in sorted(frc.members, key=lambda fm: (not fm.is_chair, not fm.is_secretary)):
        m = db.get(GsMember, fm.gs_member_id)
        if m is not None:
            members_out.append(
                FrcMemberOut(
                    gs_member_id=fm.gs_member_id,
                    name=m.name,
                    gender=m.gender,
                    category=m.category,
                    is_chair=fm.is_chair,
                    is_secretary=fm.is_secretary,
                )
            )
    return FrcOut(
        id=frc.id,
        constituted_on=frc.constituted_on,
        resolution_ref=frc.resolution_ref,
        sdlc_intimated_on=frc.sdlc_intimated_on,
        is_current=frc.is_current,
        composition=FrcCheckOut(**frc.composition_proof),
        members=members_out,
    )


@router.post("/villages/{village_id}/frc/check", response_model=FrcCheckOut)
def frc_check_endpoint(body: FrcCheckIn, db: DbSession, scope: GramSabhaOnly) -> FrcCheckOut:
    """Live composition check while the FRC is being chosen (nothing is saved)."""
    result, _ = _check(db, _gram_sabha(db, scope[1].id), body)
    return _check_out(result)


@router.post(
    "/villages/{village_id}/frc", response_model=FrcOut, status_code=status.HTTP_201_CREATED
)
def constitute_frc(body: FrcCreate, db: DbSession, scope: GramSabhaOnly) -> FrcOut:
    """
    Record the FRC elected by the Gram Sabha. Refused unless Rule 3(1) is met (BR-01).
    A new FRC supersedes the current one; the old one is kept as history.
    """
    principal, village = scope
    gs = _gram_sabha(db, village.id)
    result, members = _check(db, gs, body)
    if not result.ok:
        raise RuleViolation(
            "FRC_COMPOSITION_INVALID",
            "Rule 3(1)",
            result.failures[0],
            {"failures": result.failures, **result.proof()},
        )
    for old in db.find(Frc, {"gram_sabha_id": gs.id, "is_current": True}):
        old.is_current = False
    frc = Frc(
        gram_sabha_id=gs.id,
        constituted_on=body.constituted_on,
        resolution_ref=body.resolution_ref,
        composition_proof=result.proof(),
        is_current=True,
        created_by_user_id=principal.user_id,
    )
    frc.members = [
        FrcMember(
            gs_member_id=m.id,
            is_chair=m.id == body.chair_id,
            is_secretary=m.id == body.secretary_id,
        )
        for m in members
    ]
    db.add(frc)
    db.commit()
    return _frc_out(db, frc)


def _current_frc(db: DbSession, gs: GramSabha) -> Frc:
    frc = db.find_one(Frc, {"gram_sabha_id": gs.id, "is_current": True})
    if frc is None:
        raise ApiError(404, "FRC_NOT_CONSTITUTED", "frc.not_constituted")
    return frc


@router.get("/villages/{village_id}/frc", response_model=FrcOut)
def get_frc(db: DbSession, scope: AnyRole) -> FrcOut:
    """The current FRC with its stored composition proof (data for the G3 certificate)."""
    return _frc_out(db, _current_frc(db, _gram_sabha(db, scope[1].id)))


@router.get("/villages/{village_id}/frc/history", response_model=list[FrcOut])
def frc_history(db: DbSession, scope: AnyRole) -> list[FrcOut]:
    gs = _gram_sabha(db, scope[1].id)
    rows = db.find(Frc, {"gram_sabha_id": gs.id}, sort=[("created_at", -1)])
    return [_frc_out(db, f) for f in rows]


@router.post("/villages/{village_id}/frc/intimation", response_model=FrcOut)
def frc_intimation(body: FrcIntimation, db: DbSession, scope: GramSabhaOnly) -> FrcOut:
    """Record the date the chairperson and secretary were intimated to the SDLC [Rule 3(1)]."""
    frc = _current_frc(db, _gram_sabha(db, scope[1].id))
    if body.sdlc_intimated_on < frc.constituted_on:
        raise ApiError(422, "INTIMATION_BEFORE_CONSTITUTION", "frc.intimation_before_constitution")
    frc.sdlc_intimated_on = body.sdlc_intimated_on
    db.commit()
    return _frc_out(db, frc)


# ── Claimants per case ────────────────────────────────────────────────────────


def _claimants_out(db: DbSession, case_id: uuid.UUID) -> list[ClaimantOut]:
    claimants = db.find(CaseClaimant, {"case_id": case_id})
    m_ids = [c.gs_member_id for c in claimants]
    members = db.find(GsMember, {"_id": {"$in": m_ids}}, sort=[("name", 1)]) if m_ids else []
    return [
        ClaimantOut(gs_member_id=m.id, name=m.name, gender=m.gender, category=m.category)
        for m in members
    ]


@router.get("/cases/{case_id}/claimants", response_model=list[ClaimantOut])
def get_claimants(
    case_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal
) -> list[ClaimantOut]:
    load_case(db, principal, case_id)
    return _claimants_out(db, case_id)


@router.put("/cases/{case_id}/claimants", response_model=list[ClaimantOut])
def put_claimants(
    case_id: uuid.UUID, body: ClaimantsIn, db: DbSession, principal: CurrentPrincipal
) -> list[ClaimantOut]:
    """
    The Gram Sabha members who are claimants in this case (claimant edits, draft only).
    Used for recusal [Rule 3(3)], the elder-statement check and quorum test 3 [Rule 4(2)].
    """
    ctx = load_case(db, principal, case_id)
    ensure_editable(ctx)
    ids = set(body.member_ids)
    members = (
        db.find(
            GsMember,
            {"_id": {"$in": list(ids)}, "gram_sabha_id": ctx.case.gram_sabha_id},
        )
        if ids
        else []
    )
    if len(members) != len(ids):
        raise ApiError(422, "CLAIMANT_NOT_IN_ROSTER", "case.claimant_not_in_roster")
    existing = db.find(CaseClaimant, {"case_id": case_id})
    for row in existing:
        db.delete(row)
    db.flush()
    db.add_all([CaseClaimant(case_id=case_id, gs_member_id=m.id) for m in members])
    db.commit()
    return _claimants_out(db, case_id)
