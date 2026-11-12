import 'package:calorie_lens/core/utils/persian_digits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toPersianDigits', () {
    test('ارقام لاتین به فارسی', () {
      expect(toPersianDigits('0123456789'), '۰۱۲۳۴۵۶۷۸۹');
    });
    test('ارقام عربی به فارسی', () {
      expect(toPersianDigits('٠١٢٣٤٥٦٧٨٩'), '۰۱۲۳۴۵۶۷۸۹');
    });
    test('متن غیرعددی دست نمی‌خورد', () {
      expect(toPersianDigits('کالری 1850 kcal'), 'کالری ۱۸۵۰ kcal');
    });
  });

  group('toLatinDigits', () {
    test('فارسی و عربی به لاتین', () {
      expect(toLatinDigits('۱۲۳٤٥٦'), '123456');
    });
    test('رفت‌وبرگشت', () {
      expect(toLatinDigits(toPersianDigits('2026-11-09')), '2026-11-09');
    });
  });

  group('formatPersianNumber', () {
    test('جداکننده‌ی هزارگان', () {
      expect(formatPersianNumber(1850), '۱٬۸۵۰');
      expect(formatPersianNumber(1234567), '۱٬۲۳۴٬۵۶۷');
      expect(formatPersianNumber(999), '۹۹۹');
    });
    test('بدون جداکننده', () {
      expect(formatPersianNumber(1850, grouping: false), '۱۸۵۰');
    });
    test('اعشار با «٫» و حذف صفر انتهایی', () {
      expect(formatPersianNumber(0.5, fractionDigits: 2), '۰٫۵');
      expect(formatPersianNumber(72.25, fractionDigits: 1), '۷۲٫۳');
      expect(formatPersianNumber(70.0, fractionDigits: 1), '۷۰');
    });
    test('عدد منفی', () {
      expect(formatPersianNumber(-300), '−۳۰۰');
    });
  });

  group('parsePersianNumber', () {
    test('ورودی فارسی', () {
      expect(parsePersianNumber('۷۰٫۵'), 70.5);
      expect(parsePersianNumber('۱٬۸۵۰'), 1850);
      expect(parsePersianNumber(' 165 '), 165);
    });
    test('ورودی نامعتبر', () {
      expect(parsePersianNumber('abc'), isNull);
      expect(parsePersianNumber(''), isNull);
    });
  });
}
