import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/user_role.dart';

/// What the app promises about who can read a thread, in the words the person
/// reading it will actually recognise.
///
/// Every clause is a claim the schema has to make true, so change them
/// together: "only you and your youth pastor" is `threads_select_participant`
/// having no parent branch; "administrators can access" is
/// `admin_read_thread()`; "every access is recorded" is the
/// `message_access_log` row that function writes before it returns anything.
///
/// Shown on the inbox and inside every thread rather than once at signup. A
/// privacy promise nobody remembers reading is not informed consent.
const _adminClause =
    'TrueAnchor administrators can access these messages when required for '
    'safety or legal reasons, and every access is recorded.';

/// The disclosure is role-specific because the promise genuinely differs. A
/// single string cannot be honest to all three: "not your parents" is
/// meaningless to a parent, and a youth pastor reading "only you and your youth
/// pastor" is being told about themselves.
///
/// The parent wording carries an extra sentence the others do not need. A
/// parent may reasonably assume they can read whatever their youth writes, and
/// they cannot — that is the deliberate design decision behind
/// `threads_select_participant`, so it is stated here rather than discovered.
String messagingDisclosureFor(UserRole? role) => switch (role) {
      UserRole.youthPastor =>
        'Only you and the person you are writing to can read this conversation '
            '— not their parents, and not your church admin. $_adminClause',
      UserRole.parent =>
        'Only you and your youth pastor can read this conversation — not your '
            'church admin, and not the rest of your family. If your youth '
            'messages the youth pastor, that conversation is private to them. '
            '$_adminClause',
      // Youth, and the fallback while the profile is still loading: the
      // strongest promise, so a partly-loaded screen never over-claims.
      _ => 'Only you and your youth pastor can read this conversation — not '
          'your parents, and not your church admin. $_adminClause',
    };

class MessagingDisclosure extends ConsumerWidget {
  const MessagingDisclosure({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentProfileProvider).value?.role;
    return NoticeBanner(
      message: messagingDisclosureFor(role),
      icon: Icons.lock_outline,
    );
  }
}
