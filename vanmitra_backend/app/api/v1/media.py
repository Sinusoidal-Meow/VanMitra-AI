"""
Uploads of scans, photos and audio. Files are content-addressed (SHA-256) and served
only to their uploader or to someone who may see a case that uses them.
"""

import uuid
from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, File, Form, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy import or_, select

from ... import storage
from ...auth.deps import CurrentPrincipal, CurrentUser, DbSession
from ...config import get_settings
from ...errors import ApiError
from ...models.procedure import Evidence, Media
from ...schemas.evidence import MediaOut
from ...services.cases import load_case

router = APIRouter(tags=["media"])

ALLOWED_MIME = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "application/pdf",
    "audio/mpeg",
    "audio/mp4",
    "audio/aac",
    "audio/wav",
    "audio/x-wav",
    "audio/ogg",
    "audio/webm",
}


def media_out(m: Media) -> MediaOut:
    return MediaOut(
        id=m.id,
        sha256=m.sha256,
        mime=m.mime,
        size_bytes=m.size_bytes,
        original_name=m.original_name,
        captured_at=m.captured_at,
        gps_lat=m.gps_lat,
        gps_lon=m.gps_lon,
        gps_accuracy_m=m.gps_accuracy_m,
        created_at=m.created_at,
    )


@router.post("/media", response_model=MediaOut, status_code=status.HTTP_201_CREATED)
async def upload(
    db: DbSession,
    user: CurrentUser,
    file: Annotated[UploadFile, File()],
    captured_at: Annotated[datetime | None, Form()] = None,
    gps_lat: Annotated[float | None, Form(ge=-90, le=90)] = None,
    gps_lon: Annotated[float | None, Form(ge=-180, le=180)] = None,
    gps_accuracy_m: Annotated[float | None, Form(ge=0)] = None,
) -> MediaOut:
    mime = (file.content_type or "").lower()
    if mime not in ALLOWED_MIME:
        raise ApiError(415, "UNSUPPORTED_MEDIA_TYPE", "media.unsupported_type", {"mime": mime})
    limit = get_settings().max_upload_mb * 1024 * 1024
    data = await file.read(limit + 1)
    if len(data) > limit:
        raise ApiError(413, "FILE_TOO_LARGE", "media.too_large", {"max_mb": limit // 1048576})
    if not data:
        raise ApiError(422, "EMPTY_FILE", "media.empty")
    digest, key = storage.save(data)
    media = Media(
        sha256=digest,
        mime=mime,
        size_bytes=len(data),
        original_name=(file.filename or None),
        storage_key=key,
        uploaded_by_user_id=user.id,
        captured_at=captured_at,
        gps_lat=gps_lat,
        gps_lon=gps_lon,
        gps_accuracy_m=gps_accuracy_m,
    )
    db.add(media)
    db.commit()
    db.refresh(media)
    return media_out(media)


def _accessible(db: DbSession, principal: CurrentPrincipal, media_id: uuid.UUID) -> Media:
    media = db.get(Media, media_id)
    if media is None:
        raise ApiError(404, "MEDIA_NOT_FOUND", "media.not_found")
    if media.uploaded_by_user_id == principal.user_id:
        return media
    case_ids = db.scalars(
        select(Evidence.case_id).where(
            or_(Evidence.media_id == media_id, Evidence.signed_scan_media_id == media_id)
        )
    ).all()
    for case_id in set(case_ids):
        try:
            load_case(db, principal, case_id)
            return media
        except ApiError:
            continue
    raise ApiError(404, "MEDIA_NOT_FOUND", "media.not_found")


@router.get("/media/{media_id}", response_model=MediaOut)
def media_info(media_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal) -> MediaOut:
    return media_out(_accessible(db, principal, media_id))


@router.get("/media/{media_id}/file")
def media_file(media_id: uuid.UUID, db: DbSession, principal: CurrentPrincipal) -> FileResponse:
    media = _accessible(db, principal, media_id)
    return FileResponse(
        storage.path_for(media.storage_key),
        media_type=media.mime,
        filename=media.original_name or f"{media.sha256}",
    )
