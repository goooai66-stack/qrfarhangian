"""دیتابیس سرور (SQLite برای شروع؛ بخش ۱۰-۱). عکس‌ها ذخیره نمی‌شوند."""

from __future__ import annotations

import hashlib
import json
import secrets
import sqlite3
import threading
import time
from datetime import datetime
from zoneinfo import ZoneInfo

SCHEMA = """
CREATE TABLE IF NOT EXISTS devices (
  id TEXT PRIMARY KEY,
  token_hash TEXT NOT NULL UNIQUE,
  premium_until INTEGER,
  created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS usage (
  device_id TEXT NOT NULL,
  day TEXT NOT NULL,
  scans INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (device_id, day)
);
CREATE TABLE IF NOT EXISTS purchases (
  token TEXT PRIMARY KEY,
  store TEXT NOT NULL,
  product_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  verified_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS invites (
  invitee_id TEXT PRIMARY KEY,
  inviter_id TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS scan_feedback (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,
  scan_id TEXT,
  original_json TEXT NOT NULL,
  corrected_json TEXT NOT NULL,
  note TEXT,
  created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS events (
  day TEXT NOT NULL,
  name TEXT NOT NULL,
  device_id TEXT NOT NULL,
  count INTEGER NOT NULL,
  PRIMARY KEY (day, name, device_id)
);
CREATE TABLE IF NOT EXISTS scan_cache (
  image_hash TEXT PRIMARY KEY,
  result_json TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS scan_log (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  day TEXT NOT NULL,
  provider TEXT NOT NULL,
  model TEXT NOT NULL,
  status TEXT NOT NULL,
  is_food INTEGER,
  item_count INTEGER,
  cached INTEGER NOT NULL DEFAULT 0,
  input_tokens INTEGER,
  output_tokens INTEGER,
  cost_usd REAL,
  latency_ms INTEGER
);
CREATE INDEX IF NOT EXISTS idx_scan_log_day ON scan_log(day);
"""


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


