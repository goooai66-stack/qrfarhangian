"""محدودیت نرخ ساده در حافظه (پنجره‌ی لغزان). برای چند نمونه‌ی سرور
باید به Redis یا دیتابیس منتقل شود."""

from __future__ import annotations

import time
from collections import defaultdict, deque


class RateLimiter:
    def __init__(self, limit: int, window_seconds: float):
        self.limit = limit
        self.window = window_seconds
        self._hits: dict[str, deque[float]] = defaultdict(deque)

    def check(self, key: str, now: float | None = None) -> float | None:
        """None یعنی مجاز؛ در غیر این صورت چند ثانیه تا مجاز شدن."""
        t = time.monotonic() if now is None else now
        q = self._hits[key]
        while q and q[0] <= t - self.window:
            q.popleft()
        if len(q) >= self.limit:
            return max(0.0, q[0] + self.window - t)
        q.append(t)
        return None
