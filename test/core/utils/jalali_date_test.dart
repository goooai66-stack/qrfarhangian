import 'package:calorie_lens/core/utils/jalali_date.dart';
import 'package:calorie_lens/l10n/app_localizations_fa.dart';
import 'package:calorie_lens/l10n/date_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ۱ فروردین ۱۴۰۵ = ۲۱ مارس ۲۰۲۶ (شنبه)
  final nowruz1405 = DateTime(2026, 3, 21);

  final t = AppLocalizationsFa();

  test('قالب بلند شمسی (نام‌ها از فایل ترجمه)', () {
    expect(t.formatDateLong(nowruz1405), '۱ فروردین ۱۴۰۵');
  });

  test('قالب کوتاه شمسی', () {
    expect(formatJalaliShort(DateTime(2026, 11, 9)), '۱۴۰۵/۰۸/۱۸');
  });

  test('قالب با نام روز', () {
    expect(t.formatDateWithWeekday(nowruz1405), 'شنبه ۱ فروردین ۱۴۰۵');
    expect(
      t.formatDateWithWeekday(DateTime(2026, 11, 9)),
      'دوشنبه ۱۸ آبان ۱۴۰۵',
    );
  });

  test('هفته از شنبه شروع می‌شود', () {
    expect(weekdayIndexFromSaturday(DateTime(2026, 11, 7)), 0); // شنبه
    expect(weekdayIndexFromSaturday(DateTime(2026, 11, 13)), 6); // جمعه
    expect(startOfWeek(DateTime(2026, 11, 13, 15)), DateTime(2026, 11, 7));
    expect(startOfWeek(DateTime(2026, 11, 7)), DateTime(2026, 11, 7));
  });

  test('تبدیل شمسی به میلادی', () {
    expect(jalaliToDateTime(1405, 1, 1), nowruz1405);
  });

  test('ذخیره به UTC/ISO', () {
    final d = DateTime.utc(2026, 11, 9, 8, 30);
    expect(toStorageIso(d), '2026-11-09T08:30:00.000Z');
  });

  test('کلید روز', () {
    expect(dayKey(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
  });

  test('نام ماه‌ها', () {
    expect(t.monthName(1), 'فروردین');
    expect(t.monthName(12), 'اسفند');
    expect(t.jalaliMonths, hasLength(12));
  });

  test('نام روزها از شنبه و شکل کوتاه', () {
    expect(t.weekdays.first, 'شنبه');
    expect(t.weekdays.last, 'جمعه');
    expect(t.weekdayShort(DateTime(2026, 11, 10)), 'س'); // سه‌شنبه
    expect(t.weekdaysShort, ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج']);
  });
}
