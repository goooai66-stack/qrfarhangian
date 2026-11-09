from app.providers.base import ProviderBusy, ProviderRefused, ProviderTimeout
from app.providers.fake import FakeProvider

from .conftest import JPEG, fake_json, png_bytes, register, scan


def test_health(client):
    r = client.get("/health")
    assert r.json()["ok"] is True
    assert r.json()["provider"] == "fake"


def test_auth_required(client):
    assert scan(client, {}).status_code == 401
    assert client.get("/quota", headers={"Authorization": "Bearer nope"}).status_code == 401


def test_device_id_validation(client):
    assert client.post("/auth/device", json={"device_id": "short"}).status_code == 400
    assert client.post("/auth/device", json={"device_id": "x" * 20 + "!"}).status_code == 400


def test_reregister_rotates_token(client):
    old = register(client)
    new = register(client)
    assert client.get("/quota", headers=old).status_code == 401
    assert client.get("/quota", headers=new).status_code == 200


def test_scan_ok_and_calories_from_our_db(client):
    h = register(client)
    r = scan(client, h)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["is_food"] is True
    ids = [i["food_id"] for i in body["items"]]
    assert ids[:2] == ["chelo", "kabab_koobideh"]
    chelo = body["items"][0]
    assert chelo["match"] == "exact"
    assert chelo["unit"] == "kafgir"
    # داده‌ی نمونه null است ← کالری null، نه صفر و نه عدد مدل.
    assert chelo["kcal"] is None and chelo["grams"] is None
    # «گوجه کبابی» در پایگاه نیست ← none
    assert body["items"][2]["food_id"] is None
    assert body["items"][2]["match"] == "none"
    q = body["quota"]
    assert (q["used"], q["limit"], q["remaining"]) == (1, 3, 2)
    assert q["premium"] is False and q["rewards_left"] == 5


def test_fourth_scan_rejected(client):
    """معیار پذیرش: سهمیه‌ی چهارم در یک روز رد می‌شود."""
    h = register(client)
    for i in range(3):
        assert scan(client, h, salt=i).status_code == 200
    r = scan(client, h, salt=9)
    assert r.status_code == 429
    assert r.json()["error"]["code"] == "quota_exceeded"
    assert client.get("/quota", headers=h).json()["remaining"] == 0


def test_quota_is_per_device(client):
    a = register(client, "device_aaaaaaaaaaaaaaaa")
    b = register(client, "device_bbbbbbbbbbbbbbbb")
    for i in range(3):
        scan(client, a, salt=i)
    assert scan(client, b, salt=5).status_code == 200


def test_not_food_does_not_consume_quota(make_client):
    c = make_client(FakeProvider(result=fake_json(is_food=False)))
    h = register(c)
    for i in range(5):
        r = scan(c, h, salt=i)
        assert r.status_code == 200
        assert r.json()["is_food"] is False
        assert r.json()["items"] == []
    assert c.get("/quota", headers=h).json()["used"] == 0


def test_provider_failures_refund_quota(make_client):
    for err, status, code in [
        (ProviderTimeout("t"), 504, "provider_timeout"),
        (ProviderBusy("b"), 503, "provider_busy"),
        (ProviderRefused("r"), 502, "provider_refused"),
    ]:
        c = make_client(FakeProvider(error=err))
        h = register(c)
        r = scan(c, h)
        assert r.status_code == status
        assert r.json()["error"]["code"] == code
        assert c.get("/quota", headers=h).json()["used"] == 0


def test_invalid_model_output_rejected(make_client):
    bad = [
        "not json",
        '{"items": [], "is_food": "yes", "notes_fa": null}',
        fake_json(items=[{"food_id": "chelo", "name_fa": "چلو", "quantity": -1, "unit": "kafgir", "confidence": 1}]),
        fake_json(items=[{"food_id": "chelo", "name_fa": "چلو", "quantity": 1, "unit": "cup", "confidence": 1}]),
        fake_json(extra=1),
    ]
    for text in bad:
        c = make_client(FakeProvider(result=text))
        h = register(c)
        r = scan(c, h)
        assert r.status_code == 502, text
        assert r.json()["error"]["code"] == "invalid_model_output"
        assert c.get("/quota", headers=h).json()["used"] == 0


