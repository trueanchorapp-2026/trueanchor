import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trueanchor/core/error/app_exception.dart';

void main() {
  group('database sentinels', () {
    // The SQL functions raise bare sentinel codes; all the wording lives in
    // Dart. These tests pin that contract in both directions.
    test('INVALID_INVITE_CODE becomes plain language', () {
      final mapped = mapError(const PostgrestException(
        message: 'INVALID_INVITE_CODE',
        code: 'P0001',
      ));
      expect(mapped.message, contains('church code'));
      expect(mapped.message, isNot(contains('INVALID_INVITE_CODE')));
    });

    test('is found even when wrapped by the generic signup failure', () {
      // The signup trigger's exception reaches the client buried inside an
      // AuthException, so the match has to be a substring match.
      final mapped = mapError(const AuthException(
        'Database error saving new user: INVALID_INVITE_CODE',
      ));
      expect(mapped.message, contains('church code'));
    });

    test('INVALID_FAMILY_CODE becomes plain language', () {
      final mapped =
          mapError(const PostgrestException(message: 'INVALID_FAMILY_CODE'));
      expect(mapped.message, contains('family code'));
    });

    test('ALREADY_IN_A_FAMILY becomes plain language', () {
      final mapped =
          mapError(const PostgrestException(message: 'ALREADY_IN_A_FAMILY'));
      expect(mapped.message, startsWith('You already belong to a family.'));
      // join_family now raises this too, and moving households is a church
      // admin action — so the message has to say where to go next.
      expect(mapped.message, contains('church'));
    });

    test('household role sentinels become plain language', () {
      // Raised by set_family_member_role. Each has to read as an explanation
      // rather than as a bug, because the UI only shows the mapped text.
      for (final sentinel in const [
        'ONLY_HEAD_CAN_ASSIGN_ROLES',
        'NOT_A_FAMILY_MEMBER',
        'CANNOT_CHANGE_STAFF_ROLE',
        'HEAD_MUST_BE_AN_ADULT',
      ]) {
        final mapped = mapError(PostgrestException(message: sentinel));
        expect(mapped.message, isNot(contains(sentinel)),
            reason: '$sentinel leaked its raw code to the user');
        expect(mapped.message, isNot('Something went wrong. Please try again.'),
            reason: '$sentinel fell through to the generic message');
      }
    });

    test('ONLY_PARENTS_CAN_CREATE_FAMILIES becomes plain language', () {
      final mapped = mapError(
        const PostgrestException(message: 'ONLY_PARENTS_CAN_CREATE_FAMILIES'),
      );
      expect(mapped.message, contains('Only a parent'));
    });

    test('is matched when it arrives in details rather than message', () {
      final mapped = mapError(const PostgrestException(
        message: 'unexpected_failure',
        details: 'ALREADY_IN_A_FAMILY',
      ));
      expect(mapped.message, startsWith('You already belong to a family.'));
    });
  });

  group('auth errors', () {
    test('bad credentials', () {
      expect(
        mapError(const AuthException('Invalid login credentials')).message,
        'That email or password is incorrect.',
      );
    });

    test('duplicate email', () {
      expect(
        mapError(const AuthException('User already registered')).message,
        contains('already exists'),
      );
    });

    test('short password', () {
      expect(
        mapError(const AuthException(
          'Password should be at least 6 characters',
        )).message,
        'Password must be at least 6 characters.',
      );
    });

    test('unconfirmed email', () {
      expect(
        mapError(const AuthException('Email not confirmed')).message,
        contains('confirm your email'),
      );
    });

    test('a bare trigger abort still gets actionable advice', () {
      expect(
        mapError(const AuthException('Database error saving new user')).message,
        contains('church code'),
      );
    });

    test('an unrecognised auth message is passed through as-is', () {
      expect(
        mapError(const AuthException('Rate limit exceeded')).message,
        'Rate limit exceeded',
      );
    });
  });

  group('postgrest errors', () {
    test('42501 is reported as a permission problem, not a crash', () {
      // This is what an RLS refusal looks like on the wire. Users see it when
      // they try to read or write something outside their church or family.
      expect(
        mapError(const PostgrestException(
          message: 'new row violates row-level security policy',
          code: '42501',
        )).message,
        "You don't have permission to do that.",
      );
    });

    test('other postgrest errors keep their message', () {
      expect(
        mapError(const PostgrestException(
          message: 'duplicate key value violates unique constraint',
          code: '23505',
        )).message,
        contains('duplicate key'),
      );
    });
  });

  test('an AppException passes through untouched', () {
    const original = AppException('Already friendly.');
    expect(identical(mapError(original), original), isTrue);
  });

  test('an unknown error never leaks its raw text to the user', () {
    // Stack traces and internal type names are not something to put in front
    // of a parent or a teenager.
    final mapped = mapError(StateError('Bad state: _internal_thing == null'));
    expect(mapped.message, 'Something went wrong. Please try again.');
    expect(mapped.message, isNot(contains('_internal_thing')));
  });

  test('AppException.toString is the message, so it is safe to interpolate',
      () {
    expect('${const AppException('Nope.')}', 'Nope.');
  });
}
