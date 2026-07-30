import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../domain/message.dart';
import '../domain/message_thread.dart';
import '../domain/messaging_repository.dart';

class SupabaseMessagingRepository implements MessagingRepository {
  const SupabaseMessagingRepository(this._client);

  final SupabaseClient _client;

  // Both participants' names, so the inbox can label a thread from either
  // side. The !member_id / !pastor_id hints disambiguate two foreign keys into
  // the same table.
  static const _threadColumns = '*, '
      'member:profiles!member_id(first_name, last_name), '
      'pastor:profiles!pastor_id(first_name, last_name)';

  @override
  Future<List<MessageThread>> fetchThreads() async {
    try {
      final rows = await _client
          .from('message_threads')
          .select(_threadColumns)
          .order('last_message_at', ascending: false);
      return rows.map(MessageThread.fromJson).toList();
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<List<Message>> fetchMessages(String threadId) async {
    try {
      final rows = await _client
          .from('messages')
          .select()
          .eq('thread_id', threadId)
          .order('created_at');
      return rows.map(Message.fromJson).toList();
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<Message> send({
    required String threadId,
    required String body,
  }) async {
    try {
      final senderId = _client.auth.currentUser?.id;
      if (senderId == null) {
        throw const AppException('You are signed out. Sign in to send.');
      }
      final row = await _client
          .from('messages')
          .insert(
            Message.toInsertJson(
              threadId: threadId,
              senderId: senderId,
              body: body,
            ),
          )
          .select()
          .single();
      return Message.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<void> deleteMessage(String id) async {
    try {
      // A delete outside the window matches no row rather than raising, so
      // PostgREST reports success either way. The caller re-reads the thread;
      // a message that is still there is the answer.
      await _client.from('messages').delete().eq('id', id);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<MessageThread> openThread({String? withId}) async {
    try {
      // open_thread returns the composite type public.message_threads, which
      // PostgREST hands back as a single object rather than an array.
      final row = await _client
          .rpc('open_thread', params: {'p_with_id': withId})
          .single();
      return MessageThread.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<void> markRead(MessageThread thread) async {
    final userId = _client.auth.currentUser?.id;
    final column = thread.readColumnFor(userId);
    if (column == null) return;
    try {
      // guard_thread_columns() reverts an attempt to write the other party's
      // receipt, so naming the wrong column would silently do nothing --
      // readColumnFor is what keeps that from happening quietly.
      await _client
          .from('message_threads')
          .update({column: DateTime.now().toUtc().toIso8601String()})
          .eq('id', thread.id);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<List<PastorOption>> fetchYouthPastors() async {
    try {
      final rows = await _client.rpc('church_youth_pastors') as List<dynamic>;
      return rows
          .cast<Map<String, dynamic>>()
          .map(PastorOption.fromJson)
          .toList();
    } catch (error) {
      throw mapError(error);
    }
  }
}
