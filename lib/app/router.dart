import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../features/home/today_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/plans/plans_screen.dart';
import '../features/profile/profile_edit_screen.dart';
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
