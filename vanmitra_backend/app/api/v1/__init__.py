from fastapi import APIRouter

from . import auth, cases, form_c, health, members

router = APIRouter(prefix="/api/v1")
router.include_router(health.router)
router.include_router(auth.router)
router.include_router(members.router)
router.include_router(cases.router)
router.include_router(form_c.router)
