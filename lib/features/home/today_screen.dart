import 'package:flutter/material.dart';

import '../../core/utils/jalali_date.dart';
import '../../l10n/app_localizations.dart';
import '../common/placeholder_view.dart';

/// تب «امروز» — داشبورد در مرحله‌ی ۲.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.tabToday)),
      body: PlaceholderView(
        icon: Icons.restaurant_outlined,
        message: t.todayPlaceholder,
        footer: Text(t.todayDate(formatJalaliWithWeekday(DateTime.now()))),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // جریان ثبت در مرحله‌ی ۲ و ۳.
        onPressed: null,
        icon: const Icon(Icons.photo_camera_outlined),
        label: Text(t.logFood),
      ),
    );
  }
}
