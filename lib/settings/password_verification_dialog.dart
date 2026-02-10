import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/widgets/rtl_text_field.dart';
import 'package:otzaria/core/scaffold_messenger.dart';

/// דיאלוג לאימות סיסמה למצב מוגן
class PasswordVerificationDialog extends StatefulWidget {
  final Future<bool> Function(String password) onVerify;
  final String title;
  final String? hint;

  const PasswordVerificationDialog({
    super.key,
    required this.onVerify,
    this.title = 'הזן סיסמה',
    this.hint,
  });

  @override
  State<PasswordVerificationDialog> createState() =>
      _PasswordVerificationDialogState();
}

class _PasswordVerificationDialogState
    extends State<PasswordVerificationDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isObscured = true;
  bool _isVerifying = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    if (_passwordController.text.isEmpty) {
      UiSnack.showError('נא להזין סיסמה');
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      final isValid = await widget.onVerify(_passwordController.text);

      if (!mounted) return;

      if (isValid) {
        Navigator.of(context).pop(true);
      } else {
        UiSnack.showError('סיסמה שגויה');
        _passwordController.clear();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            widget.title,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 8),
          const Icon(FluentIcons.lock_closed_24_regular),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.hint != null) ...[
              Text(
                widget.hint!,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
            ],
            RtlTextField(
              controller: _passwordController,
              obscureText: _isObscured,
              autofocus: true,
              enabled: !_isVerifying,
              decoration: InputDecoration(
                labelText: 'סיסמה',
                hintText: 'הזן את הסיסמה',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(FluentIcons.key_24_regular),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isObscured
                        ? FluentIcons.eye_24_regular
                        : FluentIcons.eye_off_24_regular,
                  ),
                  onPressed: () {
                    setState(() {
                      _isObscured = !_isObscured;
                    });
                  },
                ),
              ),
              onSubmitted: (_) => _handleVerify(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isVerifying ? null : () => Navigator.of(context).pop(false),
          child: const Text('ביטול'),
        ),
        FilledButton(
          onPressed: _isVerifying ? null : _handleVerify,
          child: _isVerifying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('אישור'),
        ),
      ],
    );
  }
}

/// דיאלוג להגדרת סיסמה חדשה
class SetPasswordDialog extends StatefulWidget {
  final Future<void> Function(String password) onSetPassword;

  const SetPasswordDialog({
    super.key,
    required this.onSetPassword,
  });

  @override
  State<SetPasswordDialog> createState() => _SetPasswordDialogState();
}

class _SetPasswordDialogState extends State<SetPasswordDialog> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _isObscured1 = true;
  bool _isObscured2 = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_passwordController.text.isEmpty) {
      UiSnack.showError('נא להזין סיסמה');
      return;
    }

    if (_passwordController.text.length < 4) {
      UiSnack.showError('הסיסמה חייבת להכיל לפחות 4 תווים');
      return;
    }

    if (_passwordController.text != _confirmController.text) {
      UiSnack.showError('הסיסמאות אינן תואמות');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSetPassword(_passwordController.text);

      if (!mounted) return;

      UiSnack.show('הסיסמה נשמרה בהצלחה');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      UiSnack.showError('שגיאה בשמירת הסיסמה: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'הגדרת סיסמה',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 20),
          ),
          SizedBox(width: 8),
          Icon(FluentIcons.lock_closed_24_regular),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'הגדר סיסמה להגנה על ההגדרות',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            RtlTextField(
              controller: _passwordController,
              obscureText: _isObscured1,
              autofocus: true,
              enabled: !_isSaving,
              decoration: InputDecoration(
                labelText: 'סיסמה חדשה',
                hintText: 'לפחות 4 תווים',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(FluentIcons.key_24_regular),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isObscured1
                        ? FluentIcons.eye_24_regular
                        : FluentIcons.eye_off_24_regular,
                  ),
                  onPressed: () {
                    setState(() {
                      _isObscured1 = !_isObscured1;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            RtlTextField(
              controller: _confirmController,
              obscureText: _isObscured2,
              enabled: !_isSaving,
              decoration: InputDecoration(
                labelText: 'אימות סיסמה',
                hintText: 'הזן שוב את הסיסמה',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(FluentIcons.checkmark_lock_24_regular),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isObscured2
                        ? FluentIcons.eye_24_regular
                        : FluentIcons.eye_off_24_regular,
                  ),
                  onPressed: () {
                    setState(() {
                      _isObscured2 = !_isObscured2;
                    });
                  },
                ),
              ),
              onSubmitted: (_) => _handleSave(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('ביטול'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('שמור'),
        ),
      ],
    );
  }
}
