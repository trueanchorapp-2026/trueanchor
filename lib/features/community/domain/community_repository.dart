import 'community.dart';
import 'community_discussion.dart';
import 'community_event.dart';
import 'community_membership.dart';
import 'feed_query.dart';
import 'published_post.dart';
import 'region.dart';
import 'topic_tag.dart';
import 'vote.dart';

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
  /// The caller's family membership (any adult in the family).
  Future<CommunityMembership?> fetchMyMembership();
  Future<List<CommunityMembership>> fetchMembers(String communityId);
  Future<CommunityMembership> joinCommunity(String communityId);
  Future<void> leaveCommunity();

  // Community admin (regional/app admin only)
  Future<List<CommunityAdminCandidate>> fetchAdminCandidates(
    String communityId,
  );

  /// Makes [userId] the admin for [membershipId]'s family; null revokes.
  Future<CommunityMembership> setAdmin({
    required String membershipId,
    String? userId,
  });

  // News & Parent Hub resources
  Future<List<PublishedPost>> searchPosts(
    PublishedKind kind,
    String communityId,
    FeedQuery query,
  );
  Future<PublishedPost?> fetchPost(PublishedKind kind, String postId);
  Future<PublishedPost> createPost({
    required PublishedKind kind,
    required String communityId,
    required String title,
    required String body,
    String? linkUrl,
    List<String> tagIds = const [],
  });
  Future<PublishedPost> updatePost({
    required PublishedKind kind,
    required String postId,
    required String title,
    required String body,
    String? linkUrl,
  });
  Future<void> deletePost(PublishedKind kind, String postId);
  Future<void> setPostTags({
    required PublishedKind kind,
    required String postId,
    required List<String> tagIds,
  });

  // Topic tags
  Future<List<TopicTag>> fetchTopicTags();

  // Discussions
  Future<List<CommunityDiscussion>> searchDiscussions(
    String communityId,
    FeedQuery query,
  );
  Future<CommunityDiscussion?> fetchDiscussion(String discussionId);

  /// Up to five discussions related to a news post (shared tags, then text).
  Future<List<CommunityDiscussion>> fetchRelatedDiscussions(String newsId);
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

  // Votes
  /// Sets the caller's vote (1, -1, or 0 to clear) and returns the new tally.
  Future<VoteTally> castVote({
    required VoteTarget target,
    required String itemId,
    required int value,
  });

  /// Toggles the caller's "helpful" mark on a reply.
  Future<({int helpfulCount, bool markedByMe})> toggleReplyHelpful(
    String replyId,
  );

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