class Database:
    def __init__(self, path: str, timezone: str):
        self._conn = sqlite3.connect(path, check_same_thread=False, isolation_level=None)
        self._conn.row_factory = sqlite3.Row
        self._lock = threading.Lock()
        self._tz = ZoneInfo(timezone)
        with self._lock:
            self._conn.executescript(SCHEMA)
            self._migrate()

    def _migrate(self) -> None:
        """افزودن ستون‌های جدید به دیتابیس‌های قدیمی (بدون از دست رفتن داده)."""
        cols = {r["name"] for r in self._conn.execute("PRAGMA table_info(usage)")}
        if "rewards" not in cols:
            self._conn.execute("ALTER TABLE usage ADD COLUMN rewards INTEGER NOT NULL DEFAULT 0")
        if "voice" not in cols:
            self._conn.execute("ALTER TABLE usage ADD COLUMN voice INTEGER NOT NULL DEFAULT 0")
        dcols = {r["name"] for r in self._conn.execute("PRAGMA table_info(devices)")}
        if "invite_code" not in dcols:
            self._conn.execute("ALTER TABLE devices ADD COLUMN invite_code TEXT")
            self._conn.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_invite_code ON devices(invite_code)")

    def today(self) -> str:
        """روز سهمیه بر اساس ساعت ایران (ریست نیمه‌شب تهران)."""
        return datetime.now(self._tz).date().isoformat()

    # ---- دستگاه ----

    def register_device(self, device_id: str) -> str:
        token = secrets.token_urlsafe(32)
        with self._lock:
            self._conn.execute(
                "INSERT INTO devices (id, token_hash, created_at) VALUES (?, ?, ?) "
                "ON CONFLICT(id) DO UPDATE SET token_hash = excluded.token_hash",
                (device_id, hash_token(token), int(time.time())),
            )
        return token

    def device_for_token(self, token: str) -> sqlite3.Row | None:
        with self._lock:
            return self._conn.execute(
                "SELECT * FROM devices WHERE token_hash = ?", (hash_token(token),)
            ).fetchone()

    def device_by_id(self, device_id: str) -> sqlite3.Row | None:
        with self._lock:
            return self._conn.execute("SELECT * FROM devices WHERE id = ?", (device_id,)).fetchone()

    def is_premium(self, device: sqlite3.Row) -> bool:
        until = device["premium_until"]
        return until is not None and until > time.time()

    # ---- سهمیه (سمت سرور، بخش ۹-۱) ----

    def used_today(self, device_id: str) -> int:
        return self.usage_today(device_id)[0]

    def usage_today(self, device_id: str) -> tuple[int, int]:
        """(اسکن‌های امروز، ویدیوهای جایزه‌دار امروز)"""
        with self._lock:
            row = self._conn.execute(
                "SELECT scans, rewards FROM usage WHERE device_id = ? AND day = ?",
                (device_id, self.today()),
            ).fetchone()
        return (row["scans"], row["rewards"]) if row else (0, 0)

    def try_add_reward(self, device_id: str, max_per_day: int) -> bool:
        """یک ویدیوی کامل‌دیده‌شده = ۱ اسکن بیشتر، تا سقف روزانه (اتمیک)."""
        day = self.today()
        with self._lock:
            self._conn.execute(
                "INSERT OR IGNORE INTO usage (device_id, day, scans) VALUES (?, ?, 0)", (device_id, day)
            )
            cur = self._conn.execute(
                "UPDATE usage SET rewards = rewards + 1 WHERE device_id = ? AND day = ? AND rewards < ?",
                (device_id, day, max_per_day),
            )
            return cur.rowcount == 1

    # ---- خرید اشتراک ----

    def apply_purchase(self, token: str, store: str, product_id: str, device_id: str, expires_at: int) -> int:
        """ثبت خرید و فعال‌سازی ویژه. همان توکن روی دستگاه جدید (نصب دوباره)
        به آن دستگاه منتقل می‌شود. مقدار برگشتی: premium_until."""
        now = int(time.time())
        with self._lock:
            old = self._conn.execute("SELECT device_id FROM purchases WHERE token = ?", (token,)).fetchone()
            self._conn.execute(
                "INSERT INTO purchases (token, store, product_id, device_id, expires_at, verified_at) "
                "VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(token) DO UPDATE SET device_id = excluded.device_id, "
                "expires_at = excluded.expires_at, verified_at = excluded.verified_at",
                (token, store, product_id, device_id, expires_at, now),
            )
            if old is not None and old["device_id"] != device_id:
                self._conn.execute(
                    "UPDATE devices SET premium_until = NULL WHERE id = ? AND premium_until <= ?",
                    (old["device_id"], expires_at),
                )
            self._conn.execute(
                "UPDATE devices SET premium_until = MAX(COALESCE(premium_until, 0), ?) WHERE id = ?",
                (expires_at, device_id),
            )
            return self._conn.execute("SELECT premium_until FROM devices WHERE id = ?", (device_id,)).fetchone()[0]

    def try_reserve_scan(self, device_id: str, limit: int) -> bool:
        """یک اسکن رزرو می‌کند اگر زیر سقف باشد (اتمیک)."""
        day = self.today()
        with self._lock:
            self._conn.execute(
                "INSERT OR IGNORE INTO usage (device_id, day, scans) VALUES (?, ?, 0)", (device_id, day)
            )
            cur = self._conn.execute(
                "UPDATE usage SET scans = scans + 1 WHERE device_id = ? AND day = ? AND scans < ?",
                (device_id, day, limit),
            )
            return cur.rowcount == 1

    def refund_scan(self, device_id: str) -> None:
        """غذا نبود یا خطا شد ← سهمیه برمی‌گردد."""
        with self._lock:
            self._conn.execute(
                "UPDATE usage SET scans = scans - 1 WHERE device_id = ? AND day = ? AND scans > 0",
                (device_id, self.today()),
            )

    # ---- کش نتیجه (فقط نتیجه، نه عکس) ----

    def cache_get(self, image_hash: str, ttl_days: int) -> dict | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT result_json, created_at FROM scan_cache WHERE image_hash = ?", (image_hash,)
            ).fetchone()
        if row is None or row["created_at"] < time.time() - ttl_days * 86400:
            return None
        return json.loads(row["result_json"])

    def cache_put(self, image_hash: str, result: dict) -> None:
        with self._lock:
            self._conn.execute(
                "INSERT OR REPLACE INTO scan_cache (image_hash, result_json, created_at) VALUES (?, ?, ?)",
                (image_hash, json.dumps(result, ensure_ascii=False), int(time.time())),
            )

    # ---- لاگ هزینه (بخش ۸-۵) ----

    def log_scan(self, **f) -> None:
        f.setdefault("created_at", int(time.time()))
        f.setdefault("day", self.today())
        cols = ", ".join(f)
        with self._lock:
            self._conn.execute(
                f"INSERT INTO scan_log ({cols}) VALUES ({', '.join('?' * len(f))})", tuple(f.values())
            )

    def stats(self, days: int) -> list[dict]:
        with self._lock:
            rows = self._conn.execute(
                """
                SELECT day,
                       COUNT(*) AS scans,
                       SUM(CASE WHEN status = 'ok' AND is_food = 1 THEN 1 ELSE 0 END) AS food_scans,
                       SUM(cached) AS cached,
                       SUM(CASE WHEN status NOT IN ('ok') THEN 1 ELSE 0 END) AS failed,
                       COUNT(DISTINCT device_id) AS active_devices,
                       ROUND(COALESCE(SUM(cost_usd), 0), 6) AS cost_usd,
                       CAST(AVG(latency_ms) AS INTEGER) AS avg_latency_ms
                FROM scan_log GROUP BY day ORDER BY day DESC LIMIT ?
                """,
                (days,),
            ).fetchall()
        out = []
        for r in rows:
            d = dict(r)
            d["cost_per_active_device_usd"] = (
                round(d["cost_usd"] / d["active_devices"], 6) if d["active_devices"] else 0
            )
            out.append(d)
        return out

    # ---- ثبت صوتی/متنی ----

    def voice_today(self, device_id: str) -> int:
        with self._lock:
            row = self._conn.execute(
                "SELECT voice FROM usage WHERE device_id = ? AND day = ?", (device_id, self.today())
            ).fetchone()
        return row["voice"] if row else 0

    def try_reserve_voice(self, device_id: str, limit: int) -> bool:
        day = self.today()
        with self._lock:
            self._conn.execute(
                "INSERT OR IGNORE INTO usage (device_id, day, scans) VALUES (?, ?, 0)", (device_id, day)
            )
            cur = self._conn.execute(
                "UPDATE usage SET voice = voice + 1 WHERE device_id = ? AND day = ? AND voice < ?",
                (device_id, day, limit),
            )
            return cur.rowcount == 1

    def refund_voice(self, device_id: str) -> None:
        with self._lock:
            self._conn.execute(
                "UPDATE usage SET voice = voice - 1 WHERE device_id = ? AND day = ? AND voice > 0",
                (device_id, self.today()),
            )

    # ---- کد دعوت ----

    _ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # بدون O/0/I/1 (اشتباه‌پذیر)

    def invite_code(self, device_id: str) -> str:
        with self._lock:
            row = self._conn.execute("SELECT invite_code FROM devices WHERE id = ?", (device_id,)).fetchone()
            if row and row["invite_code"]:
                return row["invite_code"]
            while True:
                code = "".join(secrets.choice(self._ALPHABET) for _ in range(6))
                try:
                    self._conn.execute("UPDATE devices SET invite_code = ? WHERE id = ?", (code, device_id))
                    return code
                except sqlite3.IntegrityError:
                    continue

    def invite_stats(self, device_id: str) -> tuple[int, str | None]:
        """(تعداد دعوت‌های موفق، کد دعوت‌کننده‌ی خود این دستگاه)"""
        with self._lock:
            n = self._conn.execute("SELECT COUNT(*) FROM invites WHERE inviter_id = ?", (device_id,)).fetchone()[0]
            by = self._conn.execute(
                "SELECT d.invite_code FROM invites i JOIN devices d ON d.id = i.inviter_id WHERE i.invitee_id = ?",
                (device_id,),
            ).fetchone()
        return n, (by[0] if by else None)

    def redeem_invite(self, invitee_id: str, code: str, days: int, max_rewards: int) -> str:
        """نتیجه: ok | invalid | self | already | (هر دو طرف [days] روز ویژه می‌گیرند؛
        دعوت‌کننده حداکثر [max_rewards] بار)."""
        now = int(time.time())
        with self._lock:
            inviter = self._conn.execute(
                "SELECT id FROM devices WHERE invite_code = ?", (code.strip().upper(),)
            ).fetchone()
            if inviter is None:
                return "invalid"
            if inviter["id"] == invitee_id:
                return "self"
            try:
                self._conn.execute(
                    "INSERT INTO invites (invitee_id, inviter_id, created_at) VALUES (?, ?, ?)",
                    (invitee_id, inviter["id"], now),
                )
            except sqlite3.IntegrityError:
                return "already"
            extend = (
                "UPDATE devices SET premium_until = MAX(COALESCE(premium_until, 0), ?) + ? WHERE id = ?"
            )
            self._conn.execute(extend, (now, days * 86400, invitee_id))
            n = self._conn.execute("SELECT COUNT(*) FROM invites WHERE inviter_id = ?", (inviter["id"],)).fetchone()[0]
            if n <= max_rewards:
                self._conn.execute(extend, (now, days * 86400, inviter["id"]))
            return "ok"

    # ---- «تشخیص اشتباه بود» ----

    def add_feedback(self, device_id: str, scan_id: str | None, original: str, corrected: str, note: str | None) -> None:
        with self._lock:
            self._conn.execute(
                "INSERT INTO scan_feedback (device_id, scan_id, original_json, corrected_json, note, created_at) "
                "VALUES (?, ?, ?, ?, ?, ?)",
                (device_id, scan_id, original, corrected, note, int(time.time())),
            )

    def recent_feedback(self, limit: int) -> list[dict]:
        """برای بازبینی دستی گزارش‌های «تشخیص اشتباه بود» (بدون شناسه‌ی دستگاه)."""
        with self._lock:
            rows = self._conn.execute(
                "SELECT scan_id, original_json, corrected_json, note, created_at "
                "FROM scan_feedback ORDER BY id DESC LIMIT ?",
                (limit,),
            ).fetchall()
        return [dict(r) for r in rows]

    # ---- آنالیتیکس بی‌نام (بخش ۱۱) ----

    def add_events(self, device_id: str, events: list[tuple[str, str, int]]) -> None:
        with self._lock:
            for day, name, count in events:
                self._conn.execute(
                    "INSERT INTO events (day, name, device_id, count) VALUES (?, ?, ?, ?) "
                    "ON CONFLICT(day, name, device_id) DO UPDATE SET count = count + excluded.count",
                    (day, name, device_id, count),
                )

    def event_stats(self, days: int) -> list[dict]:
        with self._lock:
            rows = self._conn.execute(
                "SELECT day, name, SUM(count) AS total, COUNT(DISTINCT device_id) AS devices "
                "FROM events WHERE day >= date('now', ?) GROUP BY day, name ORDER BY day DESC, name",
                (f"-{days} days",),
            ).fetchall()
        return [dict(r) for r in rows]

    # ---- حذف داده‌های دستگاه (درخواست کاربر) ----

    def delete_device(self, device_id: str) -> None:
        """همه‌ی داده‌های این دستگاه پاک می‌شود. سابقه‌ی خرید (توکن فروشگاه) برای
        بازیابی اشتراک می‌ماند ولی از دستگاه جدا می‌شود؛ لاگ هزینه بی‌نام می‌شود."""
        with self._lock:
            self._conn.execute("DELETE FROM usage WHERE device_id = ?", (device_id,))
            self._conn.execute("DELETE FROM events WHERE device_id = ?", (device_id,))
            self._conn.execute("DELETE FROM scan_feedback WHERE device_id = ?", (device_id,))
            self._conn.execute("DELETE FROM invites WHERE invitee_id = ? OR inviter_id = ?", (device_id, device_id))
            self._conn.execute("UPDATE purchases SET device_id = '' WHERE device_id = ?", (device_id,))
            self._conn.execute("UPDATE scan_log SET device_id = 'deleted' WHERE device_id = ?", (device_id,))
            self._conn.execute("DELETE FROM devices WHERE id = ?", (device_id,))
