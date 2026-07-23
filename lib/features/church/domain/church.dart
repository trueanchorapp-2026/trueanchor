import 'dart:math';

import '../../profile/domain/user_role.dart';

/// A row of `public.churches`. RLS only ever returns the caller's own church.
class Church {
  const Church({
    required this.id,
    required this.name,
    this.city,
    this.state,
  });

  factory Church.fromJson(Map<String, dynamic> json) => Church(
        id: json['id'] as String,
        name: json['name'] as String,
        city: json['city'] as String?,
        state: json['state'] as String?,
      );

  final String id;
  final String name;
  final String? city;
  final String? state;

  /// "Coral Springs, FL", or just whichever half is set. Empty when neither is.
  String get location => [city, state]
      .where((part) => part != null && part.trim().isNotEmpty)
      .join(', ');
}

/// A row of `public.church_invites`. Holding one of these codes is what lets
/// somebody join this church — in the role the code names — so treat them as
/// credentials, not as labels.
class ChurchInvite {
  const ChurchInvite({
    required this.id,
    required this.churchId,
    required this.code,
    required this.role,
    required this.maxUses,
    required this.uses,
    this.expiresAt,
  });

  factory ChurchInvite.fromJson(Map<String, dynamic> json) => ChurchInvite(
        id: json['id'] as String,
        churchId: json['church_id'] as String,
        code: json['code'] as String,
        role: UserRole.fromWire(json['role'] as String),
        maxUses: json['max_uses'] as int? ?? 0,
        uses: json['uses'] as int? ?? 0,
        expiresAt: json['expires_at'] == null
            ? null
            : DateTime.tryParse(json['expires_at'] as String)?.toLocal(),
      );

  final String id;
  final String churchId;
  final String code;
  final UserRole role;
  final int maxUses;
  final int uses;
  final DateTime? expiresAt;

  int get remainingUses => (maxUses - uses).clamp(0, maxUses);

  bool get isExhausted => uses >= maxUses;

  bool isExpiredAt(DateTime now) {
    final expiry = expiresAt;
    return expiry != null && !expiry.isAfter(now);
  }

  /// Mirrors the `where` clause in `validate_invite_code`. If this ever
  /// disagrees with the SQL, staff will be told a code works when it does not.
  bool isUsableAt(DateTime now) => !isExhausted && !isExpiredAt(now);

  String statusLabelAt(DateTime now) {
    if (isExhausted) return 'Used up';
    if (isExpiredAt(now)) return 'Expired';
    return '$remainingUses left';
  }

  /// Characters a person can read aloud without ambiguity: no O/0, no I/1.
  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Generates a code for a new invite. Takes a [Random] so it can be seeded
  /// in tests.
  static String generateCode({int length = 8, Random? random}) {
    final rng = random ?? Random.secure();
    return List.generate(
      length,
      (_) => _codeAlphabet[rng.nextInt(_codeAlphabet.length)],
    ).join();
  }

  /// The database matches on `upper(trim(code))`, so normalise the same way
  /// before writing one — otherwise a code with a stray space is unusable.
  static String normalizeCode(String value) =>
      value.replaceAll(RegExp(r'\s+'), '').toUpperCase();

  Map<String, dynamic> toInsertJson() => {
        'church_id': churchId,
        'code': normalizeCode(code),
        'role': role.wire,
        'max_uses': maxUses,
        'expires_at': expiresAt?.toUtc().toIso8601String(),
      };
}
