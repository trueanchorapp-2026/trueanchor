import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/complete_signup_page.dart';
import '../../features/auth/presentation/sign_in_page.dart';
import '../../features/auth/presentation/sign_up_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/church/presentation/church_page.dart';
import '../../features/community/presentation/community_discussion_detail_page.dart';
import '../../features/community/presentation/community_discussion_editor_page.dart';
import '../../features/community/presentation/community_discussions_page.dart';
import '../../features/community/presentation/community_event_editor_page.dart';
import '../../features/community/presentation/community_events_page.dart';
import '../../features/community/presentation/community_manage_page.dart';
import '../../features/community/presentation/community_news_editor_page.dart';
import '../../features/community/presentation/community_news_page.dart';
import '../../features/community/presentation/community_resources_page.dart';
import '../../features/community/presentation/community_shell.dart';
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
import '../../features/journal/domain/journal_entry.dart';
import '../../features/journal/presentation/journal_editor_page.dart';
import '../../features/journal/presentation/journal_list_page.dart';
import '../../features/group_chat/presentation/group_chat_page.dart';
import '../../features/group_chat/presentation/group_manage_page.dart';
import '../../features/messaging/presentation/thread_list_page.dart';
import '../../features/messaging/presentation/thread_page.dart';
import '../../features/milestones/presentation/milestone_editor_page.dart';
import '../../features/milestones/presentation/milestone_list_page.dart';
import '../../features/relationships/presentation/interaction_editor_page.dart';
import '../../features/relationships/presentation/relationship_detail_page.dart';
import '../../features/relationships/presentation/relationship_editor_page.dart';
import '../../features/relationships/presentation/relationship_list_page.dart';
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

  // Discipleship sub-tabs (cont.)
  static const relationships = '/discipleship/relationships';
  static const discipleshipJournal = '/discipleship/journal';

  // Community sub-tabs
  static const communityNews = '/community/news';
  static const communityDiscussions = '/community/discussions';
  static const communityEvents = '/community/events';
  static const communityResources = '/community/resources';
  static const communityManage = '/community/manage';

  // Community drill-down routes
  static const communityNewsNew = '/community-news/new';
  static const communityNewsEdit = '/community-news/:id/edit';
  static const communityDiscussionNew = '/community-discussion/new';
  static const communityDiscussionDetail = '/community-discussion/:id';
  static const communityEventNew = '/community-event/new';

  // Drill-down routes
  static const journalNew = '/journal/new';
  static const journalEdit = '/journal/:id/edit';
  static const editMember = '/family/member/:id/edit';
  static const eventEditor = '/events/editor';
  static const messageThread = '/messages/thread/:id';
  static const milestoneNew = '/milestones/new';
  static const relationshipNew = '/relationships/new';
  static const relationshipDetail = '/relationships/:id';
  static const relationshipEdit = '/relationships/:id/edit';
  static const interactionNew = '/relationships/:id/interaction/new';
  static const groupChat = '/messages/group/:id';
  static const groupManage = '/messages/group/:id/manage';
  static const dashboard = '/dashboard';
  static const dashboardYouth = '/dashboard/youth/:id';
  static const editProfile = '/profile/edit';
  static const family = '/family';
  static const church = '/church';

  // Legacy — kept for staff navigation.
  static const journal = '/journal';

  static String journalEditFor(String entryId) => '/journal/$entryId/edit';

  static String journalNewFor({String? devotionalId, String? type}) {
    final params = <String, String>{};
    if (devotionalId != null) params['devotionalId'] = devotionalId;
    if (type != null) params['type'] = type;
    if (params.isEmpty) return journalNew;
    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return '$journalNew?$query';
  }

  static String messageThreadFor(String threadId) =>
      '/messages/thread/$threadId';

  static String dashboardYouthFor(String profileId) =>
      '/dashboard/youth/$profileId';

  static String editMemberFor(String memberId) =>
      '/family/member/$memberId/edit';

  static String relationshipDetailFor(String id) => '/relationships/$id';

  static String relationshipEditFor(String id) => '/relationships/$id/edit';

  static String interactionNewFor(String relationshipId) =>
      '/relationships/$relationshipId/interaction/new';

  static String groupChatFor(String groupId) => '/messages/group/$groupId';

  static String groupManageFor(String groupId) =>
      '/messages/group/$groupId/manage';

  static String communityNewsEditFor(String newsId) =>
      '/community-news/$newsId/edit';

  static String communityDiscussionDetailFor(String discussionId) =>
      '/community-discussion/$discussionId';
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

      // Messaging guard — covers inbox, thread drill-down, and group chat.
      if ((location.startsWith(Routes.messages) ||
              location.startsWith('/messages/thread') ||
              location.startsWith('/messages/group')) &&
          !profile.role.canUseMessaging) {
        return _homeFor(profile.role);
      }

      // Relationships tracker is youth-only.
      if ((location.startsWith(Routes.relationships) ||
              location.startsWith('/relationships')) &&
          !profile.role.canTrackRelationships) {
        return _homeFor(profile.role);
      }

      // Community is adults-only.
      if (location.startsWith(Routes.community) &&
          profile.role == UserRole.youth) {
        return _homeFor(profile.role);
      }

      // Redirect bare /community to the first sub-tab.
      if (location == Routes.community) {
        return Routes.communityNews;
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
        builder: (context, state) {
          final qp = state.uri.queryParameters;
          return JournalEditorPage(
            devotionalId: qp['devotionalId'],
            initialType: EntryType.tryFromWire(qp['type']),
          );
        },
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
      GoRoute(
        path: Routes.groupChat,
        builder: (context, state) =>
            GroupChatPage(groupId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.groupManage,
        builder: (context, state) =>
            GroupManagePage(groupId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.relationshipNew,
        builder: (context, state) => const RelationshipEditorPage(),
      ),
      GoRoute(
        path: Routes.relationshipEdit,
        builder: (context, state) => RelationshipEditorPage(
            relationshipId: state.pathParameters['id']),
      ),
      GoRoute(
        path: Routes.relationshipDetail,
        builder: (context, state) => RelationshipDetailPage(
            relationshipId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.interactionNew,
        builder: (context, state) => InteractionEditorPage(
            relationshipId: state.pathParameters['id']!),
      ),
      // Community drill-down routes (outside the shell).
      GoRoute(
        path: Routes.communityNewsNew,
        builder: (context, state) => const CommunityNewsEditorPage(),
      ),
      GoRoute(
        path: Routes.communityNewsEdit,
        builder: (context, state) =>
            CommunityNewsEditorPage(newsId: state.pathParameters['id']),
      ),
      GoRoute(
        path: Routes.communityDiscussionNew,
        builder: (context, state) =>
            const CommunityDiscussionEditorPage(),
      ),
      GoRoute(
        path: Routes.communityDiscussionDetail,
        builder: (context, state) => CommunityDiscussionDetailPage(
            discussionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.communityEventNew,
        builder: (context, state) => const CommunityEventEditorPage(),
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
                path: Routes.discipleshipJournal,
                builder: (context, state) => const JournalListPage(),
              ),
              GoRoute(
                path: '/discipleship/messages',
                builder: (context, state) => const ThreadListPage(),
              ),
              GoRoute(
                path: Routes.relationships,
                builder: (context, state) =>
                    const RelationshipListPage(),
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
          // Community sub-shell with filter chips.
          ShellRoute(
            builder: (context, state, child) => CommunityShell(
              location: state.matchedLocation,
              child: child,
            ),
            routes: [
              GoRoute(
                path: Routes.communityNews,
                builder: (context, state) => const CommunityNewsPage(),
              ),
              GoRoute(
                path: Routes.communityDiscussions,
                builder: (context, state) =>
                    const CommunityDiscussionsPage(),
              ),
              GoRoute(
                path: Routes.communityEvents,
                builder: (context, state) =>
                    const CommunityEventsPage(),
              ),
              GoRoute(
                path: Routes.communityResources,
                builder: (context, state) =>
                    const CommunityResourcesPage(),
              ),
              GoRoute(
                path: Routes.communityManage,
                builder: (context, state) =>
                    const CommunityManagePage(),
              ),
            ],
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
        ],
      ),
    ],
  );
});

String _homeFor(UserRole role) => switch (role) {
      _ when role.canViewEngagementDashboard => Routes.dashboard,
      _ when role.isChurchStaff => Routes.church,
      _ when role.isRegionalAdmin => Routes.communityManage,
      _ => Routes.today,
    };
