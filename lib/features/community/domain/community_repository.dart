import 'community.dart';
import 'community_discussion.dart';
import 'community_event.dart';
import 'community_membership.dart';
import 'community_news.dart';
import 'region.dart';

abstract interface class CommunityRepository {
  // Regions
  Future<List<Region>> fetchRegions();
  Future<Region> createRegion({required String name});
  Future<void> deleteRegion(String regionId);

  // Communities
  Future<List<Community>> fetchCommunities({String? regionId});
  Future<Community> createCommunity({
    required String regionId,
    required String name,
    String? city,
    String? state,
  });
  Future<Community> updateCommunity({
    required String communityId,
    required String name,
    String? city,
    String? state,
  });
  Future<void> deleteCommunity(String communityId);

  // Memberships
  Future<CommunityMembership?> fetchMyMembership();
  Future<List<CommunityMembership>> fetchMembers(String communityId);
  Future<CommunityMembership> joinCommunity(String communityId);
  Future<void> leaveCommunity();
  Future<CommunityMembership> setAdmin({
    required String membershipId,
    required bool isAdmin,
  });

  // News
  Future<List<CommunityNewsItem>> fetchNews(String communityId);
  Future<CommunityNewsItem> createNews({
    required String communityId,
    required String title,
    required String body,
  });
  Future<CommunityNewsItem> updateNews({
    required String newsId,
    required String title,
    required String body,
  });
  Future<void> deleteNews(String newsId);

  // Discussions
  Future<List<CommunityDiscussion>> fetchDiscussions(String communityId);
  Future<CommunityDiscussion> createDiscussion({
    required String communityId,
    required String title,
    required String body,
  });
  Future<CommunityDiscussion> updateDiscussion({
    required String discussionId,
    required String title,
    required String body,
  });
  Future<void> deleteDiscussion(String discussionId);

  // Replies
  Future<List<DiscussionReply>> fetchReplies(String discussionId);
  Future<DiscussionReply> createReply({
    required String discussionId,
    required String body,
  });
  Future<void> deleteReply(String replyId);

  // Events
  Future<List<CommunityEvent>> fetchEvents(String communityId);
  Future<CommunityEvent> createEvent({
    required String communityId,
    required String title,
    String? description,
    String? location,
    required DateTime startsAt,
    DateTime? endsAt,
  });
  Future<CommunityEvent> updateEvent({
    required String eventId,
    required String title,
    String? description,
    String? location,
    required DateTime startsAt,
    DateTime? endsAt,
  });
  Future<void> deleteEvent(String eventId);
}
