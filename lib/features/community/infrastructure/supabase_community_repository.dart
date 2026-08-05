import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../domain/community.dart';
import '../domain/community_discussion.dart';
import '../domain/community_event.dart';
import '../domain/community_membership.dart';
import '../domain/community_news.dart';
import '../domain/community_repository.dart';
import '../domain/region.dart';

class SupabaseCommunityRepository implements CommunityRepository {
  SupabaseCommunityRepository(this._client);

  final SupabaseClient _client;

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

  @override
  Future<CommunityMembership?> fetchMyMembership() async {
    try {
      final rows = await _client
          .from('community_memberships')
          .select('*, family:families(name)')
          .eq('joined_by', _uid)
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
          .select('*, family:families(name)')
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

  @override
  Future<CommunityMembership> setAdmin({
    required String membershipId,
    required bool isAdmin,
  }) async {
    try {
      final row = await _client.rpc('set_community_admin', params: {
        'p_membership_id': membershipId,
        'p_is_admin': isAdmin,
      });
      return CommunityMembership.fromJson(row as Map<String, dynamic>);
    } catch (e) {
      throw mapError(e);
    }
  }

  // ── News ────────────────────────────────────────────────────────────────

  @override
  Future<List<CommunityNewsItem>> fetchNews(String communityId) async {
    try {
      final rows = await _client
          .from('community_news')
          .select('*, author:profiles!author_id(first_name, last_name)')
          .eq('community_id', communityId)
          .order('created_at', ascending: false);
      return rows.map(CommunityNewsItem.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<CommunityNewsItem> createNews({
    required String communityId,
    required String title,
    required String body,
  }) async {
    try {
      final row = await _client
          .from('community_news')
          .insert(CommunityNewsItem.toInsertJson(
            communityId: communityId,
            authorId: _uid,
            title: title,
            body: body,
          ))
          .select()
          .single();
      return CommunityNewsItem.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<CommunityNewsItem> updateNews({
    required String newsId,
    required String title,
    required String body,
  }) async {
    try {
      final row = await _client
          .from('community_news')
          .update(CommunityNewsItem.toUpdateJson(title: title, body: body))
          .eq('id', newsId)
          .select()
          .single();
      return CommunityNewsItem.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> deleteNews(String newsId) async {
    try {
      await _client.from('community_news').delete().eq('id', newsId);
    } catch (e) {
      throw mapError(e);
    }
  }

  // ── Discussions ─────────────────────────────────────────────────────────

  @override
  Future<List<CommunityDiscussion>> fetchDiscussions(
    String communityId,
  ) async {
    try {
      final rows = await _client
          .from('community_discussions')
          .select('*, author:profiles!author_id(first_name, last_name)')
          .eq('community_id', communityId)
          .order('created_at', ascending: false);
      return rows.map(CommunityDiscussion.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<CommunityDiscussion> createDiscussion({
    required String communityId,
    required String title,
    required String body,
  }) async {
    try {
      final row = await _client
          .from('community_discussions')
          .insert(CommunityDiscussion.toInsertJson(
            communityId: communityId,
            authorId: _uid,
            title: title,
            body: body,
          ))
          .select()
          .single();
      return CommunityDiscussion.fromJson(row);
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
          .select('*, author:profiles!author_id(first_name, last_name)')
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
  }) async {
    try {
      final row = await _client
          .from('community_discussion_replies')
          .insert(DiscussionReply.toInsertJson(
            discussionId: discussionId,
            authorId: _uid,
            body: body,
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
