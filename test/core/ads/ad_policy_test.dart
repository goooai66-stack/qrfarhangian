import 'package:calorie_lens/core/ads/ad_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 11, 9, 10);
  DateTime at(int minutes) => start.add(Duration(minutes: minutes));
  const today = '2026-11-09';

  test('هرگز در ۲ دقیقه‌ی اول جلسه', () {
    final p = AdPolicy(sessionStart: start);
    expect(
      p.canShowInterstitial(now: at(1), today: today, premium: false),
      isFalse,
    );
    expect(
      p.canShowInterstitial(now: at(2), today: today, premium: false),
      isTrue,
    );
  });

  test('حداقل ۴ دقیقه فاصله', () {
    final p = AdPolicy(sessionStart: start)
      ..recordInterstitial(now: at(3), today: today);
    expect(
      p.canShowInterstitial(now: at(6), today: today, premium: false),
      isFalse,
    );
    expect(
      p.canShowInterstitial(now: at(7), today: today, premium: false),
      isTrue,
    );
  });

  test('حداکثر ۴ بار در روز؛ روز جدید از صفر', () {
    final p = AdPolicy(sessionStart: start);
    for (var i = 0; i < 4; i++) {
      final t = at(3 + i * 5);
      expect(
        p.canShowInterstitial(now: t, today: today, premium: false),
        isTrue,
      );
      p.recordInterstitial(now: t, today: today);
    }
    expect(
      p.canShowInterstitial(now: at(60), today: today, premium: false),
      isFalse,
    );
    expect(
      p.canShowInterstitial(
        now: at(60 * 24),
        today: '2026-11-10',
        premium: false,
      ),
      isTrue,
    );
  });

  test('کاربر ویژه هیچ‌وقت', () {
    final p = AdPolicy(sessionStart: start);
    expect(
      p.canShowInterstitial(now: at(30), today: today, premium: true),
      isFalse,
    );
  });
}
