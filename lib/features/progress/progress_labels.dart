import 'package:flutter/material.dart';

import '../../core/progress/badges.dart';
import '../../l10n/app_localizations.dart';

extension AchievementLabels on AppLocalizations {
  String achievementName(Achievement a) => switch (a) {
    Achievement.firstLog => badgeFirstLog,
    Achievement.streak3 => badgeStreak3,
    Achievement.streak7 => badgeStreak7,
    Achievement.firstKg => badgeFirstKg,
    Achievement.water8 => badgeWater8,
  };

  String achievementDesc(Achievement a) => switch (a) {
    Achievement.firstLog => badgeFirstLogDesc,
    Achievement.streak3 => badgeStreak3Desc,
    Achievement.streak7 => badgeStreak7Desc,
    Achievement.firstKg => badgeFirstKgDesc,
    Achievement.water8 => badgeWater8Desc,
  };
}

IconData achievementIcon(Achievement a) => switch (a) {
  Achievement.firstLog => Icons.restaurant,
  Achievement.streak3 => Icons.local_fire_department_outlined,
  Achievement.streak7 => Icons.local_fire_department,
  Achievement.firstKg => Icons.monitor_weight_outlined,
  Achievement.water8 => Icons.water_drop,
};
