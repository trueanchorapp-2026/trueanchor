import 'community.dart';
import 'community_discussion.dart';
import 'community_event.dart';
import 'community_membership.dart';
import 'community_news.dart';
import 'discussion_query.dart';
import 'parent_resource.dart';
import 'region.dart';
import 'topic_tag.dart';

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

  // Topic tags
  Future<List<TopicTag>> fetchTopicTags();

  // Discussions
  Future<List<CommunityDiscussion>> searchDiscussions(
    String communityId,
    DiscussionQuery query,
  );
  Future<String> uploadDiscussionImage({
    required String fileName,
    required List<int> bytes,
  });
  Future<CommunityDiscussion> createDiscussion({
    required String communityId,
    required String title,
    required String body,
    List<String> imageUrls = const [],
    List<String> tagIds = const [],
  });
  Future<void> setDiscussionTags({
    required String discussionId,
    required List<String> tagIds,
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
    List<String> imageUrls = const [],
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

  // Parent Resources
  Future<List<ParentResource>> fetchParentResources();
}
