import 'package:flutter/foundation.dart';

/// What a vote is cast on; [wireValue] is `cast_vote`'s `p_kind`.
enum VoteTarget {
  discussion('discussion'),
  news('news'),
  resource('resource');

  const VoteTarget(this.wireValue);

  final String wireValue;
}

/// Up/down counts on a post plus the current user's own vote
/// (1 = up, -1 = down, 0 = none).
@immutable
class VoteTally {
  const VoteTally({this.upvotes = 0, this.downvotes = 0, this.myVote = 0})
      : assert(myVote >= -1 && myVote <= 1);

  /// Reads `upvotes`, `downvotes` and either a flat `my_vote` (RPCs) or an
  /// embedded `my_votes: [{value: 1}]` (PostgREST, RLS limits it to own row).
  factory VoteTally.fromJson(Map<String, dynamic> json) {
    var mine = json['my_vote'];
    final embedded = json['my_votes'];
    if (mine == null && embedded is List && embedded.isNotEmpty) {
      final first = embedded.first;
      if (first is Map) mine = first['value'];
    }
    return VoteTally(
      upvotes: (json['upvotes'] as num?)?.toInt() ?? 0,
      downvotes: (json['downvotes'] as num?)?.toInt() ?? 0,
      myVote: ((mine as num?)?.toInt() ?? 0).clamp(-1, 1),
    );
  }

  final int upvotes;
  final int downvotes;
  final int myVote;

  int get score => upvotes - downvotes;

  /// The tally after the user taps up (`1`) or down (`-1`): tapping the vote
  /// they already cast clears it, tapping the other one switches. The new
  /// [myVote] is what to send to the server.
  VoteTally tap(int direction) {
    assert(direction == 1 || direction == -1);
    final next = direction == myVote ? 0 : direction;
    var up = upvotes;
    var down = downvotes;
    if (myVote == 1) up--;
    if (myVote == -1) down--;
    if (next == 1) up++;
    if (next == -1) down++;
    return VoteTally(
      upvotes: up < 0 ? 0 : up,
      downvotes: down < 0 ? 0 : down,
      myVote: next,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VoteTally &&
      other.upvotes == upvotes &&
      other.downvotes == downvotes &&
      other.myVote == myVote;

  @override
  int get hashCode => Object.hash(upvotes, downvotes, myVote);

  @override
  String toString() => 'VoteTally(+$upvotes -$downvotes mine=$myVote)';
}
