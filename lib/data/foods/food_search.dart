import 'dart:math' as math;

import '../../core/utils/persian_text.dart';
import 'food.dart';

/// جستجوی فازی فارسی روی نام و نام‌های دیگر غذاها.
///
/// مقاوم به «ی/ي»، «ک/ك»، نیم‌فاصله، فاصله و غلط تایپی کوچک.
/// رتبه‌بندی: میزان تطابق، سپس دفعات استفاده‌ی کاربر، سپس نام.
class FoodSearchIndex {
  FoodSearchIndex(List<Food> foods)
    : _entries = [
        for (final f in foods)
          _Entry(f, [
            for (final n in {f.nameFa, ...f.aliases, ?f.nameEn})
              _Name(normalizePersian(n)),
          ]),
      ];

  final List<_Entry> _entries;

  List<Food> search(
    String query, {
    Map<String, int> frequency = const {},
    int limit = 50,
  }) {
    final q = normalizePersian(query);
    if (q.isEmpty) return const [];
    final qc = q.replaceAll(' ', '');
    final qTokens = q.split(' ');

    final scored = <(Food, int)>[];
    for (final e in _entries) {
      var best = 0;
      for (final n in e.names) {
        best = math.max(best, _score(q, qc, qTokens, n));
        if (best == 100) break;
      }
      if (best > 0) scored.add((e.food, best));
    }
    scored.sort((a, b) {
      final s = b.$2.compareTo(a.$2);
      if (s != 0) return s;
      final f = (frequency[b.$1.id] ?? 0).compareTo(frequency[a.$1.id] ?? 0);
      if (f != 0) return f;
      return a.$1.nameFa.compareTo(b.$1.nameFa);
    });
    return [for (final s in scored.take(limit)) s.$1];
  }

  static int _score(String q, String qc, List<String> qTokens, _Name n) {
    if (n.compact == qc) return 100;
    if (n.compact.startsWith(qc)) return 90;
    // همه‌ی کلمه‌های جستجو، شروع یکی از کلمه‌های نام‌اند: «کباب کو» ← کباب کوبیده
    if (qTokens.every((t) => n.tokens.any((w) => w.startsWith(t)))) return 80;
    if (n.compact.contains(qc)) return 70;

    // غلط تایپی: کل نام یا ابتدای نام.
    final tol = qc.length <= 3 ? 0 : (qc.length <= 6 ? 1 : 2);
    if (tol == 0) return 0;
    final d = levenshtein(qc, n.compact, max: tol);
    if (d <= tol) return 60 - d * 5;
    if (n.compact.length > qc.length) {
      final dp = levenshtein(qc, n.compact.substring(0, qc.length), max: tol);
      if (dp <= tol) return 50 - dp * 5;
    }
    // غلط تایپی در یک کلمه: «کوبیدع» ← کباب کوبیده
    for (final w in n.tokens) {
      if (w.length < 4) continue;
      final dw = levenshtein(qc, w, max: tol);
      if (dw <= tol) return 45 - dw * 5;
    }
    return 0;
  }
}

class _Entry {
  _Entry(this.food, this.names);
  final Food food;
  final List<_Name> names;
}

class _Name {
  _Name(String normalized)
    : compact = normalized.replaceAll(' ', ''),
      tokens = normalized.split(' ');
  final String compact;
  final List<String> tokens;
}

/// فاصله‌ی ویرایشی؛ اگر از [max] بیشتر شد، زودتر `max + 1` برمی‌گرداند.
int levenshtein(String a, String b, {int max = 1 << 30}) {
  if ((a.length - b.length).abs() > max) return max + 1;
  if (a == b) return 0;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  var cur = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    cur[0] = i;
    var rowMin = cur[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = math.min(
        math.min(cur[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + cost,
      );
      rowMin = math.min(rowMin, cur[j]);
    }
    if (rowMin > max) return max + 1;
    final t = prev;
    prev = cur;
    cur = t;
  }
  return prev[b.length];
}
