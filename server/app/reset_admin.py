"""فراموشی رمز مدیر:  python -m app.reset_admin

رمز و همه‌ی نشست‌ها پاک می‌شود؛ بعد در /admin دوباره با کد راه‌اندازی
(ADMIN_TOKEN) رمز تازه بساز. تنظیمات ذخیره‌شده دست نمی‌خورد.
"""

from .config import Settings
from .db import Database


def reset(db: Database) -> None:
    with db._lock:
        db._conn.execute("DELETE FROM admin_kv WHERE key = 'password'")
        db._conn.execute("DELETE FROM admin_sessions")


if __name__ == "__main__":
    s = Settings.from_env()
    reset(Database(s.db_path, s.quota_timezone))
    print("رمز مدیر پاک شد. حالا /admin را باز کن و با کد راه‌اندازی رمز تازه بساز.")
