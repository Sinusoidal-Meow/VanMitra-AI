from fastapi import APIRouter

from . import auth, cases, health

router = APIRouter(prefix="/api/v1")
router.include_router(health.router)
router.include_router(auth.router)
router.include_router(cases.router)
