import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/settings/settings_repository.dart';
import 'package:otzaria/settings/settings_bloc.dart';
import 'package:otzaria/settings/settings_state.dart';
import 'package:otzaria/settings/password_verification_dialog.dart';

/// Wrapper שבודק סיסמה לפני כניסה למסך מוגן
class ProtectedSettingsWrapper extends StatefulWidget {
  final Widget child;

  const ProtectedSettingsWrapper({
    super.key,
    required this.child,
  });

  @override
  State<ProtectedSettingsWrapper> createState() =>
      _ProtectedSettingsWrapperState();
}

class _ProtectedSettingsWrapperState extends State<ProtectedSettingsWrapper> {
  bool _isVerified = false;
  bool _isChecking = true;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    // נשתמש ב-postFrameCallback כדי לוודא שה-context מוכן
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkProtection();
      }
    });
  }

  void _checkProtection() {
    // נבדוק אם מצב מוגן מופעל
    final state = context.read<SettingsBloc>().state;
    final repository = context.read<SettingsRepository>();

    if (!state.protectedModeEnabled || !repository.hasProtectedModePassword()) {
      // אין הגנה - נאפשר גישה ישירה
      if (mounted) {
        setState(() {
          _isVerified = true;
          _isChecking = false;
        });
      }
    } else {
      // יש הגנה - נדרוש אימות
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
        if (!_dialogShown) {
          _dialogShown = true;
          _showPasswordDialog();
        }
      }
    }
  }

  Future<void> _showPasswordDialog() async {
    final repository = context.read<SettingsRepository>();

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: PasswordVerificationDialog(
          title: 'הזן סיסמה',
          hint: 'הנך במצב מוגן.\nהזן את הסיסמה כדי לגשת להגדרות',
          onVerify: (password) async {
            return repository.verifyProtectedModePassword(password);
          },
        ),
      ),
    );

    if (verified == true) {
      if (mounted) {
        setState(() {
          _isVerified = true;
        });
      }
    } else {
      // המשתמש ביטל - נחזור למסך הקודם
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SettingsBloc, SettingsState>(
      listenWhen: (previous, current) =>
          previous.protectedModeEnabled != current.protectedModeEnabled,
      listener: (context, state) {
        // אם המצב המוגן הופעל והמשתמש עדיין לא אומת
        if (state.protectedModeEnabled && !_isVerified) {
          final repository = context.read<SettingsRepository>();
          if (repository.hasProtectedModePassword()) {
            // נאפס את הסטטוס ונבקש אימות מחדש
            setState(() {
              _isVerified = false;
              _isChecking = false;
              _dialogShown = false;
            });
            // נציג את הדיאלוג
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_dialogShown) {
                _dialogShown = true;
                _showPasswordDialog();
              }
            });
          }
        }
      },
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isVerified) {
      return const Scaffold(
        body: Center(
          child: Text(
            'ממתין לאימות...',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }

    return widget.child;
  }
}

/// פונקציה עוזרת לבדיקה האם צריך הגנה
bool shouldProtectSettings(BuildContext context) {
  final state = context.read<SettingsBloc>().state;
  final repository = context.read<SettingsRepository>();
  return state.protectedModeEnabled && repository.hasProtectedModePassword();
}

/// פונקציה עוזרת לאימות סיסמה
Future<bool> verifyPasswordForAction(BuildContext context) async {
  if (!shouldProtectSettings(context)) {
    return true; // אין הגנה - מאושר
  }

  final repository = context.read<SettingsRepository>();

  final verified = await showDialog<bool>(
    context: context,
    builder: (context) => PasswordVerificationDialog(
      title: 'אמת סיסמה',
      hint: 'הנך במצב מוגן.\nהזן את הסיסמה כדי לבצע פעולה זו',
      onVerify: (password) async {
        return repository.verifyProtectedModePassword(password);
      },
    ),
  );

  return verified == true;
}
