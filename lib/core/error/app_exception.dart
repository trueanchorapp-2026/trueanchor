import 'package:supabase_flutter/supabase_flutter.dart';

/// A failure that already carries text safe to show a user.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Translates Supabase/Postgres errors into plain language.
///
/// The database raises bare sentinel codes (`INVALID_INVITE_CODE`, …) so the
/// wording lives here in one place rather than being duplicated across SQL.
/// Sentinels raised inside the signup trigger surface wrapped in a generic
/// "Database error saving new user" AuthException, so we substring-match the
/// whole message rather than comparing it exactly.
AppException mapError(Object error) {
  if (error is AppException) return error;

  final raw = switch (error) {
    final AuthException e => e.message,
    final PostgrestException e => '${e.message} ${e.details ?? ''}',
    _ => error.toString(),
  };

  for (final entry in _sentinels.entries) {
    if (raw.contains(entry.key)) return AppException(entry.value);
  }

  if (error is AuthException) return AppException(_mapAuth(error, raw));
  if (error is PostgrestException) {
    // 42501 = insufficient_privilege, i.e. an RLS policy refused the row.
    if (error.code == '42501') {
      return const AppException(
        "You don't have permission to do that.",
      );
    }
    return AppException(error.message);
  }

  return const AppException('Something went wrong. Please try again.');
}

const _sentinels = <String, String>{
  'INVALID_INVITE_CODE':
      'That church code is not valid. Check with your church for a current code.',
  'INVALID_FAMILY_CODE':
      'That family code is not valid. Ask the head of your household to re-send it.',
  'ALREADY_IN_A_FAMILY':
      'You already belong to a family. Ask your church to move you if that is wrong.',
  'ONLY_PARENTS_CAN_CREATE_FAMILIES':
      'Only a parent can create a family. Ask a parent to set yours up.',
  'ONLY_HEAD_CAN_ASSIGN_ROLES':
      'Only the head of your household can change roles.',
  'NOT_A_FAMILY_MEMBER': 'That person is not in your household.',
  'CANNOT_CHANGE_STAFF_ROLE':
      'That account belongs to the church, so its role is set by a church admin.',
  'NO_YOUTH_PASTOR':
      'Your church has not set up a youth pastor yet, so there is nobody to '
          'message. Ask your church to add one.',
  'INVALID_THREAD_PARTICIPANT':
      'That person is not someone you can message.',
  'ROLE_CANNOT_MESSAGE':
      'Messaging is between families and their youth pastor, so this account '
          'cannot open a conversation.',
  'NOT_AUTHORIZED': 'You do not have access to that.',
  'HEAD_MUST_BE_AN_ADULT':
      'The head of household cannot be set to youth. Ask your church to move '
          'the household to someone else first.',
};

String _mapAuth(AuthException error, String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('invalid login credentials')) {
    return 'That email or password is incorrect.';
  }
  if (lower.contains('already registered') ||
      lower.contains('already been registered')) {
    return 'An account already exists for that email. Try signing in.';
  }
  if (lower.contains('password should be at least')) {
    return 'Password must be at least 6 characters.';
  }
  if (lower.contains('email not confirmed')) {
    return 'Please confirm your email address before signing in.';
  }
  // The signup trigger aborting shows up here with no usable detail.
  if (lower.contains('database error saving new user')) {
    return 'We could not finish creating your account. '
        'Double-check your church code and try again.';
  }
  return error.message;
}
