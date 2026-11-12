import sqlite3
import time

from app.billing.verifiers import NotConfiguredPurchaseVerifier, parse_product_days
from app.db import Database

from .conftest import register, scan


def reward(c, h, token="tapsell-reward-1"):
    return c.post("/quota/reward", headers=h, json={"reward_token": token})


def buy(c, h, token="test-abc", product="premium_yearly", store="bazaar"):
    return c.post(
        "/purchase/verify",
        headers=h,
        json={"store": store, "product_id": product, "purchase_token": token},
    )


def test_reward_adds_one_scan_up_to_daily_limit(client):
    h = register(client)
    for i in range(3):
        assert scan(client, h, salt=i).status_code == 200
    assert scan(client, h, salt=10).json()["error"]["code"] == "quota_exceeded"

    q = reward(client, h).json()
    assert (q["limit"], q["remaining"], q["rewards_left"]) == (4, 1, 4)
    assert scan(client, h, salt=11).status_code == 200  # اسکن چهارم با ویدیو

    for _ in range(4):
        assert reward(client, h).status_code == 200
    r = reward(client, h)  # ششمین ویدیو
    assert r.status_code == 429 and r.json()["error"]["code"] == "reward_limit"
    assert client.get("/quota", headers=h).json()["limit"] == 3 + 5


def test_reward_requires_token(client):
    h = register(client)
    r = reward(client, h, token="")
    assert r.status_code == 400 and r.json()["error"]["code"] == "invalid_reward"


def test_purchase_activates_premium_and_unlimited_fair_quota(client):
    h = register(client)
    q = buy(client, h).json()
    assert q["premium"] is True
    assert q["limit"] == 30 and q["rewards_left"] == 0
    assert q["premium_until"] > time.time() + 360 * 86400
    # بیشتر از ۳ اسکن رایگان (زیر محدودیت نرخ ۶ در دقیقه).
    for i in range(5):
        assert scan(client, h, salt=i).status_code == 200
    # کاربر ویژه تبلیغ نمی‌بیند ← پاداش ندارد.
    assert reward(client, h).json()["error"]["code"] == "premium_user"


def test_invalid_or_unknown_purchase(client):
    h = register(client)
    assert buy(client, h, token="forged").json()["error"]["code"] == "invalid_purchase"
    assert buy(client, h, product="lifetime").status_code == 402
    assert buy(client, h, store="googleplay").status_code == 400
    assert client.get("/quota", headers=h).json()["premium"] is False


def test_restore_after_reinstall_moves_premium_to_new_device(client):
    old = register(client, "device_aaaaaaaaaaaaaaaa")
    assert buy(client, old, token="test-same").json()["premium"] is True
    # نصب دوباره ← شناسه‌ی دستگاه جدید، همان توکن خرید از فروشگاه.
    new = register(client, "device_bbbbbbbbbbbbbbbb")
    assert client.get("/quota", headers=new).json()["premium"] is False
    assert buy(client, new, token="test-same").json()["premium"] is True
    assert client.get("/quota", headers=old).json()["premium"] is False


def test_store_verification_not_configured(make_client):
    c2 = make_client(purchase_verifier="stores")
    h = register(c2)
    r = buy(c2, h)
    assert r.status_code == 503
    assert r.json()["error"]["code"] == "verification_unavailable"


def test_parse_product_days():
    assert parse_product_days("a=30, b=365") == {"a": 30, "b": 365}


def test_old_database_gets_rewards_column(tmp_path):
    path = tmp_path / "old.db"
    con = sqlite3.connect(path)
    con.execute("CREATE TABLE usage (device_id TEXT NOT NULL, day TEXT NOT NULL, scans INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (device_id, day))")
    con.execute("INSERT INTO usage VALUES ('d', '2026-01-01', 2)")
    con.commit()
    con.close()
    db = Database(str(path), "Asia/Tehran")
    cols = {r["name"] for r in db._conn.execute("PRAGMA table_info(usage)")}
    assert "rewards" in cols
    assert db._conn.execute("SELECT scans FROM usage").fetchone()[0] == 2


def test_not_configured_verifier_raises():
    import asyncio

    import pytest

    from app.billing.verifiers import VerifierUnavailable

    with pytest.raises(VerifierUnavailable):
        asyncio.run(NotConfiguredPurchaseVerifier().verify("bazaar", "x", "y"))
