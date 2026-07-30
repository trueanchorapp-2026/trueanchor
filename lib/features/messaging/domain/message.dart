/// How long after sending a message may still be withdrawn.
///
/// Mirrors the `interval '5 minutes'` in `messages_delete_own_recent`. The
/// database is the real gate; this constant only decides whether the app
/// offers the option, so the two must agree or the UI will show a delete that
/// fails.
const messageDeleteWindow = Duration(minutes: 5);

/// A row of `public.messages`.
class Message {
  const Message({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        threadId: json['thread_id'] as String,
        senderId: json['sender_id'] as String,
        body: json['body'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
      );

  final String id;
  final String threadId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  bool isSentBy(String? userId) => userId != null && senderId == userId;

  /// Whether the app should offer to withdraw this message. Mirrors
  /// `messages_delete_own_recent`: your own, and inside the window.
  bool canDeleteAt(DateTime now, {String? userId}) =>
      isSentBy(userId) && now.difference(createdAt) < messageDeleteWindow;

  /// thread_id and sender_id are the whole payload: church_id is not on this
  /// table at all — the thread carries the tenancy — and created_at is the
  /// database's to set, since the delete window is measured against it.
  static Map<String, dynamic> toInsertJson({
    required String threadId,
    required String senderId,
    required String body,
  }) =>
      {
        'thread_id': threadId,
        'sender_id': senderId,
        'body': body.trim(),
      };
}
