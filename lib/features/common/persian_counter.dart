import 'package:flutter/material.dart';

import '../../core/utils/persian_digits.dart';

/// شمارنده‌ی کاراکتر TextField با ارقام فارسی («۴۲/۳۰۰»).
/// استفاده: `buildCounter: persianCounter`
Widget? persianCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => maxLength == null
    ? null
    : Text(
        toPersianDigits('$currentLength/$maxLength'),
        style: Theme.of(context).textTheme.bodySmall,
      );
