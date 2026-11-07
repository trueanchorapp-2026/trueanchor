import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../application/community_providers.dart';
import '../domain/discussion_query.dart';
import '../domain/topic_tag.dart';

/// Search box, tag chips and (optionally) a sort menu above a filterable list.
/// Stateless about the filter itself: the caller owns it and passes callbacks.
class TagFilterBar extends ConsumerStatefulWidget {
  const TagFilterBar({
    required this.selectedTagIds,
    required this.initialText,
    required this.onToggleTag,
    required this.onTextChanged,
    required this.onClear,
    this.isFiltered = false,
    this.searchHint = 'Search',
    this.sort,
    this.onSortChanged,
    super.key,
  });

  final Set<String> selectedTagIds;
  final String initialText;
  final ValueChanged<String> onToggleTag;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onClear;
  final bool isFiltered;
  final String searchHint;

  /// When null, no sort menu is shown.
  final DiscussionSort? sort;
  final ValueChanged<DiscussionSort>? onSortChanged;

  @override
  ConsumerState<TagFilterBar> createState() => _TagFilterBarState();
}

class _TagFilterBarState extends ConsumerState<TagFilterBar> {
  static const _debounce = Duration(milliseconds: 300);

  late final _controller = TextEditingController(text: widget.initialText);
  final _chipScroll = ScrollController();
  Timer? _timer;
  bool _expanded = false;

  Widget _chip(TopicTag tag) => FilterChip(
        label: Text(tag.label),
        selected: widget.selectedTagIds.contains(tag.id),
        onSelected: (_) => widget.onToggleTag(tag.id),
      );

  @override
  void didUpdateWidget(TagFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow the filter's text only when it changes from outside this box
    // (our own debounced edits already match the controller).
    if (widget.initialText != oldWidget.initialText &&
        widget.initialText != _controller.text) {
      _timer?.cancel();
      _controller.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _chipScroll.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(_debounce, () => widget.onTextChanged(value));
    setState(() {}); // toggles the clear-text icon
  }

  void _clearAll() {
    _timer?.cancel();
    _controller.clear();
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(topicTagsProvider).value ?? const <TopicTag>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _timer?.cancel();
                            _controller.clear();
                            widget.onTextChanged('');
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
            if (widget.sort != null) ...[
              const SizedBox(width: AppTheme.space2),
              _SortMenu(sort: widget.sort!, onChanged: widget.onSortChanged),
            ],
          ],
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: AppTheme.space2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _expanded
                    ? Wrap(
                        spacing: AppTheme.space2,
                        runSpacing: AppTheme.space2,
                        children: [for (final tag in tags) _chip(tag)],
                      )
                    : _CollapsedChipRow(
                        controller: _chipScroll,
                        // Selected tags first, so active filters stay
                        // visible without scrolling.
                        children: [
                          for (final tag in tags)
                            if (widget.selectedTagIds.contains(tag.id))
                              _chip(tag),
                          for (final tag in tags)
                            if (!widget.selectedTagIds.contains(tag.id))
                              _chip(tag),
                        ],
                      ),
              ),
              IconButton(
                tooltip: _expanded ? 'Show fewer topics' : 'Show all topics',
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ],
          ),
        ],
        if (widget.isFiltered)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Clear filters'),
            ),
          ),
      ],
    );
  }
}

/// One scrollable line of chips. Mouse and trackpad can drag it (Flutter web
/// only drags with touch by default), and a scrollbar shows there is more.
class _CollapsedChipRow extends StatelessWidget {
  const _CollapsedChipRow({required this.controller, required this.children});

  final ScrollController controller;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: PointerDeviceKind.values.toSet(),
      ),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: AppTheme.space3),
          child: Row(
            children: [
              for (final chip in children)
                Padding(
                  padding: const EdgeInsets.only(right: AppTheme.space2),
                  child: chip,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.sort, this.onChanged});

  final DiscussionSort sort;
  final ValueChanged<DiscussionSort>? onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DiscussionSort>(
      tooltip: 'Sort',
      initialValue: sort,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final option in DiscussionSort.values)
          CheckedPopupMenuItem(
            value: option,
            checked: option == sort,
            child: Text(option.label),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space2,
          vertical: AppTheme.space2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 20),
            const SizedBox(width: AppTheme.space1),
            Text(sort.label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

/// Compact tag labels on a card. Tapping one (when [onTap] is given) adds
/// that tag to the list's filter.
class TagChipRow extends ConsumerWidget {
  const TagChipRow({required this.tagIds, this.onTap, super.key});

  final List<String> tagIds;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byId = ref.watch(topicTagsByIdProvider);
    final tags = [
      for (final id in tagIds)
        if (byId[id] != null) byId[id]!,
    ];
    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppTheme.space2,
      runSpacing: AppTheme.space1,
      children: [
        for (final tag in tags)
          ActionChip(
            label: Text(tag.label),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelStyle: Theme.of(context).textTheme.labelSmall,
            onPressed: onTap == null ? null : () => onTap!(tag.id),
          ),
      ],
    );
  }
}

/// Lets an author choose up to [TopicTag.maxPerPost] tags.
class TagPicker extends ConsumerWidget {
  const TagPicker({
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tagsState = ref.watch(topicTagsProvider);
    final atLimit = selected.length >= TopicTag.maxPerPost;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Topics (up to ${TopicTag.maxPerPost})',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: AppTheme.space2),
        tagsState.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Text(
            'Topics could not be loaded.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
          data: (tags) => Wrap(
            spacing: AppTheme.space2,
            runSpacing: AppTheme.space1,
            children: [
              for (final tag in tags)
                FilterChip(
                  label: Text(tag.label),
                  selected: selected.contains(tag.id),
                  onSelected: !enabled ||
                          (atLimit && !selected.contains(tag.id))
                      ? null
                      : (on) => onChanged(
                            on
                                ? {...selected, tag.id}
                                : ({...selected}..remove(tag.id)),
                          ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet for changing an existing post's tags. Resolves to the new
/// selection, or null if dismissed.
Future<Set<String>?> showTagPickerSheet(
  BuildContext context, {
  required Set<String> initial,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _TagPickerSheet(initial: initial),
  );
}

class _TagPickerSheet extends StatefulWidget {
  const _TagPickerSheet({required this.initial});

  final Set<String> initial;

  @override
  State<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<_TagPickerSheet> {
  late var _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.space5,
          0,
          AppTheme.space5,
          AppTheme.space5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit topics', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppTheme.space4),
            TagPicker(
              selected: _selected,
              onChanged: (value) => setState(() => _selected = value),
            ),
            const SizedBox(height: AppTheme.space5),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_selected),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
