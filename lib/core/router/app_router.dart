import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/complete_signup_page.dart';
import '../../features/auth/presentation/sign_in_page.dart';
import '../../features/auth/presentation/sign_up_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/church/presentation/church_page.dart';
import '../../features/devotionals/presentation/today_page.dart';
import '../../features/engagement/presentation/engagement_dashboard_page.dart';
import '../../features/engagement/presentation/youth_engagement_detail_page.dart';
import '../../features/events/domain/event.dart';
import '../../features/events/presentation/event_editor_page.dart';
import '../../features/events/presentation/event_list_page.dart';
import '../../features/family/presentation/family_page.dart';
import '../../features/family/presentation/family_setup_page.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/journal/presentation/journal_editor_page.dart';
import '../../features/journal/presentation/journal_list_page.dart';
import '../../features/messaging/presentation/thread_list_page.dart';
import '../../features/messaging/presentation/thread_page.dart';
import '../../features/milestones/presentation/milestone_editor_page.dart';
import '../../features/milestones/presentation/milestone_list_page.dart';
import '../../features/profile/application/profile_providers.dart';
import '../../features/profile/domain/user_role.dart';
import '../../features/profile/presentation/edit_profile_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../providers/supabase_providers.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const completeSignup = '/complete-signup';
  static const familySetup = '/family-setup';
  static const today = '/today';
  static const journal = '/journal';
  static const journalNew = '/journal/new';
  static const journalEdit = '/journal/:id/edit';
  static const editMember = '/family/member/:id/edit';
  static const events = '/events';
  static const eventEditor = '/events/editor';
  static const messages = '/messages';
  static const messageThread = '/messages/thread/:id';
  static const milestones = '/milestones';
  static const milestoneNew = '/milestones/new';
  static const family = '/family';
  static const church = '/church';
  static const dashboard = '/dashboard';
  static const dashboardYouth = '/dashboard/youth/:id';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';

  static String journalEditFor(String entryId) => '/journal/$entryId/edit';

  static String messageThreadFor(String threadId) =>
      '/messages/thread/$threadId';

  static String dashboardYouthFor(String profileId) =>
      '/dashboard/youth/$profileId';

  static String editMemberFor(String memberId) =>
      '/family/member/$memberId/edit';
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
        // A session with no profile is the OAuth path: the user authenticated
        // through Google but has not claimed a church code yet. Send them to
        // finish signup rather than back to the sign-in screen.
        final signedIn = ref.read(currentUserIdProvider) != null;
        if (signedIn) {
          return location == Routes.completeSignup
              ? null
              : Routes.completeSignup;
        }
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
          location == Routes.completeSignup ||
          location == Routes.familySetup) {
        return _homeFor(profile.role);
      }

      // The church view would be empty for a household member anyway — RLS
      // returns them nothing — so don't leave them staring at it.
      if (location == Routes.church && !profile.role.isChurchStaff) {
        return _homeFor(profile.role);
      }

      // youth_engagement_overview() raises NOT_AUTHORIZED for everyone else,
      // so this guard is what turns a would-be error screen into a redirect.
      if (location.startsWith(Routes.dashboard) &&
          !profile.role.canViewEngagementDashboard) {
        return _homeFor(profile.role);
      }

      // Messaging is between a household and its youth pastor. A church admin
      // reaching /messages would see an empty inbox they can never fill —
      // `open_thread()` raises ROLE_CANNOT_MESSAGE for them.
      if (location.startsWith(Routes.messages) &&
          !profile.role.canUseMessaging) {
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
        path: Routes.completeSignup,
        builder: (context, state) => const CompleteSignUpPage(),
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
        path: Routes.journalEdit,
        builder: (context, state) =>
            JournalEditorPage(entryId: state.pathParameters['id']),
      ),
      GoRoute(
        path: Routes.editMember,
        // Editing someone else's profile. The page re-checks that the target
        // really is in the caller's household, and RLS refuses regardless.
        builder: (context, state) =>
            EditProfilePage(memberId: state.pathParameters['id']),
      ),
      GoRoute(
        path: Routes.eventEditor,
        // A non-null Event means edit; null means create. Staff-only; the FAB
        // and edit affordances that reach here are already role-gated.
        builder: (context, state) =>
            EventEditorPage(event: state.extra as Event?),
      ),
      GoRoute(
        path: Routes.milestoneNew,
        builder: (context, state) => const MilestoneEditorPage(),
      ),
      GoRoute(
        path: Routes.editProfile,
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        // Top-level, like the thread page: a drill-down is a place you go into
        // and come back from, and it carries its own Message action.
        path: Routes.dashboardYouth,
        builder: (context, state) =>
            YouthEngagementDetailPage(profileId: state.pathParameters['id']!),
      ),
      GoRoute(
        // Outside the ShellRoute on purpose: a thread is a place you are in,
        // and it also keeps `/messages/thread/...` from lighting up the
        // Messages tab through HomeShell's startsWith match.
        path: Routes.messageThread,
        builder: (context, state) =>
            ThreadPage(threadId: state.pathParameters['id']!),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            HomeShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: Routes.today,
            builder: (context, state) => const TodayPage(),
          ),
          GoRoute(
            path: Routes.journal,
            builder: (context, state) => const JournalListPage(),
          ),
          GoRoute(
            path: Routes.events,
            builder: (context, state) => const EventListPage(),
          ),
          GoRoute(
            path: Routes.dashboard,
            builder: (context, state) => const EngagementDashboardPage(),
          ),
          GoRoute(
            path: Routes.messages,
            builder: (context, state) => const ThreadListPage(),
          ),
          GoRoute(
            path: Routes.milestones,
            builder: (context, state) => const MilestoneListPage(),
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

/// Members land on the daily devotional — the habit the app exists to build.
/// A youth pastor lands on the youth who need them, not on the directory.
/// Everyone else on the church staff lands on the directory.
String _homeFor(UserRole role) => switch (role) {
      _ when role.canViewEngagementDashboard => Routes.dashboard,
      _ when role.isChurchStaff => Routes.church,
      _ => Routes.today,
    };
