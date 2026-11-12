"""پنل مدیریت: ساخت رمز، ورود، تغییر تنظیمات برای همه، و محافظت‌ها."""

import pytest
from fastapi.testclient import TestClient

from app import admin
from app.config import Settings
from app.main import create_app

from .conftest import register, scan

CODE = "s" * 40
PASSWORD = "a-strong-password"
XH = {"X-Requested-With": "cl-admin"}


def make(tmp_path, **kw) -> TestClient:
    base = dict(db_path=str(tmp_path / "a.db"), admin_token=CODE)
    base.update(kw)
    return TestClient(create_app(Settings(**base)))


def setup(c: TestClient) -> None:
    r = c.post("/admin/api/setup", json={"setup_code": CODE, "password": PASSWORD})
    assert r.status_code == 200, r.text


def test_page_served_and_state(tmp_path):
    c = make(tmp_path)
    r = c.get("/admin")
    assert r.status_code == 200 and "مدیریت کالری‌لنز" in r.text
    assert "default-src 'none'" in r.headers["Content-Security-Policy"]
    assert c.get("/admin/api/state").json() == {"needs_setup": True, "setup_available": True, "logged_in": False}


def test_setup_needs_code_once_and_strong_password(tmp_path):
    c = make(tmp_path)
    assert c.post("/admin/api/setup", json={"setup_code": "wrong", "password": PASSWORD}).status_code == 403
    assert c.post("/admin/api/setup", json={"setup_code": CODE, "password": "short"}).status_code == 400
    setup(c)
    assert c.get("/admin/api/state").json()["logged_in"] is True
    # بار دوم ممکن نیست، حتی با کد درست.
    assert c.post("/admin/api/setup", json={"setup_code": CODE, "password": "another-password"}).status_code == 409


def test_setup_impossible_without_server_code(tmp_path):
    c = make(tmp_path, admin_token="")
    assert c.get("/admin/api/state").json()["setup_available"] is False
    assert c.post("/admin/api/setup", json={"setup_code": "", "password": PASSWORD}).status_code == 403


def test_password_stored_hashed(tmp_path):
    c = make(tmp_path)
    setup(c)
    stored = c.app.state.db.admin_get("password")
    assert PASSWORD not in stored and stored.startswith("scrypt$")
    assert admin.verify_password(PASSWORD, stored)
    assert not admin.verify_password("nope", stored)


def test_login_logout_and_wrong_password(tmp_path):
    c = make(tmp_path)
    setup(c)
    assert c.post("/admin/api/logout", headers=XH).status_code == 200
    assert c.get("/admin/api/settings", headers=XH).status_code == 401
    assert c.post("/admin/api/login", json={"password": "wrong-password"}).status_code == 403
    assert c.post("/admin/api/login", json={"password": PASSWORD}).status_code == 200
    assert c.get("/admin/api/settings", headers=XH).status_code == 200


def test_login_rate_limited(tmp_path):
    c = make(tmp_path)
    setup(c)
    codes = [c.post("/admin/api/login", json={"password": "x"}).status_code for _ in range(10)]
    assert codes[-1] == 429


def test_settings_need_session_and_csrf_header(tmp_path):
    c = make(tmp_path)
    setup(c)
    # بدون هدر صفحه (درخواست از سایت دیگر) رد می‌شود.
    assert c.get("/admin/api/settings").status_code == 401
    assert c.put("/admin/api/settings", json={"values": {"free_scans_per_day": 9}}).status_code == 401
    # کد راه‌اندازی به‌تنهایی برای تغییر تنظیمات کافی نیست.
    other = make(tmp_path)
    r = other.put("/admin/api/settings", headers=XH | {"X-Admin-Token": CODE}, json={"values": {}})
    assert r.status_code == 401


def test_change_quota_applies_to_everyone_immediately_and_persists(tmp_path):
    c = make(tmp_path)
    h = register(c)
    assert c.get("/quota", headers=h).json()["limit"] == 3
    setup(c)
    r = c.put("/admin/api/settings", headers=XH, json={"values": {"free_scans_per_day": 1}})
    assert r.json()["ok"] is True and r.json()["changed"] == ["free_scans_per_day"]
    assert c.get("/quota", headers=h).json()["limit"] == 1
    assert scan(c, h).status_code == 200
    assert scan(c, h, salt=1).status_code == 429
    # بعد از ری‌استارت سرور هم می‌ماند.
    again = make(tmp_path)
    assert again.get("/quota", headers=h).json()["limit"] == 1


def test_api_key_saved_masked_and_provider_switched(tmp_path):
    c = make(tmp_path)
    setup(c)
    values = {
        "vision_provider": "openai_compatible",
        "openai_compat_base_url": "https://openrouter.ai/api/v1",
        "openai_compat_api_key": "sk-or-secret-12345678",
        "openai_compat_model": "vendor/model-x",
    }
    r = c.put("/admin/api/settings", headers=XH, json={"values": values})
    assert r.status_code == 200, r.text
    assert "sk-or-secret" not in r.text
    assert c.app.state.provider.name == "openai_compatible"
    body = c.get("/admin/api/settings", headers=XH)
    assert "sk-or-secret" not in body.text
    key = next(f for f in body.json()["fields"] if f["name"] == "openai_compat_api_key")
    assert key == key | {"value": "", "is_set": True, "masked": "••••5678"}
    # کلید خالی = همان قبلی بماند.
    r = c.put("/admin/api/settings", headers=XH, json={"values": {"openai_compat_api_key": "", "openai_compat_model": "vendor/model-y"}})
    assert r.json()["changed"] == ["openai_compat_model"]
    assert c.app.state.provider.model == "vendor/model-y"
    assert make(tmp_path).app.state.provider.model == "vendor/model-y"


