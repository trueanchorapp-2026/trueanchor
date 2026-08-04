import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/complete_signup_page.dart';
import '../../features/auth/presentation/sign_in_page.dart';
import '../../features/auth/presentation/sign_up_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/church/presentation/church_page.dart';
import '../../features/community/presentation/community_page.dart';
import '../../features/devotionals/presentation/devotional_history_page.dart';
import '../../features/devotionals/presentation/today_page.dart';
import '../../features/engagement/presentation/engagement_dashboard_page.dart';
import '../../features/engagement/presentation/youth_engagement_detail_page.dart';
import '../../features/events/domain/event.dart';
import '../../features/events/presentation/event_editor_page.dart';
import '../../features/events/presentation/event_list_page.dart';
import '../../features/family/presentation/family_page.dart';
import '../../features/family/presentation/family_setup_page.dart';
import '../../features/home/presentation/discipleship_shell.dart';
import '../../features/home/presentation/home_page.dart';
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

  // Main tabs
  static const home = '/home';
  static const discipleship = '/discipleship';
  static const community = '/community';
  static const profile = '/profile';

  // Discipleship sub-tabs
  static const today = '/discipleship/today';
  static const devotionalHistory = '/discipleship/history';
  static const messages = '/discipleship/messages';
  static const milestones = '/discipleship/milestones';
  static const events = '/discipleship/events';

  // Drill-down routes
  static const journalNew = '/journal/new';
  static const journalEdit = '/journal/:id/edit';
  static const editMember = '/family/member/:id/edit';
  static const eventEditor = '/events/editor';
  static const messageThread = '/messages/thread/:id';
  static const milestoneNew = '/milestones/new';
  static const dashboard = '/dashboard';
  static const dashboardYouth = '/dashboard/youth/:id';
  static const editProfile = '/profile/edit';
  static const family = '/family';
  static const church = '/church';

  // Legacy — kept for staff navigation.
  static const journal = '/journal';

  static String journalEditFor(String entryId) => '/journal/$entryId/edit';

  static String messageThreadFor(String threadId) =>
      '/messages/thread/$threadId';

  static String dashboardYouthFor(String profileId) =>
      '/dashboard/youth/$profileId';

  static String editMemberFor(String memberId) =>
      '/family/member/$memberId/edit';
}

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

      if (profileState.isLoading) {
        return location == Routes.splash ? null : Routes.splash;
      }

      if (profileState.hasError) {
        return onAuthPage ? null : Routes.signIn;
      }

      final profile = profileState.value;

      if (profile == null) {
        final signedIn = ref.read(currentUserIdProvider) != null;
        if (signedIn) {
          return location == Routes.completeSignup
              ? null
              : Routes.completeSignup;
        }
        return onAuthPage ? null : Routes.signIn;
      }

      if (profile.role.requiresFamily && !profile.hasFamily) {
        return location == Routes.familySetup ? null : Routes.familySetup;
      }

      if (onAuthPage ||
          location == Routes.splash ||
          location == Routes.completeSignup ||
          location == Routes.familySetup) {
        return _homeFor(profile.role);
      }

      // Church view is staff-only.
      if (location == Routes.church && !profile.role.isChurchStaff) {
        return _homeFor(profile.role);
      }

      // Engagement dashboard is pastor/admin-only.
      if (location.startsWith(Routes.dashboard) &&
          !profile.role.canViewEngagementDashboard) {
        return _homeFor(profile.role);
      }

      // Messaging guard — covers both the inbox and thread drill-down.
      if ((location.startsWith(Routes.messages) ||
              location.startsWith('/messages/thread')) &&
          !profile.role.canUseMessaging) {
        return _homeFor(profile.role);
      }

      // Community is adults-only.
      if (location.startsWith(Routes.community) &&
          profile.role == UserRole.youth) {
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
      // Drill-down routes (outside the shell).
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
        builder: (context, state) =>
            EditProfilePage(memberId: state.pathParameters['id']),
      ),
      GoRoute(
        path: Routes.eventEditor,
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
        path: Routes.dashboardYouth,
        builder: (context, state) =>
            YouthEngagementDetailPage(profileId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.messageThread,
        builder: (context, state) =>
            ThreadPage(threadId: state.pathParameters['id']!),
      ),
      // Main shell with 4 tabs.
      ShellRoute(
        builder: (context, state, child) =>
            HomeShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (context, state) => const HomePage(),
          ),
          // Discipleship sub-shell with filter chips.
          ShellRoute(
            builder: (context, state, child) => DiscipleshipShell(
              location: state.matchedLocation,
              child: child,
            ),
            routes: [
              GoRoute(
                path: Routes.today,
                builder: (context, state) => const TodayPage(),
              ),
              GoRoute(
                path: Routes.devotionalHistory,
                builder: (context, state) =>
                    const DevotionalHistoryPage(),
              ),
              GoRoute(
                path: '/discipleship/messages',
                builder: (context, state) => const ThreadListPage(),
              ),
              GoRoute(
                path: '/discipleship/milestones',
                builder: (context, state) => const MilestoneListPage(),
              ),
              GoRoute(
                path: '/discipleship/events',
                builder: (context, state) => const EventListPage(),
              ),
            ],
          ),
          GoRoute(
            path: Routes.community,
            builder: (context, state) => const CommunityPage(),
          ),
          GoRoute(
            path: Routes.profile,
            builder: (context, state) => const ProfilePage(),
          ),
          // Staff routes kept at root level inside the shell.
          GoRoute(
            path: Routes.dashboard,
            builder: (context, state) => const EngagementDashboardPage(),
          ),
          GoRoute(
            path: Routes.church,
            builder: (context, state) => const ChurchPage(),
          ),
          GoRoute(
            path: Routes.family,
            builder: (context, state) => const FamilyPage(),
          ),
          GoRoute(
            path: Routes.journal,
            builder: (context, state) => const JournalListPage(),
          ),
          GoRoute(
            path: Routes.events,
            builder: (context, state) => const EventListPage(),
          ),
        ],
      ),
    ],
  );
});

String _homeFor(UserRole role) => switch (role) {
      _ when role.canViewEngagementDashboard => Routes.dashboard,
      _ when role.isChurchStaff => Routes.church,
      _ => Routes.today,
    };
