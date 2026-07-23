import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/sign_in_page.dart';
import '../../features/auth/presentation/sign_up_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/church/presentation/church_page.dart';
import '../../features/family/presentation/family_page.dart';
import '../../features/family/presentation/family_setup_page.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/journal/presentation/journal_editor_page.dart';
import '../../features/journal/presentation/journal_list_page.dart';
import '../../features/profile/application/profile_providers.dart';
import '../../features/profile/domain/user_role.dart';
import '../../features/profile/presentation/edit_profile_page.dart';
import '../../features/profile/presentation/profile_page.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const familySetup = '/family-setup';
  static const journal = '/journal';
  static const journalNew = '/journal/new';
  static const family = '/family';
  static const church = '/church';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
}

/// Bridges Riverpod to go_router: any change to the current profile (which
/// itself watches the auth session) re-runs the redirect ladder.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen(currentProfileProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}

final routerRefreshProvider = Provider<_RouterRefresh>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return refresh;
});

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: ref.watch(routerRefreshProvider),
    redirect: (context, state) {
      final profileState = ref.read(currentProfileProvider);
      final location = state.matchedLocation;
      final onAuthPage =
          location == Routes.signIn || location == Routes.signUp;

      // Still restoring the session / loading the profile row.
      if (profileState.isLoading) {
        return location == Routes.splash ? null : Routes.splash;
      }

      // A failed profile load must not trap the user on a blank splash.
      if (profileState.hasError) {
        return onAuthPage ? null : Routes.signIn;
      }

      final profile = profileState.value;

      if (profile == null) {
        return onAuthPage ? null : Routes.signIn;
      }

      // Parents and youth belong to a household; everything else in the app
      // is scoped by it, so setup has to happen before anything else.
      if (profile.role.requiresFamily && !profile.hasFamily) {
        return location == Routes.familySetup ? null : Routes.familySetup;
      }

      // Signed in and set up: bounce away from the entry pages.
      if (onAuthPage ||
          location == Routes.splash ||
          location == Routes.familySetup) {
        return _homeFor(profile.role);
      }

      // The church view would be empty for a household member anyway — RLS
      // returns them nothing — so don't leave them staring at it.
      if (location == Routes.church && !profile.role.isChurchStaff) {
        return _homeFor(profile.role);
      }

      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: Routes.signUp,
        builder: (context, state) => const SignUpPage(),
      ),
      GoRoute(
        path: Routes.familySetup,
        builder: (context, state) => const FamilySetupPage(),
      ),
      GoRoute(
        path: Routes.journalNew,
        builder: (context, state) => const JournalEditorPage(),
      ),
      GoRoute(
        path: Routes.editProfile,
        builder: (context, state) => const EditProfilePage(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            HomeShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: Routes.journal,
            builder: (context, state) => const JournalListPage(),
          ),
          GoRoute(
            path: Routes.family,
            builder: (context, state) => const FamilyPage(),
          ),
          GoRoute(
            path: Routes.church,
            builder: (context, state) => const ChurchPage(),
          ),
          GoRoute(
            path: Routes.profile,
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
    ],
  );
});

/// Church staff have no journal and no household of their own, so they land on
/// the church directory instead.
String _homeFor(UserRole role) =>
    role.isChurchStaff ? Routes.church : Routes.journal;
