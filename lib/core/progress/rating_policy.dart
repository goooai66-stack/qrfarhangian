/// درخواست امتیاز در بازار/مایکت (بخش ۴-۷): بعد از ۳ روز استفاده‌ی موفق،
/// بدون اصرار. «بعداً» ← دوباره بعد از ۷ روز؛ «نه» یا امتیاز داد ← دیگر هرگز.
library;

enum RatingState { none, later, done, never }

const ratingMinLoggedDays = 3;
const ratingRetryDays = 7;

bool shouldAskForRating({
  required int loggedDays,
  required RatingState state,
  required DateTime? lastAsked,
  required DateTime now,
}) {
  if (loggedDays < ratingMinLoggedDays) return false;
  return switch (state) {
    RatingState.none => true,
    RatingState.later =>
      lastAsked == null ||
          now.difference(lastAsked) >= const Duration(days: ratingRetryDays),
    RatingState.done || RatingState.never => false,
  };
}
