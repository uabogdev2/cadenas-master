import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/user_profile_service.dart';
import '../theme/app_theme.dart';

Future<bool> showDisplayNameDialog(
  BuildContext context, {
  bool isInitial = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: !isInitial,
    builder: (_) => _DisplayNameDialog(isInitial: isInitial),
  );
  return result ?? false;
}

class _DisplayNameDialog extends StatefulWidget {
  const _DisplayNameDialog({required this.isInitial});

  final bool isInitial;

  @override
  State<_DisplayNameDialog> createState() => _DisplayNameDialogState();
}

class _DisplayNameDialogState extends State<_DisplayNameDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final UserProfileService _profileService = UserProfileService();

  String? _errorText;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final initial = _profileService.current?.displayName ?? '';
    if (_profileService.isDisplayNameFormatValid(initial)) {
      _controller.text = initial;
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _controller.text.trim();
    if (!_profileService.isDisplayNameFormatValid(value)) {
      setState(() {
        _errorText = 'Utilise 3 à 10 lettres ou chiffres, sans espace.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final result = await _profileService.updateDisplayName(value);
    if (!result.success) {
      setState(() {
        _isSubmitting = false;
        _errorText = result.message ?? 'Impossible de valider ce nom.';
      });
      return;
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.badge_rounded,
              size: 48,
              color: AppTheme.secondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              widget.isInitial ? 'Choisis ton nom' : 'Modifier ton nom',
              style: AppTheme.heading2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '10 caractères max, lettres + chiffres seulement.\nExemple: Pegasus225',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLength: 10,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(10),
              ],
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Nom unique',
                counterText: '',
                errorText: _errorText,
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!widget.isInitial)
                  Expanded(
                    child: TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Plus tard'),
                    ),
                  ),
                if (!widget.isInitial) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Valider'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

