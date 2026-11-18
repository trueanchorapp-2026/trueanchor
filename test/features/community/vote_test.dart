import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/community/domain/vote.dart';

void main() {
  group('VoteTally.tap', () {
    test('no vote → up adds an upvote', () {
      expect(
        const VoteTally(upvotes: 2, downvotes: 1).tap(1),
        const VoteTally(upvotes: 3, downvotes: 1, myVote: 1),
      );
    });

    test('tapping the same vote again undoes it', () {
      expect(
        const VoteTally(upvotes: 3, downvotes: 1, myVote: 1).tap(1),
        const VoteTally(upvotes: 2, downvotes: 1),
      );
      expect(
        const VoteTally(upvotes: 0, downvotes: 1, myVote: -1).tap(-1),
        const VoteTally(),
      );
    });

    test('switching from up to down moves the vote', () {
      expect(
        const VoteTally(upvotes: 3, downvotes: 1, myVote: 1).tap(-1),
        const VoteTally(upvotes: 2, downvotes: 2, myVote: -1),
      );
    });

    test('counts never go negative on stale data', () {
      expect(
        const VoteTally(myVote: 1).tap(1),
        const VoteTally(),
      );
    });

    test('score is ups minus downs', () {
      expect(const VoteTally(upvotes: 5, downvotes: 2).score, 3);
    });
  });

  group('VoteTally.fromJson', () {
    test('reads a flat my_vote from an RPC row', () {
      expect(
        VoteTally.fromJson({'upvotes': 4, 'downvotes': 1, 'my_vote': -1}),
        const VoteTally(upvotes: 4, downvotes: 1, myVote: -1),
      );
    });

    test('reads an embedded my_votes row', () {
      expect(
        VoteTally.fromJson({
          'upvotes': 1,
          'downvotes': 0,
          'my_votes': [
            {'value': 1},
          ],
        }),
        const VoteTally(upvotes: 1, myVote: 1),
      );
    });

    test('missing fields mean zero and no vote', () {
      expect(VoteTally.fromJson({'my_votes': []}), const VoteTally());
    });
  });
}
