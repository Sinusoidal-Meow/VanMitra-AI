# Temporary Mock Changes to Revert

I have temporarily hardcoded a mock backend directly into the application's central `ApiClient` so you can test the UI and workflows immediately on your mobile device without needing a running backend server.

Before you push your changes to your branch (`kaushal-dev`), **you must revert this file** to restore real network calls:

### 1. `lib/core/api/api_client.dart`
**What was changed:**
- Added a `static const bool _useMock = true;` flag inside the `ApiClient` class.
- Added a `_handleMockRequest()` method that intercepts HTTP requests and returns hardcoded JSON data (for `/auth/login`, `/me`, `/cases`, etc.).
- Modified `get()`, `post()`, `put()`, and `patch()` methods to return the mock data if `_useMock` is true.

**How to revert:**
You can easily revert this specific file to its original state using git:
```bash
git checkout -- lib/core/api/api_client.dart
```

Alternatively, you can just manually delete the `_useMock` variable and the `_handleMockRequest` function, and remove the `if (_useMock) return _handleMockRequest(...)` lines from the top of the HTTP methods inside `lib/core/api/api_client.dart`.

Once you revert these changes, the app will resume trying to hit the real endpoints on `http://10.0.2.2:8010/api/v1` (or whatever `VANMITRA_API_BASE_URL` you provide).
