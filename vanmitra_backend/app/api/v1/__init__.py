from fastapi import APIRouter

from . import (
    admin,
    auth,
    cases,
    claim_calls,
    evidence,
    form_a,
    form_b,
    form_c,
    health,
    media,
    members,
    villages,
    workflow,
)

router = APIRouter(prefix="/api/v1")
router.include_router(health.router)
router.include_router(auth.router)
router.include_router(admin.router)
router.include_router(members.router)
router.include_router(villages.router)
router.include_router(cases.router)
router.include_router(form_a.router)
router.include_router(form_b.router)
router.include_router(form_c.router)
router.include_router(workflow.router)
router.include_router(claim_calls.router)
router.include_router(media.router)
router.include_router(evidence.router)
