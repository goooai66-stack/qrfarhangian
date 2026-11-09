import io
import json
import struct
import zlib

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.providers.fake import FakeProvider

# یک JPEG معتبر کوچک نیاز نیست؛ سرور فقط امضای فایل را بررسی می‌کند.
JPEG = b"\xff\xd8\xff\xe0" + b"\x00" * 200


def png_bytes() -> bytes:
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(b"\x00\x00\x00\x00")) + chunk(b"IEND", b"")


@pytest.fixture
def make_client(tmp_path):
    def _make(provider=None, **overrides):
        s = Settings(db_path=str(tmp_path / "test.db"), **overrides)
        app = create_app(s, provider or FakeProvider())
        return TestClient(app)

    return _make


@pytest.fixture
def client(make_client):
    return make_client()


def register(c: TestClient, device_id: str = "device_aaaaaaaaaaaaaaaa") -> dict:
    r = c.post("/auth/device", json={"device_id": device_id})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['token']}"}


def scan(c: TestClient, headers: dict, image: bytes = JPEG, salt: int = 0):
    # salt: بایت متفاوت تا کش نتیجه فعال نشود.
    return c.post("/scan", headers=headers, files={"image": ("a.jpg", io.BytesIO(image + bytes([salt])), "image/jpeg")})


def fake_json(**kw) -> str:
    base = {"items": [], "is_food": True, "notes_fa": None}
    base.update(kw)
    return json.dumps(base, ensure_ascii=False)
