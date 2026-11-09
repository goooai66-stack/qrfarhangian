import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../core/nutrition/nutrition_types.dart';
import '../core/utils/jalali_date.dart';
import '../features/home/today_screen.dart';
import '../features/logging/food_detail_screen.dart';
import '../features/logging/food_search_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/plans/plans_screen.dart';
import '../features/profile/profile_edit_screen.dart';
import '../features/scan/photo_source.dart';
import '../features/scan/scan_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/progress/progress_screen.dart';
import 'home_shell.dart';

abstract final class Routes {
  static const onboarding = '/onboarding';
  static const today = '/today';
  static const progress = '/progress';
  static const plans = '/plans';
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';
  static const search = '/search';
  static const food = '/food';

  /// جستجو برای ثبت در [meal] از روز [day].
  static String searchFor({required MealType meal, required DateTime day}) =>
      Uri(
        path: search,
        queryParameters: {'meal': meal.name, 'date': dayKey(day)},
      ).toString();

  static String foodFor({
    required String foodId,
    required MealType meal,
    required DateTime day,
  }) => Uri(
    path: '$food/$foodId',
    queryParameters: {'meal': meal.name, 'date': dayKey(day)},
  ).toString();

  /// جستجو برای انتخاب یک غذا (نتیجه با pop برمی‌گردد).
  static const pickFood = '$search?pick=1';

  static const scan = '/scan';

  static String scanFor({
    required ScanSource source,
    required MealType meal,
    required DateTime day,
  }) => Uri(
    path: scan,
    queryParameters: {
      'source': source.name,
      'meal': meal.name,
      'date': dayKey(day),
    },
  ).toString();

  static String reviewPending(int id) =>
      Uri(path: scan, queryParameters: {'pending': '$id'}).toString();

  static String editLog({required String foodId, required int logId}) => Uri(
    path: '$food/$foodId',
    queryParameters: {'logId': '$logId'},
  ).toString();
}

MealType? _meal(String? name) =>
    MealType.values.where((m) => m.name == name).firstOrNull;

DateTime? _day(String? key) {
  if (key == null) return null;
  try {
    return parseDayKey(key);
  } on FormatException {
    return null;
  }
}

/// [onboardingDone] با تغییرش روتر را دوباره ارزیابی می‌کند.
GoRouter buildRouter(ValueListenable<bool> onboardingDone) => GoRouter(
  initialLocation: onboardingDone.value ? Routes.today : Routes.onboarding,
  refreshListenable: onboardingDone,
  redirect: (context, state) {
    final atOnboarding = state.matchedLocation.startsWith(Routes.onboarding);
    if (!onboardingDone.value && !atOnboarding) return Routes.onboarding;
    if (onboardingDone.value && atOnboarding) return Routes.today;
    return null;
  },
  routes: [
    GoRoute(
      path: Routes.onboarding,
      builder: (_, _) => const OnboardingScreen(),
    ),
    // جستجو و جزئیات غذا تمام‌صفحه‌اند (بیرون از تب‌ها).
    GoRoute(
      path: Routes.search,
      builder: (_, state) => FoodSearchScreen(
        meal: _meal(state.uri.queryParameters['meal']),
        day: _day(state.uri.queryParameters['date']),
        pickMode: state.uri.queryParameters['pick'] == '1',
      ),
    ),
    GoRoute(
      path: Routes.scan,
      builder: (_, state) {
        final q = state.uri.queryParameters;
        return ScanScreen(
          source: ScanSource.values
              .where((s) => s.name == q['source'])
              .firstOrNull,
          meal: _meal(q['meal']),
          day: _day(q['date']),
          pendingId: int.tryParse(q['pending'] ?? ''),
        );
      },
    ),
    GoRoute(
      path: '${Routes.food}/:id',
      builder: (_, state) => FoodDetailScreen(
        foodId: state.pathParameters['id']!,
        meal: _meal(state.uri.queryParameters['meal']),
        day: _day(state.uri.queryParameters['date']),
        logId: int.tryParse(state.uri.queryParameters['logId'] ?? ''),
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => HomeShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: Routes.today, builder: (_, _) => const TodayScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.progress,
              builder: (_, _) => const ProgressScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: Routes.plans, builder: (_, _) => const PlansScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.profile,
              builder: (_, _) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (_, _) => const ProfileEditScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
