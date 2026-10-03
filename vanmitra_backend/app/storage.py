"""
File storage for scans, photos and audio. Local disk for development; the interface
(save / path / exists) is what an S3 / MinIO backend implements later (B-10).
Files are content-addressed by SHA-256, so the stored bytes can be re-verified.
"""

import hashlib
from pathlib import Path

from .config import get_settings


def _root() -> Path:
    root = Path(get_settings().media_dir).resolve()
    root.mkdir(parents=True, exist_ok=True)
    return root


def save(data: bytes) -> tuple[str, str]:
    """Store bytes; returns (sha256, storage_key). Saving the same bytes twice is a no-op."""
    digest = hashlib.sha256(data).hexdigest()
    key = f"{digest[:2]}/{digest}"
    path = _root() / key
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".part")
        tmp.write_bytes(data)
        tmp.replace(path)
    return digest, key


def path_for(key: str) -> Path:
    path = (_root() / key).resolve()
    if _root() not in path.parents:  # never serve outside the media root
        raise ValueError("invalid storage key")
    return path
