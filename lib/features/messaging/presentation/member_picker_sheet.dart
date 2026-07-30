import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../profile/domain/profile.dart';
import '../../profile/domain/user_role.dart';
import '../application/messaging_providers.dart';

/// Asks a youth pastor who they want to write to. Resolves to null if they
/// back out.
///
/// Youth pastors only — the member side picks from a list of pastors instead,
/// and `open_thread()` refuses every other role outright.
Future<Profile?> showMemberPickerSheet(BuildContext context) {
  return showModalBottomSheet<Profile>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const MemberPickerSheet(),
  );
}

/// The church's parents and youth, searchable.
///
/// A church directory is long enough that a plain list is not a picker, so the
/// search field is the primary control rather than a refinement: a pastor
/// looking for one family should be able to type a name instead of scrolling
/// past every other one.
class MemberPickerSheet extends ConsumerStatefulWidget {
  const MemberPickerSheet({super.key});

  @override
  ConsumerState<MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends ConsumerState<MemberPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Matches on the whole name rather than the first word, so "rivera" finds
  /// someone the pastor only knows by their surname.
  List<Profile> _filter(List<Profile> people) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return people;
    return people
        .where((person) => person.fullName.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final membersState = ref.watch(messageableMembersProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          // Tall enough that the list is worth scrolling, short enough that the
          // sheet still reads as a sheet.
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.space5,
                  0,
                  AppTheme.space5,
                  AppTheme.space3,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Who would you like to message?',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppTheme.space2),
                    Text(
                      'Only the two of you will be able to read it.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    TextField(
                      controller: _search,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        labelText: 'Search by name',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AsyncValueView(
                  value: membersState,
                  onRetry: () => ref.invalidate(messageableMembersProvider),
                  builder: (people) {
                    if (people.isEmpty) {
                      return const EmptyState(
                        icon: Icons.groups_outlined,
                        title: 'Nobody to message yet',
                        message: 'Parents and youth appear here once they join '
                            'your church.',
                      );
                    }

                    final matches = _filter(people);
                    if (matches.isEmpty) {
                      return const EmptyState(
                        icon: Icons.search_off,
                        title: 'No one by that name',
                        message: 'Try a different spelling, or clear the '
                            'search.',
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: AppTheme.space5),
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final person = matches[index];
                        return ListTile(
                          leading: CircleAvatar(child: Text(person.initials)),
                          title: Text(person.fullName),
                          // Parent or Youth. A pastor writing to a household
                          // needs to know which of the two they picked, and
                          // names alone do not say.
                          subtitle: Text(_subtitleFor(person)),
                          onTap: () => Navigator.of(context).pop(person),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A youth's grade is the fastest way to tell two same-named youth apart, and
/// it is what a pastor already thinks in.
String _subtitleFor(Profile person) {
  final grade = person.grade;
  if (person.role == UserRole.youth && grade != null) {
    return 'Youth · Grade $grade';
  }
  return person.role.label;
}
