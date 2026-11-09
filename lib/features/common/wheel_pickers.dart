import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../core/utils/jalali_date.dart';
import '../../core/utils/persian_digits.dart';

/// چرخ انتخاب یک مقدار از فهرست، با برچسب فارسی.
class ValueWheel<T> extends StatefulWidget {
  const ValueWheel({
    super.key,
    required this.values,
    required this.value,
    required this.label,
    required this.onChanged,
    this.height = 200,
    this.itemExtent = 44,
  });

  final List<T> values;
  final T value;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final double height;
  final double itemExtent;

  @override
  State<ValueWheel<T>> createState() => _ValueWheelState<T>();
}

class _ValueWheelState<T> extends State<ValueWheel<T>> {
  late FixedExtentScrollController _c;

  int get _index {
    final i = widget.values.indexOf(widget.value);
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    _c = FixedExtentScrollController(initialItem: _index);
  }

  @override
  void didUpdateWidget(covariant ValueWheel<T> old) {
    super.didUpdateWidget(old);
    // اگر فهرست یا مقدار از بیرون عوض شد (مثلاً تعداد روزهای ماه)، همگام کن.
    if (_c.hasClients && _c.selectedItem != _index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _c.hasClients) _c.jumpToItem(_index);
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: widget.itemExtent,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: _c,
            itemExtent: widget.itemExtent,
            physics: const FixedExtentScrollPhysics(),
            diameterRatio: 1.6,
            onSelectedItemChanged: (i) => widget.onChanged(widget.values[i]),
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: widget.values.length,
              builder: (context, i) => Center(
                child: Text(
                  widget.label(widget.values[i]),
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// چرخ عددی با ارقام فارسی.
class NumberWheel extends StatelessWidget {
  const NumberWheel({
    super.key,
    required this.values,
    required this.value,
    required this.onChanged,
    this.fractionDigits = 0,
  });

  final List<double> values;
  final double value;
  final ValueChanged<double> onChanged;
  final int fractionDigits;

  @override
  Widget build(BuildContext context) => ValueWheel<double>(
    values: values,
    value: _nearest(values, value),
    label: (v) => formatPersianNumber(v, fractionDigits: fractionDigits),
    onChanged: onChanged,
  );

  static double _nearest(List<double> values, double v) =>
      values.reduce((a, b) => (a - v).abs() <= (b - v).abs() ? a : b);
}

/// انتخابگر تاریخ شمسی با سه چرخ (روز، ماه، سال — از راست به چپ).
class JalaliDateWheel extends StatelessWidget {
  const JalaliDateWheel({
    super.key,
    required this.value,
    required this.minYear,
    required this.maxYear,
    required this.onChanged,
  });

  final DateTime value;
  final int minYear;
  final int maxYear;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final j = Jalali.fromDateTime(value);
    final year = j.year.clamp(minYear, maxYear);
    final monthLength = Jalali(year, j.month).monthLength;
    final day = j.day.clamp(1, monthLength);

    void emit(int y, int m, int d) {
      final len = Jalali(y, m).monthLength;
      onChanged(Jalali(y, m, d.clamp(1, len)).toDateTime());
    }

    return Row(
      children: [
        Expanded(
          child: ValueWheel<int>(
            values: [for (var d = 1; d <= monthLength; d++) d],
            value: day,
            label: (d) => toPersianDigits('$d'),
            onChanged: (d) => emit(year, j.month, d),
          ),
        ),
        Expanded(
          flex: 2,
          child: ValueWheel<int>(
            values: [for (var m = 1; m <= 12; m++) m],
            value: j.month,
            label: jalaliMonthName,
            onChanged: (m) => emit(year, m, day),
          ),
        ),
        Expanded(
          child: ValueWheel<int>(
            // جدیدترین سال بالا.
            values: [for (var y = maxYear; y >= minYear; y--) y],
            value: year,
            label: (y) => toPersianDigits('$y'),
            onChanged: (y) => emit(y, j.month, day),
          ),
        ),
      ],
    );
  }
}
