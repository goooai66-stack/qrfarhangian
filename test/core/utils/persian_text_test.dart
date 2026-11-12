import 'package:calorie_lens/core/utils/persian_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePersian', () {
    test('ي و ك عربی', () {
      expect(normalizePersian('قرمه سبزي'), 'قرمه سبزی');
      expect(normalizePersian('كشك بادمجان'), 'کشک بادمجان');
    });
    test('نیم‌فاصله و فاصله‌های اضافه به یک فاصله', () {
      expect(normalizePersian('قورمه‌سبزی'), 'قورمه سبزی');
      expect(normalizePersian('  ته   دیگ  '), 'ته دیگ');
    });
    test('اعراب و تطویل حذف می‌شوند', () {
      expect(normalizePersian('کَبابِ'), 'کباب');
      expect(normalizePersian('کـــباب'), 'کباب');
    });
    test('آ/أ/إ به ا و ة/ۀ به ه', () {
      expect(normalizePersian('آش'), 'اش');
      expect(normalizePersian('خانۀ'), 'خانه');
    });
    test('ارقام و حروف لاتین', () {
      expect(normalizePersian('Pizza ۲'), 'pizza 2');
    });
    test('شکل‌های مختلف یک نام برابر می‌شوند', () {
      final a = normalizePersian('قورمه‌سبزی');
      final b = normalizePersian('قورمه سبزي');
      expect(a, b);
    });
  });

  test('normalizePersianCompact همه‌ی فاصله‌ها را حذف می‌کند', () {
    expect(
      normalizePersianCompact('قورمه سبزی'),
      normalizePersianCompact('قورمه‌سبزي'),
    );
    expect(normalizePersianCompact('قورمه سبزی'), 'قورمهسبزی');
  });
}
