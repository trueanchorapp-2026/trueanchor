import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../application/auth_providers.dart';
import '../domain/auth_repository.dart';

/// The church-code field shared by the sign-up and complete-signup screens.
///
/// Owns the debounced lookup so the code is validated once the user pauses,
/// not per keystroke, and reports the resolved [InvitePreview] (or null) to the
/// parent via [onPreviewChanged] so it can gate submission. Keeping this in one
/// place stops the two screens drifting on how a code is validated.
class InviteCodeField extends ConsumerStatefulWidget {
  const InviteCodeField({
    required this.controller,
    required this.onPreviewChanged,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<InvitePreview?> onPreviewChanged;
  final bool enabled;

  @override
  ConsumerState<InviteCodeField> createState() => _InviteCodeFieldState();
}

class _InviteCodeFieldState extends ConsumerState<InviteCodeField> {
  /// The code we have actually asked the server about. Kept separate from the
  /// controller text so we look it up once the user pauses, not per keystroke.
  String _checkedCode = '';
  Timer? _debounce;
  InvitePreview? _reported;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final normalised = value.trim().toUpperCase();
    if (normalised == _checkedCode) return;

    // Clear a stale confirmation immediately so it can't be mistaken for a
    // result for the code now in the box.
    if (_checkedCode.isNotEmpty) setState(() => _checkedCode = '');

    if (normalised.length < 4) return;
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _checkedCode = normalised);
    });
  }

  void _report(InvitePreview? preview) {
    if (identical(preview, _reported)) return;
    _reported = preview;
    // Defer so we never call setState on the parent during our own build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPreviewChanged(preview);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewState = _checkedCode.isEmpty
        ? const AsyncData<InvitePreview?>(null)
        : ref.watch(invitePreviewProvider(_checkedCode));
    final preview = previewState.value;
    _report(preview);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          onChanged: _onChanged,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [UpperCaseFormatter()],
          decoration: InputDecoration(
            labelText: 'Church code',
            prefixIcon: const Icon(Icons.vpn_key_outlined),
            suffixIcon: previewState.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(AppTheme.space3),
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : preview != null
                    ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                    : null,
          ),
          validator: (value) {
            if ((value?.trim().isEmpty ?? true)) {
              return 'Enter the code your church gave you.';
            }
            if (preview == null) {
              return 'That code is not valid. Check it with your church.';
            }
            return null;
          },
        ),
        if (preview != null) ...[
          const SizedBox(height: AppTheme.space3),
          InviteConfirmation(preview: preview),
        ],
      ],
    );
  }
}

/// Confirms the church and role a code resolves to, before the user commits.
class InviteConfirmation extends StatelessWidget {
  const InviteConfirmation({required this.preview, super.key});

  final InvitePreview preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppTheme.space3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.church_outlined,
              size: 20, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: AppTheme.space2),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                children: [
                  const TextSpan(text: 'Joining '),
                  TextSpan(
                    text: preview.churchName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' as '),
                  TextSpan(
                    text: preview.role.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Invite codes are stored upper-case; normalising as the user types keeps the
/// field, the lookup and the submitted value all in agreement.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
