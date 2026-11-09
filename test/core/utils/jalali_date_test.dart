import 'package:calorie_lens/core/utils/jalali_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ۱ فروردین ۱۴۰۵ = ۲۱ مارس ۲۰۲۶ (شنبه)
  final nowruz1405 = DateTime(2026, 3, 21);

  test('قالب بلند شمسی', () {
    expect(formatJalaliLong(nowruz1405), '۱ فروردین ۱۴۰۵');
  });

  test('قالب کوتاه شمسی', () {
    expect(formatJalaliShort(DateTime(2026, 11, 9)), '۱۴۰۵/۰۸/۱۸');
  });

  test('قالب با نام روز', () {
    expect(formatJalaliWithWeekday(nowruz1405), 'شنبه ۱ فروردین ۱۴۰۵');
    expect(
      formatJalaliWithWeekday(DateTime(2026, 11, 9)),
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
    expect(jalaliMonthName(1), 'فروردین');
    expect(jalaliMonthName(12), 'اسفند');
  });
}