def test_fuzzy_match_and_unit_adjust(make_client):
    out = fake_json(
        items=[
            # food_id اشتباه + نام با ي عربی ← فازی
            {"food_id": "ghorme", "name_fa": "قرمه سبزي", "quantity": 1, "unit": "ladle", "confidence": 0.8},
            # واحد تعریف‌نشده برای دوغ ← واحد پیش‌فرض
            {"food_id": "doogh", "name_fa": "دوغ", "quantity": 1, "unit": "bowl", "confidence": 0.9},
        ]
    )
    c = make_client(FakeProvider(result=out))
    items = scan(c, register(c)).json()["items"]
    assert items[0]["food_id"] == "ghormeh_sabzi"
    assert items[0]["match"] == "fuzzy"
    assert items[0]["detected_name_fa"] == "قرمه سبزي"
    assert items[1]["unit"] == "glass" and items[1]["unit_adjusted"] is True


def test_cache_avoids_second_provider_call(make_client):
    p = FakeProvider()
    c = make_client(p)
    h = register(c)
    assert scan(c, h, salt=1).status_code == 200
    assert scan(c, h, salt=1).status_code == 200
    assert p.calls == 1


def test_image_validation(client):
    h = register(client)
    r = client.post("/scan", headers=h, files={"image": ("a.txt", b"hello world", "text/plain")})
    assert r.status_code == 415
    assert scan(client, h, image=png_bytes()).status_code == 200


def test_image_too_large(make_client):
    c = make_client(max_image_bytes=100)
    r = scan(c, register(c), image=JPEG)
    assert r.status_code == 413


def test_rate_limit(make_client):
    c = make_client(scans_per_minute=2, free_scans_per_day=100)
    h = register(c)
    assert scan(c, h, salt=1).status_code == 200
    assert scan(c, h, salt=2).status_code == 200
    r = scan(c, h, salt=3)
    assert r.status_code == 429
    assert r.json()["error"]["code"] == "rate_limited"
    assert "retry-after" in r.headers


def test_cost_log_and_admin_stats(make_client):
    c = make_client(price_input_per_mtok=4.0, price_output_per_mtok=20.0, admin_token="secret")
    h = register(c)
    scan(c, h, salt=1)
    assert c.get("/admin/stats").status_code == 404
    day = c.get("/admin/stats", headers={"X-Admin-Token": "secret"}).json()["days"][0]
    assert day["scans"] == 1 and day["food_scans"] == 1
    # FakeProvider: ۱۰۰۰ توکن ورودی، ۱۰۰ خروجی ← 0.004 + 0.002
    assert abs(day["cost_usd"] - 0.006) < 1e-9
    assert abs(day["cost_per_active_device_usd"] - 0.006) < 1e-9


def test_admin_disabled_without_token(client):
    assert client.get("/admin/stats", headers={"X-Admin-Token": ""}).status_code == 404


def test_no_api_key_in_app_sources():
    """معیار پذیرش: کلید API در هیچ فایل اپ نیست."""
    import pathlib
    import re

    root = pathlib.Path(__file__).resolve().parents[2]
    pattern = re.compile(r"sk-ant-|sk-[A-Za-z0-9]{20,}|ANTHROPIC_API_KEY|OPENAI_COMPAT_API_KEY|api[_-]?key\s*[:=]", re.I)
    offenders = []
    for base in ("lib", "android", "assets"):
        for p in (root / base).rglob("*"):
            if p.is_file() and p.suffix in {".dart", ".kt", ".kts", ".xml", ".json", ".gradle", ".properties", ".arb"}:
                if pattern.search(p.read_text(encoding="utf-8", errors="ignore")):
                    offenders.append(str(p))
    assert offenders == []
