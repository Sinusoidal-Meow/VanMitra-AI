"""
Phones that receive push messages. The app registers its Firebase token after sign-in
(and whenever Firebase gives it a new one), and removes it on sign-out.
"""

from typing import Annotated, Literal

from fastapi import APIRouter, status
from pydantic import BaseModel, StringConstraints

from ...auth.deps import CurrentUser, DbSession
from ...models import now_ms
from ...models.notifications import DeviceToken

router = APIRouter(tags=["notifications"])

Token = Annotated[str, StringConstraints(strip_whitespace=True, min_length=20, max_length=4096)]


class DeviceIn(BaseModel):
    token: Token
    platform: Literal["android", "ios", "web"] = "android"
    language: Literal["mr", "en"] = "mr"


class DeviceOut(BaseModel):
    token: str
    platform: str
    language: str


@router.post("/devices", response_model=DeviceOut, status_code=status.HTTP_200_OK)
def register_device(body: DeviceIn, db: DbSession, user: CurrentUser) -> DeviceOut:
    """Register (or refresh) this phone for the signed-in user. A phone signed in by
    another user before is moved to this user."""
    device = db.find_one(DeviceToken, {"token": body.token})
    if device is None:
        device = db.add(
            DeviceToken(
                user_id=user.id, token=body.token, platform=body.platform, language=body.language
            )
        )
    else:
        device.user_id = user.id
        device.platform = body.platform
        device.language = body.language
        device.updated_at = now_ms()
    db.commit()
    return DeviceOut(token=device.token, platform=device.platform, language=device.language)


@router.delete("/devices/{token}", status_code=status.HTTP_204_NO_CONTENT)
def remove_device(token: str, db: DbSession, user: CurrentUser) -> None:
    """Stop push messages to this phone (on sign-out). Unknown tokens are ignored."""
    device = db.find_one(DeviceToken, {"token": token, "user_id": user.id})
    if device is not None:
        db.delete(device)
        db.commit()
