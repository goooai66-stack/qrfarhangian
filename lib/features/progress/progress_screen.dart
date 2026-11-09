import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../common/placeholder_view.dart';

/// تب «پیشرفت» — مرحله‌ی ۴.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.tabProgress)),
      body: PlaceholderView(
        icon: Icons.monitor_weight_outlined,
        message: t.progressPlaceholder,
      ),
    );
  }
}
