"""
Test settings are set here, before any `app` import reads them.

The default suite needs no database: the configured MongoDB address is a closed port.
Database tests (marked `db`) use VANMITRA_TEST_MONGODB_URI and are skipped without it.
"""

import os
import tempfile

os.environ["VANMITRA_ENV"] = "test"
os.environ["VANMITRA_ENABLE_LEGACY_API"] = "false"
os.environ["VANMITRA_JWT_SECRET"] = "test-secret-not-for-real-use-0123456789"
os.environ["VANMITRA_MONGODB_URI"] = (
    "mongodb://127.0.0.1:1/?serverSelectionTimeoutMS=500&connectTimeoutMS=500&directConnection=true"
)
os.environ["VANMITRA_DB_CONNECT_TIMEOUT_S"] = "1"
os.environ["VANMITRA_EXPIRY_CHECK_MINUTES"] = "0"
os.environ["VANMITRA_MEDIA_DIR"] = tempfile.mkdtemp(prefix="vanmitra-media-")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.main import create_app  # noqa: E402


@pytest.fixture
def client() -> TestClient:
    return TestClient(create_app())