@pytest.mark.parametrize(
    "values",
    [
        {"free_scans_per_day": -1},
        {"free_scans_per_day": 2.5},
        {"vision_provider": "magic"},
        {"db_path": "/tmp/x"},
        {"admin_token": "x" * 40},
        {"vision_provider": "openai_compatible"},  # بدون کلید و مدل
        {"openai_compat_base_url": "http://evil.example"},
    ],
)
def test_invalid_settings_rejected_and_nothing_saved(tmp_path, values):
    c = make(tmp_path)
    setup(c)
    r = c.put("/admin/api/settings", headers=XH, json={"values": values})
    assert r.status_code == 400 and r.json()["errors"]
    assert admin.load_overrides(c.app.state.db) == {}


def test_production_panel_cannot_enable_fake_provider(tmp_path):
    c = make(
        tmp_path, app_env="production", vision_provider="none",
        purchase_verifier="stores", reward_verifier="disabled",
    )
    setup(c)  # کوکی Secure است؛ TestClient با http آن را نمی‌فرستد
    token = c.app.state.db.admin_session_create(600)
    cookie = {"Cookie": f"{admin.COOKIE}={token}"}
    r = c.put("/admin/api/settings", headers=XH | cookie, json={"values": {"vision_provider": "fake"}})
    assert r.status_code == 400
    # تا تنظیم نشده، اسکن خطای روشن می‌دهد نه پاسخ ساختگی.
    h = register(c)
    assert scan(c, h).status_code == 502


def test_change_password_invalidates_old_one(tmp_path):
    c = make(tmp_path)
    setup(c)
    assert c.post("/admin/api/password", headers=XH, json={"current": "wrong-one", "new": "brand-new-password"}).status_code == 403
    assert c.post("/admin/api/password", headers=XH, json={"current": PASSWORD, "new": "brand-new-password"}).status_code == 200
    c.post("/admin/api/logout", headers=XH)
    assert c.post("/admin/api/login", json={"password": PASSWORD}).status_code == 403
    assert c.post("/admin/api/login", json={"password": "brand-new-password"}).status_code == 200


def test_connection_test_and_reports_with_session(tmp_path):
    c = make(tmp_path)
    setup(c)
    assert c.post("/admin/api/test", headers=XH).json()["ok"] is True  # ارائه‌دهنده‌ی fake
    assert c.get("/admin/stats").status_code == 200  # با نشست پنل
    assert make(tmp_path).get("/admin/stats").status_code == 404  # بدون نشست


def test_forgotten_password_reset_keeps_settings(tmp_path):
    from app.reset_admin import reset

    c = make(tmp_path)
    setup(c)
    c.put("/admin/api/settings", headers=XH, json={"values": {"free_scans_per_day": 7}})
    reset(c.app.state.db)
    assert c.get("/admin/api/settings", headers=XH).status_code == 401  # نشست باطل شد
    assert c.get("/admin/api/state").json()["needs_setup"] is True
    assert c.post("/admin/api/setup", json={"setup_code": CODE, "password": "a-new-password-1"}).status_code == 200
    assert admin.load_overrides(c.app.state.db) == {"free_scans_per_day": 7}


def test_presets_cover_major_providers_and_detect_current(tmp_path):
    c = make(tmp_path)
    setup(c)
    body = c.get("/admin/api/settings", headers=XH).json()
    ids = {p["id"] for p in body["presets"]}
    assert {"openrouter", "openai", "anthropic", "gemini", "custom", "none"} <= ids
    for p in body["presets"]:
        assert p["base_url"] in (None, "") or p["base_url"].startswith("https://")
    c.put("/admin/api/settings", headers=XH, json={"values": {
        "vision_provider": "openai_compatible", "openai_compat_base_url": "https://api.openai.com/v1/",
        "openai_compat_api_key": "sk-openai-12345678", "openai_compat_model": "some-vision-model"}})
    assert c.get("/admin/api/settings", headers=XH).json()["preset"] == "openai"
    # سرویس ناشناخته (مثلاً یک درگاه دیگر) ← «سرویس دیگر»
    r = c.put("/admin/api/settings", headers=XH, json={"values": {
        "openai_compat_base_url": "https://gateway.example.ir/v1", "openai_compat_api_key": "another-key-1234"}})
    assert r.status_code == 200
    assert c.get("/admin/api/settings", headers=XH).json()["preset"] == "custom"


def test_key_is_not_reused_for_a_different_service(tmp_path):
    c = make(tmp_path)
    setup(c)
    first = {"vision_provider": "openai_compatible", "openai_compat_base_url": "https://openrouter.ai/api/v1",
             "openai_compat_api_key": "sk-or-secret-12345678", "openai_compat_model": "m"}
    assert c.put("/admin/api/settings", headers=XH, json={"values": first}).status_code == 200
    # عوض کردن آدرس بدون کلید تازه: کلید OpenRouter نباید به سرویس دیگر برود.
    r = c.put("/admin/api/settings", headers=XH, json={"values": {"openai_compat_base_url": "https://api.openai.com/v1"}})
    assert r.status_code == 400 and "کلید" in r.json()["errors"][0]
    assert c.app.state.provider._url.startswith("https://openrouter.ai/")


def test_switch_to_claude_with_key_from_panel(tmp_path):
    c = make(tmp_path)
    setup(c)
    r = c.put("/admin/api/settings", headers=XH, json={"values": {
        "vision_provider": "anthropic", "anthropic_api_key": "sk-ant-secret-12345678", "anthropic_model": "claude-haiku-5-5"}})
    assert r.status_code == 200, r.text
    assert "sk-ant-secret" not in r.text
    assert c.app.state.provider.name == "anthropic" and c.app.state.provider.model == "claude-haiku-5-5"
