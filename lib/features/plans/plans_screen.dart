import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../common/placeholder_view.dart';

/// تب «برنامه‌ها» — P2.
class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.tabPlans)),
      body: PlaceholderView(
        icon: Icons.emoji_events_outlined,
        message: t.plansPlaceholder,
      ),
    );
  }
}
