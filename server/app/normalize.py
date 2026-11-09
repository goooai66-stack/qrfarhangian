"""نرمال‌سازی و جستجوی فازی فارسی — همان الگوریتم اپ
(lib/core/utils/persian_text.dart و lib/data/foods/food_search.dart)."""

from __future__ import annotations

import re

_CHAR_MAP = str.maketrans(
    {
        "ي": "ی",
        "ى": "ی",
        "ك": "ک",
        "ة": "ه",
        "ۀ": "ه",
        "أ": "ا",
        "إ": "ا",
        "آ": "ا",
        "ٱ": "ا",
        "ؤ": "و",
        **{c: str(i) for i, c in enumerate("۰۱۲۳۴۵۶۷۸۹")},
        **{c: str(i) for i, c in enumerate("٠١٢٣٤٥٦٧٨٩")},
    }
)
_DIACRITICS = re.compile("[ً-ٰٟـ]")
_SPACES = re.compile("[‌‍ ​  \\s]+")


def normalize(text: str) -> str:
    s = text.translate(_CHAR_MAP)
    s = _DIACRITICS.sub("", s).lower()
    return _SPACES.sub(" ", s).strip()


def levenshtein(a: str, b: str, max_dist: int = 1 << 30) -> int:
    if abs(len(a) - len(b)) > max_dist:
        return max_dist + 1
    if a == b:
        return 0
    prev = list(range(len(b) + 1))
    for i in range(1, len(a) + 1):
        cur = [i] + [0] * len(b)
        row_min = i
        for j in range(1, len(b) + 1):
            cost = 0 if a[i - 1] == b[j - 1] else 1
            cur[j] = min(cur[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost)
            row_min = min(row_min, cur[j])
        if row_min > max_dist:
            return max_dist + 1
        prev = cur
    return prev[len(b)]


def match_score(query: str, name: str) -> int:
    """امتیاز ۰ تا ۱۰۰ (هر دو ورودی نرمال‌شده)."""
    qc, nc = query.replace(" ", ""), name.replace(" ", "")
    q_tokens, n_tokens = query.split(" "), name.split(" ")
    if not qc:
        return 0
    if nc == qc:
        return 100
    if nc.startswith(qc):
        return 90
    if all(any(w.startswith(t) for w in n_tokens) for t in q_tokens):
        return 80
    if qc in nc:
        return 70
    tol = 0 if len(qc) <= 3 else (1 if len(qc) <= 6 else 2)
    if tol == 0:
        return 0
    d = levenshtein(qc, nc, tol)
    if d <= tol:
        return 60 - d * 5
    if len(nc) > len(qc):
        dp = levenshtein(qc, nc[: len(qc)], tol)
        if dp <= tol:
            return 50 - dp * 5
    for w in n_tokens:
        if len(w) < 4:
            continue
        dw = levenshtein(qc, w, tol)
        if dw <= tol:
            return 45 - dw * 5
    return 0
