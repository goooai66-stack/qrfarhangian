"""سخت‌گیری production: سرور با تنظیمات ناامن بالا نمی‌آید."""

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.providers.fake import FakeProvider

from .conftest import register

ADMIN = "a" * 32


def prod(tmp_path, **kw) -> Settings:
    base = dict(
        app_env="production",
        db_path=str(tmp_path / "p.db"),
        vision_provider="openai_compatible",
        openai_compat_base_url="https://example.invalid/v1",
        openai_compat_api_key="k",
        openai_compat_model="m",
        purchase_verifier="stores",
        reward_verifier="disabled",
        admin_token=ADMIN,
    )
    base.update(kw)
    return Settings(**base)


def test_safe_production_settings_have_no_problems(tmp_path):
    assert prod(tmp_path).problems() == []


@pytest.mark.parametrize(
    "override, word",
    [
        ({"vision_provider": "fake"}, "VISION_PROVIDER"),
        ({"purchase_verifier": "fake"}, "PURCHASE_VERIFIER"),
        ({"purchase_verifier": "stroes"}, "PURCHASE_VERIFIER"),
        ({"reward_verifier": "trusting"}, "REWARD_VERIFIER"),
        ({"admin_token": "short"}, "ADMIN_TOKEN"),
        ({"openai_compat_api_key": ""}, "OPENAI_COMPAT"),
        ({"app_env": "prod"}, "APP_ENV"),
    ],
)
def test_production_refuses_unsafe_settings(tmp_path, override, word):
    s = prod(tmp_path, **override)
    assert any(word in p for p in s.problems())
    if s.production:
        with pytest.raises(RuntimeError, match=word):
            create_app(s, FakeProvider())


def test_development_only_warns(tmp_path):
    # پیش‌فرض‌های توسعه (همه fake) سرور را متوقف نمی‌کند.
    c = TestClient(create_app(Settings(db_path=str(tmp_path / "d.db")), FakeProvider()))
    assert c.get("/health").status_code == 200
    assert c.get("/openapi.json").status_code == 200


def test_production_hides_docs_and_sets_headers(tmp_path):
    c = TestClient(create_app(prod(tmp_path), FakeProvider()))
    for path in ("/docs", "/redoc", "/openapi.json"):
        assert c.get(path).status_code == 404
    r = c.get("/health")
    assert r.headers["X-Content-Type-Options"] == "nosniff"
    assert r.headers["Cache-Control"] == "no-store"


def test_purchase_test_tokens_rejected_in_production(tmp_path):
    c = TestClient(create_app(prod(tmp_path), FakeProvider()))
    h = register(c)
    r = c.post(
        "/purchase/verify",
        headers=h,
        json={"store": "bazaar", "product_id": "premium_yearly", "purchase_token": "test-x"},
    )
    assert r.status_code == 503
    assert c.get("/quota", headers=h).json()["premium"] is False


def test_rewards_disabled(tmp_path):
    c = TestClient(create_app(prod(tmp_path), FakeProvider()))
    h = register(c)
    assert c.get("/quota", headers=h).json()["rewards_left"] == 0
    r = c.post("/quota/reward", headers=h, json={"reward_token": "anything"})
    assert r.status_code == 503
    assert r.json()["error"]["code"] == "reward_unavailable"
    assert c.get("/quota", headers=h).json()["limit"] == 3


def test_admin_token_checked(tmp_path):
    c = TestClient(create_app(prod(tmp_path), FakeProvider()))
    assert c.get("/admin/stats").status_code == 404
    assert c.get("/admin/stats", headers={"X-Admin-Token": "a" * 31}).status_code == 404
    assert c.get("/admin/stats", headers={"X-Admin-Token": ADMIN}).status_code == 200
