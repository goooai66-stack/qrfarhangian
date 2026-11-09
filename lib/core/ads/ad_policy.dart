/// قوانین دقیق نمایش تبلیغ (بخش ۹-۲)، خالص و قابل تست.
///
/// - تمام‌صفحه فقط بعد از ذخیره‌ی وعده؛ هرگز در ۲ دقیقه‌ی اول جلسه؛
///   حداقل ۴ دقیقه فاصله؛ حداکثر ۴ بار در روز.
/// - هیچ تبلیغی وسط اسکن، روی دوربین یا هنگام باز شدن اپ.
/// - کاربر ویژه هیچ تبلیغی نمی‌بیند.
library;

const interstitialSessionGrace = Duration(minutes: 2);
const interstitialMinGap = Duration(minutes: 4);
const interstitialMaxPerDay = 4;

class AdPolicy {
  AdPolicy({required this.sessionStart});

  final DateTime sessionStart;
  DateTime? lastInterstitial;

  /// روزی که [shownToday] برایش شمرده شده («YYYY-MM-DD»).
  String? countedDay;
  int shownToday = 0;

  bool canShowInterstitial({
    required DateTime now,
    required String today,
    required bool premium,
  }) {
    if (premium) return false;
    if (now.difference(sessionStart) < interstitialSessionGrace) return false;
    final last = lastInterstitial;
    if (last != null && now.difference(last) < interstitialMinGap) {
      return false;
    }
    final count = countedDay == today ? shownToday : 0;
    return count < interstitialMaxPerDay;
  }

  void recordInterstitial({required DateTime now, required String today}) {
    lastInterstitial = now;
    if (countedDay != today) {
      countedDay = today;
      shownToday = 0;
    }
    shownToday++;
  }
}
