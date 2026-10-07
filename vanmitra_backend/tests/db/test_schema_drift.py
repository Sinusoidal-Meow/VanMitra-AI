"""Check that all document models have their collections registered in MongoDB indexes."""

from app.models import (
    AppUser,
    BoundaryWalk,
    CaseClaimant,
    CfrBoundary,
    ClaimCall,
    ClaimCase,
    Correspondence,
    Dispute,
    Evidence,
    EvidenceVerification,
    Frc,
    GramSabha,
    GsMeeting,
    GsMember,
    LedgerEntry,
    Media,
    Notification,
    Recusal,
    Resolution,
    TitleFollowup,
    UserRole,
    VerificationProceeding,
    Village,
    WorkflowEvent,
)
from app.mongo import INDEXES


def test_models_have_indexes() -> None:
    models = [
        Village,
        GramSabha,
        GsMember,
        AppUser,
        UserRole,
        Frc,
        CaseClaimant,
        Recusal,
        ClaimCall,
        Media,
        Evidence,
        EvidenceVerification,
        LedgerEntry,
        Correspondence,
        VerificationProceeding,
        GsMeeting,
        Resolution,
        TitleFollowup,
        CfrBoundary,
        BoundaryWalk,
        Dispute,
        Notification,
        ClaimCase,
        WorkflowEvent,
    ]
    for m in models:
        assert m.COLLECTION in INDEXES, f"Collection {m.COLLECTION} missing from INDEXES"
