import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../domain/community.dart';
import '../domain/community_discussion.dart';
import '../domain/community_event.dart';
import '../domain/community_membership.dart';
import '../domain/community_repository.dart';
import '../domain/discussion_image.dart';
import '../domain/feed_query.dart';
import '../domain/published_post.dart';
import '../domain/region.dart';
import '../domain/topic_tag.dart';
import '../domain/vote.dart';

class SupabaseCommunityRepository implements CommunityRepository {
  SupabaseCommunityRepository(this._client);

  final SupabaseClient _client;

  static var _uploadSeq = 0;

  String get _uid => _client.auth.currentUser!.id;

  // ── Regions ──────────────────────────────────────────────────────────────

  @override
  Future<List<Region>> fetchRegions() async {
    try {
      final rows = await _client
          .from('regions')
          .select()
          .order('name');
      return rows.map(Region.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<Region> createRegion({required String name}) async {
    try {
      final row = await _client
          .from('regions')
          .insert(Region.toInsertJson(name: name))
          .select()
          .single();
      return Region.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> deleteRegion(String regionId) async {
    try {
      await _client.from('regions').delete().eq('id', regionId);
    } catch (e) {
      throw mapError(e);
    }
  }

  // ── Communities ──────────────────────────────────────────────────────────

  @override
  Future<List<Community>> fetchCommunities({String? regionId}) async {
    try {
      var query = _client.from('communities').select();
      if (regionId != null) {
        query = query.eq('region_id', regionId);
      }
      final rows = await query.order('name');
      return rows.map(Community.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<Community> createCommunity({
    required String regionId,
    required String name,
    String? city,
    String? state,
  }) async {
    try {
      final row = await _client
          .from('communities')
          .insert(Community.toInsertJson(
            regionId: regionId,
            name: name,
            city: city,
            state: state,
          ))
          .select()
          .single();
      return Community.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<Community> updateCommunity({
    required String communityId,
    required String name,
    String? city,
    String? state,
  }) async {
    try {
      final row = await _client
          .from('communities')
          .update(Community.toUpdateJson(name: name, city: city, state: state))
          .eq('id', communityId)
          .select()
          .single();
      return Community.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> deleteCommunity(String communityId) async {
    try {
      await _client.from('communities').delete().eq('id', communityId);
    } catch (e) {
      throw mapError(e);
    }
  }

  // ── Memberships ─────────────────────────────────────────────────────────

  static const _membershipSelect = '*, family:families(name)';

  @override
  Future<CommunityMembership?> fetchMyMembership() async {
    try {
      // Matches on the caller's family, so every adult in the family (not
      // only the one who joined) sees the membership.
      final rows = await _client
          .rpc<List<dynamic>>('my_community_membership')
          .select(_membershipSelect)
          .limit(1);
      if (rows.isEmpty) return null;
      return CommunityMembership.fromJson(rows.first);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<CommunityMembership>> fetchMembers(String communityId) async {
    try {
      final rows = await _client
          .from('community_memberships')
          .select(_membershipSelect)
          .eq('community_id', communityId)
          .order('joined_at');
      return rows.map(CommunityMembership.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<CommunityMembership> joinCommunity(String communityId) async {
    try {
      final row = await _client
          .rpc('join_community', params: {'p_community_id': communityId});
      return CommunityMembership.fromJson(row as Map<String, dynamic>);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> leaveCommunity() async {
    try {
      await _client.rpc('leave_community');
    } catch (e) {
      throw mapError(e);
    }
  }

  // ── Community admin ─────────────────────────────────────────────────────

  @override
  Future<List<CommunityAdminCandidate>> fetchAdminCandidates(
    String communityId,
  ) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'list_community_admin_candidates',
        params: {'p_community_id': communityId},
      );
      return rows
          .cast<Map<String, dynamic>>()
          .map(CommunityAdminCandidate.fromJson)
          .toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<CommunityMembership> setAdmin({
    required String membershipId,
    String? userId,
  }) async {
    try {
      final row = await _client.rpc('set_community_admin', params: {
        'p_membership_id': membershipId,
        'p_user_id': userId,
      });
      return CommunityMembership.fromJson(row as Map<String, dynamic>);
    } catch (e) {
      throw mapError(e);
    }
  }

  // ── News & Parent Hub resources ─────────────────────────────────────────

  static String _postTable(PublishedKind kind) => switch (kind) {
        PublishedKind.news => 'community_news',
        PublishedKind.resource => 'parent_resources',
      };

  static String _postSearchRpc(PublishedKind kind) => switch (kind) {
        PublishedKind.news => 'search_community_news',
        PublishedKind.resource => 'search_parent_resources',
      };

  static String _postSelect(PublishedKind kind) => switch (kind) {
        PublishedKind.news =>
          '*, author:profiles!author_id(first_name, last_name), '
              'tags:community_news_tags(tag_id), '
              'my_votes:community_news_votes(value)',
        PublishedKind.resource =>
          '*, author:profiles!author_id(first_name, last_name), '
              'tags:parent_resource_tags(tag_id), '
              'my_votes:parent_resource_votes(value)',
      };

  @override
  Future<List<PublishedPost>> searchPosts(
    PublishedKind kind,
    String communityId,
    FeedQuery query,
  ) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        _postSearchRpc(kind),
        params: query.toRpcParams(communityId),
      );
      return [
        for (final row in rows.cast<Map<String, dynamic>>())
          PublishedPost.fromJson(kind, row),
      ];
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<PublishedPost?> fetchPost(PublishedKind kind, String postId) async {
    try {
      final row = await _client
          .from(_postTable(kind))
          .select(_postSelect(kind))
          .eq('id', postId)
          .maybeSingle();
      return row == null ? null : PublishedPost.fromJson(kind, row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<PublishedPost> createPost({
    required PublishedKind kind,
    required String communityId,
    required String title,
    required String body,
    String? linkUrl,
    List<String> tagIds = const [],
  }) async {
    try {
      final row = await _client
          .from(_postTable(kind))
          .insert({
            ...PublishedPost.toWriteJson(
              title: title,
              body: body,
              linkUrl: linkUrl,
            ),
            'community_id': communityId,
            'author_id': _uid,
          })
          .select(_postSelect(kind))
          .single();
      final created = PublishedPost.fromJson(kind, row);
      if (tagIds.isEmpty) return created;
      await setPostTags(kind: kind, postId: created.id, tagIds: tagIds);
      return created.copyWith(tagIds: tagIds);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<PublishedPost> updatePost({
    required PublishedKind kind,
    required String postId,
    required String title,
    required String body,
    String? linkUrl,
  }) async {
    try {
      final row = await _client
          .from(_postTable(kind))
          .update(PublishedPost.toWriteJson(
            title: title,
            body: body,
            linkUrl: linkUrl,
          ))
          .eq('id', postId)
          .select(_postSelect(kind))
          .single();
      return PublishedPost.fromJson(kind, row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> deletePost(PublishedKind kind, String postId) async {
    try {
      await _client.from(_postTable(kind)).delete().eq('id', postId);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> setPostTags({
    required PublishedKind kind,
    required String postId,
    required List<String> tagIds,
  }) async {
    try {
      await _client.rpc<void>('set_post_tags', params: {
        'p_kind': kind.wireValue,
        'p_post_id': postId,
        'p_tag_ids': tagIds,
      });
    } catch (e) {
      throw mapError(e);
    }
  }

  // ── Topic tags ──────────────────────────────────────────────────────────

  @override
  Future<List<TopicTag>> fetchTopicTags() async {
    try {
      final rows = await _client
          .from('topic_tags')
          .select()
          .eq('is_active', true)
          .order('sort_order');
      return rows.map(TopicTag.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  // ── Discussions ─────────────────────────────────────────────────────────

  @override
  Future<List<CommunityDiscussion>> searchDiscussions(
    String communityId,
    FeedQuery query,
  ) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'search_community_discussions',
        params: query.toRpcParams(communityId),
      );
      return rows
          .cast<Map<String, dynamic>>()
          .map(CommunityDiscussion.fromJson)
          .toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<CommunityDiscussion?> fetchDiscussion(String discussionId) async {
    try {
      final row = await _client
          .from('community_discussions')
          .select('*, author:profiles!author_id(first_name, last_name), '
              'tags:community_discussion_tags(tag_id), '
              'my_votes:community_discussion_votes(value)')
          .eq('id', discussionId)
          .maybeSingle();
      return row == null ? null : CommunityDiscussion.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<CommunityDiscussion>> fetchRelatedDiscussions(
    String newsId,
  ) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'related_discussions',
        params: {'p_news_id': newsId, 'p_limit': 5},
      );
      return rows
          .cast<Map<String, dynamic>>()
          .map(CommunityDiscussion.fromJson)
          .toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<String> uploadDiscussionImage({
    required String fileName,
    required List<int> bytes,
  }) async {
    try {
      // The first folder must be the uploader's id: 0028's storage policies
      // match on it. The sequence number keeps parallel uploads of
      // same-named files (common on web) from colliding.
      final path = '$_uid/${DateTime.now().millisecondsSinceEpoch}_'
          '${_uploadSeq++}_${DiscussionImages.safeFileName(fileName)}';
      await _client.storage.from('discussion-images').uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(
              contentType: DiscussionImages.contentTypeFor(fileName),
            ),
          );
      return _client.storage
          .from('discussion-images')
          .getPublicUrl(path);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<CommunityDiscussion> createDiscussion({
    required String communityId,
    required String title,
    required String body,
    List<String> imageUrls = const [],
    List<String> tagIds = const [],
  }) async {
    try {
      final row = await _client
          .from('community_discussions')
          .insert(CommunityDiscussion.toInsertJson(
            communityId: communityId,
            authorId: _uid,
            title: title,
            body: body,
            imageUrls: imageUrls,
          ))
          .select()
          .single();
      final created = CommunityDiscussion.fromJson(row);
      if (tagIds.isEmpty) return created;
      await setDiscussionTags(discussionId: created.id, tagIds: tagIds);
      return created.copyWith(tagIds: tagIds);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> setDiscussionTags({
    required String discussionId,
    required List<String> tagIds,
  }) async {
    try {
      await _client.rpc<void>('set_discussion_tags', params: {
        'p_discussion_id': discussionId,
        'p_tag_ids': tagIds,
      });
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<CommunityDiscussion> updateDiscussion({
    required String discussionId,
    required String title,
    required String body,
  }) async {
    try {
      final row = await _client
          .from('community_discussions')
          .update(
              CommunityDiscussion.toUpdateJson(title: title, body: body))
          .eq('id', discussionId)
          .select()
          .single();
      return CommunityDiscussion.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> deleteDiscussion(String discussionId) async {
    try {
      await _client
          .from('community_discussions')
          .delete()
          .eq('id', discussionId);
    } catch (e) {
      throw mapError(e);
    }
  }

  // ── Replies ─────────────────────────────────────────────────────────────

  @override
  Future<List<DiscussionReply>> fetchReplies(String discussionId) async {
    try {
      final rows = await _client
          .from('community_discussion_replies')
          .select('*, author:profiles!author_id(first_name, last_name), '
              'my_votes:community_reply_votes(user_id)')
          .eq('discussion_id', discussionId)
          .order('created_at');
      return rows.map(DiscussionReply.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<DiscussionReply> createReply({
    required String discussionId,
    required String body,
    List<String> imageUrls = const [],
  }) async {
    try {
      final row = await _client
          .from('community_discussion_replies')
          .insert(DiscussionReply.toInsertJson(
            discussionId: discussionId,
            authorId: _uid,
            body: body,
            imageUrls: imageUrls,
          ))
          .select()
          .single();
      return DiscussionReply.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> deleteReply(String replyId) async {
    try {
      await _client
          .from('community_discussion_replies')
          .delete()
          .eq('id', replyId);
    } catch (e) {
      throw mapError(e);
    }
  }

  // ── Votes ───────────────────────────────────────────────────────────────

  @override
  Future<VoteTally> castVote({
    required VoteTarget target,
    required String itemId,
    required int value,
  }) async {
    try {
      final rows = await _client.rpc<List<dynamic>>('cast_vote', params: {
        'p_kind': target.wireValue,
        'p_item_id': itemId,
        'p_value': value,
      });
      return VoteTally.fromJson(rows.first as Map<String, dynamic>);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<({int helpfulCount, bool markedByMe})> toggleReplyHelpful(
    String replyId,
  ) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'toggle_reply_helpful',
        params: {'p_reply_id': replyId},
      );
      final row = rows.first as Map<String, dynamic>;
      return (
        helpfulCount: (row['helpful_count'] as num?)?.toInt() ?? 0,
        markedByMe: row['liked_by_me'] as bool? ?? false,
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  // ── Events ──────────────────────────────────────────────────────────────

  @override
  Future<List<CommunityEvent>> fetchEvents(String communityId) async {
    try {
      final rows = await _client
          .from('community_events')
          .select()
          .eq('community_id', communityId)
          .order('starts_at');
      return rows.map(CommunityEvent.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<CommunityEvent> createEvent({
    required String communityId,
    required String title,
    String? description,
    String? location,
    required DateTime startsAt,
    DateTime? endsAt,
  }) async {
    try {
      final row = await _client
          .from('community_events')
          .insert(CommunityEvent.toWriteJson(
            communityId: communityId,
            title: title,
            description: description,
            location: location,
            startsAt: startsAt,
            endsAt: endsAt,
          ))
          .select()
          .single();
      return CommunityEvent.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<CommunityEvent> updateEvent({
    required String eventId,
    required String title,
    String? description,
    String? location,
    required DateTime startsAt,
    DateTime? endsAt,
  }) async {
    try {
      final row = await _client
          .from('community_events')
          .update(CommunityEvent.toWriteJson(
            communityId: '',
            title: title,
            description: description,
            location: location,
            startsAt: startsAt,
            endsAt: endsAt,
          )..remove('community_id'))
          .eq('id', eventId)
          .select()
          .single();
      return CommunityEvent.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    try {
      await _client.from('community_events').delete().eq('id', eventId);
    } catch (e) {
      throw mapError(e);
    }
  }
}
