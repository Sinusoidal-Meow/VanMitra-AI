"""
G-series documents as printable HTML (Stage 5): G4 acknowledgement, G7 intimation, G8
verification sheet, G9 boundary delineation record, G10 map sheet, G12 quorum sheet,
G13 resolution and G17 joint-meeting record. The content is what the Gram Sabha
recorded; nothing is generated that was not entered.
"""

import uuid
from typing import Literal

from fastapi import APIRouter
from fastapi.responses import HTMLResponse

from ...auth.deps import CurrentPrincipal, DbSession, village_ref
from ...documents import map_svg, render
from ...errors import ApiError, RuleViolation
from ...models import BoundaryWalk, CfrBoundary, ClaimType, GramSabha, GsMember, Village
from ...models.procedure import (
    Correspondence,
    GsMeeting,
    VerificationProceeding,
)
from ...services import boundary as geo
from ...services import gramsabha as gs_facts
from ...services import readiness
from ...services.cases import CaseContext, ensure_claim_type, load_case
from ._shared import claimant_label
from .boundary import _walk_out
from .gramsabha import _quorum, _verification_out

router = APIRouter(tags=["documents"])

Lang = Literal["en", "mr"]
CASE_DOCUMENTS = ("g4", "g8", "g9", "g10", "g12", "g13", "g17")


def _html(code: str, lang: str, ctx: CaseContext, data: dict[str, object]) -> HTMLResponse:
    return HTMLResponse(render(code, lang, ctx.village, str(ctx.case.id), data))


def _boundary(db: DbSession, ctx: CaseContext) -> CfrBoundary:
    ensure_claim_type(ctx, ClaimType.CFR, "NOT_A_FORM_C_CASE")
    b = geo.current_boundary(db, ctx.case.id)
    if b is None:
        raise ApiError(404, "NO_BOUNDARY", "boundary.none")
    return b


@router.get("/cases/{case_id}/documents/{code}", response_class=HTMLResponse)
def case_document(
    case_id: uuid.UUID,
    code: str,
    db: DbSession,
    principal: CurrentPrincipal,
    lang: Lang = "en",
    meeting_id: uuid.UUID | None = None,
    dispute_id: uuid.UUID | None = None,
) -> HTMLResponse:
    """
    `g12` needs `meeting_id`; `g17` needs `dispute_id`. G10 is refused until every
    boundary segment has a landmark (BR-08).
    """
    code = code.lower()
    if code not in CASE_DOCUMENTS:
        raise ApiError(404, "UNKNOWN_DOCUMENT", "document.unknown", {"available": CASE_DOCUMENTS})
    ctx = load_case(db, principal, case_id)
    case = ctx.case

    if code == "g4":
        if case.ack_serial is None or case.acknowledged_on is None:
            raise ApiError(409, "NOT_YET_FILED", "acknowledgement.not_yet_filed")
        docs = [
            f"{e.rule_ref.value}: {e.description}"
            for e in readiness.current_evidence(db, case.id)
            if e.created_at.date() <= case.acknowledged_on
        ]
        return _html(
            code,
            lang,
            ctx,
            {
                "serial": case.ack_serial,
                "acknowledged_on": case.acknowledged_on,
                "form": case.claim_type.value.upper(),
                "within_window": case.filed_within_window,
                "claimant": claimant_label(case, ctx.village),
                "documents": docs,
            },
        )

    if code == "g8":
        rows = db.find(
            VerificationProceeding,
            {"case_id": case.id},
            sort=[("attempt_no", 1)],
        )
        return _html(code, lang, ctx, {"proceedings": [_verification_out(v) for v in rows]})

    if code == "g9":
        b = _boundary(db, ctx)
        out = geo.boundary_out(db, b)
        walks = db.find(
            BoundaryWalk,
            {"case_id": case.id},
            sort=[("walked_on", 1)],
        )
        return _html(
            code,
            lang,
            ctx,
            {
                "walks": [_walk_out(w) for w in walks],
                "segments": out.segments,
                "landmarks": out.landmarks,
            },
        )

    if code == "g10":
        b = _boundary(db, ctx)
        if geo.segments_without_landmark(b):
            raise RuleViolation(
                "LANDMARK_PER_SEGMENT", "Rule 12(1)(g)", "boundary.landmark_per_segment"
            )
        out = geo.boundary_out(db, b)
        res = gs_facts.current_resolution(db, case.id)
        form_c = case.form_c
        zones = [{"geometry": z.geometry} for z in out.use_zones]
        svg = map_svg(out.geometry, [(lm.lon, lm.lat) for lm in out.landmarks], zones)
        return _html(
            code,
            lang,
            ctx,
            {
                "area_ha": out.area_ha,
                "version": out.version,
                "status": out.status.value,
                "sealed": out.sealed_hash,
                "svg": svg,
                "landmarks": out.landmarks,
                "zones": out.use_zones,
                "bordering": [x.name for x in form_c.bordering_villages] if form_c else [],
                "resolution": res.number if res else None,
            },
        )

    if code == "g12":
        if meeting_id is None:
            raise ApiError(422, "MEETING_REQUIRED", "document.meeting_required")
        meeting = db.get(GsMeeting, meeting_id)
        if meeting is None or meeting.gram_sabha_id != case.gram_sabha_id:
            raise ApiError(404, "MEETING_NOT_FOUND", "meeting.not_found")
        attendance_list = []
        for att in meeting.attendance:
            m = db.get(GsMember, att.gs_member_id)
            if m is not None:
                attendance_list.append({"name": m.name, "present": att.present})
        attendance_list.sort(key=lambda x: str(x["name"]))
        return _html(
            code,
            lang,
            ctx,
            {
                "m": meeting,
                "q": _quorum(db, meeting, case.id).model_dump(),
                "attendance": attendance_list,
            },
        )

    if code == "g13":
        res = gs_facts.current_resolution(db, case.id)
        if res is None:
            raise ApiError(404, "NO_RESOLUTION", "resolution.none")
        meeting = db.get(GsMeeting, res.meeting_id)
        sealed = None
        if res.boundary_id:
            sealed = db.get(CfrBoundary, res.boundary_id)
        return _html(
            code,
            lang,
            ctx,
            {
                "r": res,
                "meeting": meeting,
                "q": res.quorum_proof,
                "boundary_sealed": sealed.sealed_hash if sealed else None,
            },
        )

    # g17
    if dispute_id is None:
        raise ApiError(422, "DISPUTE_REQUIRED", "document.dispute_required")
    disputes = [d for d in geo.disputes_out(db, case.id) if d.id == dispute_id]
    if not disputes:
        raise ApiError(404, "DISPUTE_NOT_FOUND", "dispute.not_found")
    return _html(code, lang, ctx, {"d": disputes[0], "own": ctx.village.name_en})


@router.get("/letters/{letter_id}/document", response_class=HTMLResponse)
def letter_document(
    letter_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal, lang: Lang = "en"
) -> HTMLResponse:
    """The tracked letter (G2 / G5 / G6 / G7 / G18) as a printable page."""
    letter = db.get(Correspondence, letter_id)
    if letter is None:
        raise ApiError(404, "LETTER_NOT_FOUND", "letter.not_found")
    gs = db.get(GramSabha, letter.gram_sabha_id)
    village = db.get(Village, gs.village_id) if gs else None
    if village is None or not principal.has(village_ref(village)):
        raise ApiError(404, "LETTER_NOT_FOUND", "letter.not_found")
    return HTMLResponse(render("g7", lang, village, str(letter.case_id or ""), {"letter": letter}))
