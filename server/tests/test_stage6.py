import json

from app.providers.base import ProviderBusy
from app.providers.fake import FakeProvider

from .conftest import register


def voice(c, h, text):
    return c.post("/voice", headers=h, json={"text": text})


def test_acceptance_sentence_to_three_items_in_lunch(client):
    """معیار پذیرش مرحله‌ی ۶."""
    h = register(client)
    r = voice(client, h, "ناهار یه بشقاب قیمه با برنج و یه دوغ خوردم")
    assert r.status_code == 200, r.text
    b = r.json()
    assert b["meal"] == "lunch"
    assert [i["food_id"] for i in b["items"]] == ["gheymeh", "chelo", "doogh"]
    assert all(i["quantity"] == 1 for i in b["items"])
    # قیمه «بشقاب» ندارد ← واحد پیش‌فرض (ملاقه)
    assert b["items"][0]["unit"] == "ladle" and b["items"][0]["unit_adjusted"] is True
    assert b["items"][2]["unit"] == "glass"
    assert b["quota"]["voice_remaining"] == 1


def test_voice_quota_two_per_day_free(client):
    h = register(client)
    assert voice(client, h, "یه دوغ").status_code == 200
    assert voice(client, h, "یه چای").status_code == 200
    r = voice(client, h, "دو تا خرما")
    assert r.status_code == 429 and r.json()["error"]["code"] == "voice_quota_exceeded"


def test_not_food_sentence_refunds_voice(client):
    h = register(client)
    for _ in range(3):
        r = voice(client, h, "سلام، هوا چطوره؟")
        assert r.json()["is_food"] is False
    assert client.get("/quota", headers=h).json()["voice_remaining"] == 2


def test_voice_validation_and_provider_errors(make_client):
    c = make_client()
    h = register(c)
    assert voice(c, h, "  ").json()["error"]["code"] == "empty_text"
    assert voice(c, h, "ا" * 301).status_code == 413
    c2 = make_client(FakeProvider(error=ProviderBusy("x")))
    h2 = register(c2)
    assert voice(c2, h2, "یه دوغ").status_code == 503
    assert c2.get("/quota", headers=h2).json()["voice_remaining"] == 2


def test_voice_meal_must_be_valid(make_client):
    bad = {"items": [], "is_food": True, "notes_fa": None, "meal": "brunch"}
    c = make_client(FakeProvider(text_result=bad))
    r = voice(c, register(c), "یه چیزی")
    assert r.json()["error"]["code"] == "invalid_model_output"


def test_invite_both_get_seven_days(client):
    a = register(client, "device_aaaaaaaaaaaaaaaa")
    b = register(client, "device_bbbbbbbbbbbbbbbb")
    code = client.get("/invite", headers=a).json()["code"]
    assert len(code) == 6
    assert client.get("/invite", headers=a).json()["code"] == code  # پایدار

    r = client.post("/invite/redeem", headers=b, json={"code": code.lower()})
    assert r.status_code == 200 and r.json()["premium"] is True
    assert client.get("/quota", headers=a).json()["premium"] is True
    info = client.get("/invite", headers=a).json()
    assert info["invited"] == 1
    assert client.get("/invite", headers=b).json()["redeemed_code"] == code

    # دوباره، کد خود، کد نامعتبر
    assert client.post("/invite/redeem", headers=b, json={"code": code}).json()["error"]["code"] == "already_redeemed"
    assert client.post("/invite/redeem", headers=a, json={"code": code}).json()["error"]["code"] == "own_code"
    assert client.post("/invite/redeem", headers=a, json={"code": "ZZZZZZ"}).status_code == 404


def test_inviter_reward_is_capped(make_client):
    c = make_client(invite_max_rewards=1)
    a = register(c, "device_aaaaaaaaaaaaaaaa")
    code = c.get("/invite", headers=a).json()["code"]
    for i, d in enumerate(["device_bbbbbbbbbbbbbbbb", "device_cccccccccccccccc"]):
        c.post("/invite/redeem", headers=register(c, d), json={"code": code})
        until = c.get("/quota", headers=a).json()["premium_until"]
        if i == 0:
            first = until
    assert until == first  # دومی به دعوت‌کننده روز اضافه نکرد


def test_feedback_scan_stored(client):
    h = register(client)
    r = client.post(
        "/feedback/scan",
        headers=h,
        json={
            "scan_id": "s1",
            "original": [{"food_id": "chelo", "quantity": 1}],
            "corrected": [{"food_id": "kateh", "quantity": 1.5}],
            "note": "کته بود",
        },
    )
    assert r.json() == {"ok": True}
    db = client.app.state.db
    row = db._conn.execute("SELECT * FROM scan_feedback").fetchone()
    assert json.loads(row["corrected_json"])[0]["food_id"] == "kateh"
    big = [{"x": "y" * 1000}] * 30
    assert client.post("/feedback/scan", headers=h, json={"original": big, "corrected": []}).status_code == 413


def test_delete_device_removes_server_data(client):
    from .conftest import scan

    h = register(client)
    assert scan(client, h).status_code == 200
    client.post("/feedback/scan", headers=h, json={"original": [], "corrected": []})
    client.post("/purchase/verify", headers=h, json={"store": "bazaar", "product_id": "premium_yearly", "purchase_token": "test-x"})
    assert client.delete("/device", headers=h).json() == {"ok": True}
    # توکن دیگر معتبر نیست.
    assert client.get("/quota", headers=h).status_code == 401
    db = client.app.state.db
    assert db._conn.execute("SELECT COUNT(*) FROM usage").fetchone()[0] == 0
    assert db._conn.execute("SELECT COUNT(*) FROM scan_feedback").fetchone()[0] == 0
    assert db._conn.execute("SELECT device_id FROM scan_log").fetchone()[0] == "deleted"
    # خرید می‌ماند تا بعد از نصب دوباره بازیابی شود.
    h2 = register(client, "device_bbbbbbbbbbbbbbbb")
    r = client.post("/purchase/verify", headers=h2, json={"store": "bazaar", "product_id": "premium_yearly", "purchase_token": "test-x"})
    assert r.json()["premium"] is True


def test_events_whitelist_and_stats(make_client):
    import datetime

    c = make_client(admin_token="secret")
    h = register(c)
    day = datetime.date.today().isoformat()
    r = c.post(
        "/events",
        headers=h,
        json={
            "events": [
                {"name": "scan", "day": day, "count": 3},
                {"name": "log_food", "day": day, "count": 2},
                {"name": "my_secret_meal", "day": day, "count": 1},
                {"name": "scan", "day": "not-a-day", "count": 1},
            ]
        },
    )
    assert r.json() == {"accepted": 2}
    c.post("/events", headers=h, json={"events": [{"name": "scan", "day": day, "count": 1}]})
    stats = c.get("/admin/events", headers={"X-Admin-Token": "secret"}).json()["events"]
    scan = next(e for e in stats if e["name"] == "scan")
    assert (scan["total"], scan["devices"]) == (4, 1)
    assert c.get("/admin/events").status_code == 404
