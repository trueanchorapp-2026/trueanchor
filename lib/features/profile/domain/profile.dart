import 'family_role.dart';
import 'user_role.dart';

/// A row of `public.profiles`, keyed by the auth user id.
class Profile {
  const Profile({
    required this.id,
    required this.churchId,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.familyId,
    this.familyRole,
    this.phone,
    this.avatarUrl,
    this.birthDate,
    this.grade,
    this.gender,
    this.baptized = false,
    this.baptizedOn,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        churchId: json['church_id'] as String,
        familyId: json['family_id'] as String?,
        role: UserRole.fromWire(json['role'] as String),
        familyRole: FamilyRole.tryFromWire(json['family_role']),
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        birthDate: _parseDate(json['birth_date']),
        grade: json['grade'] as int?,
        gender: json['gender'] as String?,
        baptized: json['baptized'] as bool? ?? false,
        baptizedOn: _parseDate(json['baptized_on']),
      );

  final String id;
  final String churchId;
  final String? familyId;
  final UserRole role;

  /// What the household calls this member. Null for church staff, who have no
  /// household, and only ever set by `set_family_member_role`.
  final FamilyRole? familyRole;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final DateTime? birthDate;
  final int? grade;
  final String? gender;
  final bool baptized;
  final DateTime? baptizedOn;

  String get fullName => [firstName, lastName]
      .where((part) => part.trim().isNotEmpty)
      .join(' ')
      .trim();

  String get initials {
    final first = firstName.trim();
    final last = lastName.trim();
    final buffer = StringBuffer();
    if (first.isNotEmpty) buffer.write(first[0]);
    if (last.isNotEmpty) buffer.write(last[0]);
    return buffer.isEmpty ? '?' : buffer.toString().toUpperCase();
  }

  /// Age is derived, never stored, so it cannot drift out of date.
  /// Returns null when no birth date has been set.
  int? ageOn(DateTime today) {
    final birth = birthDate;
    if (birth == null) return null;
    var age = today.year - birth.year;
    final hasHadBirthday =
        today.month > birth.month ||
        (today.month == birth.month && today.day >= birth.day);
    if (!hasHadBirthday) age--;
    return age < 0 ? null : age;
  }

  int? get age => ageOn(DateTime.now());

  bool get hasFamily => familyId != null;

  /// Whether the household treats this member as an adult. The family label
  /// wins when set; the permission role is the fallback for church staff and
  /// for anyone who signed up before family roles existed.
  bool get isHouseholdAdult => familyRole?.isAdult ?? role != UserRole.youth;

  /// How to describe this person inside their household. Falls back to the
  /// permission role for church staff, and for anyone who signed up before
  /// family roles existed.
  String get householdLabel => familyRole?.label ?? role.label;

  /// Only the fields a user is allowed to edit about themselves. Role,
  /// church_id and family_id are omitted deliberately — the database reverts
  /// them anyway (see `private.guard_profile_columns`), so sending them would
  /// be misleading.
  Map<String, dynamic> toUpdateJson() => {
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'birth_date': _formatDate(birthDate),
        'grade': grade,
        'gender': gender,
        'baptized': baptized,
        'baptized_on': _formatDate(baptizedOn),
      };

  Profile copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? familyId,
    DateTime? birthDate,
    int? grade,
    String? gender,
    bool? baptized,
    DateTime? baptizedOn,
    bool clearBirthDate = false,
    bool clearBaptizedOn = false,
    bool clearGrade = false,
  }) =>
      Profile(
        id: id,
        churchId: churchId,
        familyId: familyId ?? this.familyId,
        role: role,
        familyRole: familyRole,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        email: email,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl,
        birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
        grade: clearGrade ? null : (grade ?? this.grade),
        gender: gender ?? this.gender,
        baptized: baptized ?? this.baptized,
        baptizedOn: clearBaptizedOn ? null : (baptizedOn ?? this.baptizedOn),
      );
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value as String);
}

/// Postgres `date` columns want a bare yyyy-MM-dd, not a full ISO timestamp.
String? _formatDate(DateTime? value) {
  if (value == null) return null;
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
