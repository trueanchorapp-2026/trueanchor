import 'message.dart';
import 'message_thread.dart';

/// A youth pastor the member may write to. Just enough to draw a picker —
/// `church_youth_pastors()` deliberately returns nothing more, because members
/// are not allowed to read staff profiles.
class PastorOption {
  const PastorOption({required this.id, required this.name});

  factory PastorOption.fromJson(Map<String, dynamic> json) => PastorOption(
        id: json['id'] as String,
        name: [
          json['first_name'] as String? ?? '',
          json['last_name'] as String? ?? '',
        ].where((part) => part.trim().isNotEmpty).join(' ').trim(),
      );

  final String id;
  final String name;

  String get displayName => name.isEmpty ? 'Youth pastor' : name;
}

abstract interface class MessagingRepository {
  /// Every thread the caller participates in, most recent first. Which rows
  /// come back is `threads_select_participant`'s decision, not this method's.
  Future<List<MessageThread>> fetchThreads();

  Future<List<Message>> fetchMessages(String threadId);

  Future<Message> send({required String threadId, required String body});

  /// Withdraws a message. Only succeeds inside the five-minute window and only
  /// for your own — `messages_delete_own_recent` is what enforces both.
  Future<void> deleteMessage(String id);

  /// Opens the conversation, or returns the one that already exists.
  ///
  /// Always an RPC: there is no insert policy on `message_threads`, because a
  /// member cannot see a youth pastor's profile to reference. [withId] null
  /// means "my youth pastor"; a pastor must always name the member.
  Future<MessageThread> openThread({String? withId});

  /// Stamps the caller's own read receipt. A no-op for a non-participant.
  Future<void> markRead(MessageThread thread);

  /// The youth pastors in the caller's church, for the picker.
  Future<List<PastorOption>> fetchYouthPastors();
}
