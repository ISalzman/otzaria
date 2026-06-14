import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class ProgressiveScroll extends StatefulWidget {
  final Widget child;
  final ScrollOffsetController scrollController;
  final double maxSpeed;
  final double accelerationFactor;
  final double curve;
  final FocusNode? focusNode;
  final bool autofocus;
  // ScrollOffsetController לא חושף isAttached, ו-animateScroll זורק אם הרשימה
  // אינה מחוברת (נטענת/לא ב-tree). ItemScrollController (שמתחבר יחד עם
  // ScrollOffsetController לאותו ScrollablePositionedList) כן חושף isAttached.
  final ItemScrollController? itemScrollController;

  const ProgressiveScroll({
    super.key,
    required this.child,
    required this.scrollController,
    this.maxSpeed = 5000.0,
    this.accelerationFactor = 0.1,
    this.curve = 2.0,
    this.focusNode,
    this.autofocus = false,
    this.itemScrollController,
  });

  @override
  State<ProgressiveScroll> createState() => _ProgressiveScrollState();
}

class _ProgressiveScrollState extends State<ProgressiveScroll> {
  double _scrollSpeed = 0;
  bool _isKeyPressed = false;
  int _scrollDirection = 0; // 1 for down, -1 for up, 0 for no scroll
  double _timePressedInSeconds = 0;
  Timer? _scrollTickTimer;
  late final FocusNode _focusNode;
  bool _isLocalFocusNode = false;

  // גלילה אפשרית רק כשה-ScrollablePositionedList מחובר; אחרת animateScroll זורק.
  bool get _canScroll => widget.itemScrollController?.isAttached ?? false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _focusNode = FocusNode();
      _isLocalFocusNode = true;
    } else {
      _focusNode = widget.focusNode!;
    }
    // בקשת פוקוס מפורשת — Focus.autofocus לא יורה כשכבר יש primaryFocus
    // ב-scope (כמו ה-Focus של ה-Scaffold בכרטיסיית המפרשים).
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
    _startScrolling();
  }

  @override
  void dispose() {
    _scrollTickTimer?.cancel();
    if (_isLocalFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _startScrolling() {
    _scrollTickTimer?.cancel();
    _scrollTickTimer = Timer(const Duration(milliseconds: 16), () {
      if (_isKeyPressed) {
        _timePressedInSeconds += 0.016; // 16 milliseconds in seconds
        double t = _timePressedInSeconds;
        double curvedT = exp(widget.curve * t);
        _scrollSpeed = (curvedT * widget.accelerationFactor * _scrollDirection)
            .clamp(-widget.maxSpeed, widget.maxSpeed);
        //debugPrint('scroll speed: $_scrollSpeed');
      } else {
        _scrollSpeed = 0;
        _timePressedInSeconds = 0;
      }

      if (_scrollSpeed != 0 && _canScroll) {
        widget.scrollController.animateScroll(
          offset: _scrollSpeed,
          duration: const Duration(milliseconds: 16),
        );
      }

      if (mounted) {
        _startScrolling();
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final isArrowDown = event.logicalKey == LogicalKeyboardKey.arrowDown;
    final isArrowUp = event.logicalKey == LogicalKeyboardKey.arrowUp;
    if (!isArrowDown && !isArrowUp) return KeyEventResult.ignored;

    // Shift+חץ שמור לבחירת טקסט, ושאר הצירופים לקיצורים — לא מתערבים בהם.
    if (HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    if (event is KeyUpEvent) {
      _isKeyPressed = false;
      if (_canScroll) {
        widget.scrollController.animateScroll(
          offset: 100.0 * _scrollDirection,
          duration: const Duration(milliseconds: 150),
        );
      }
      _scrollDirection = 0;
    } else {
      _isKeyPressed = true;
      _scrollDirection = isArrowDown ? 1 : -1;
    }
    // בולעים את החץ כדי שלא יגלול גם Scrollable שמעל — כש"מפרשים מתחת"
    // מקונן בתוך גלילת גוף הטקסט הראשי, אחרת שניהם היו גוללים יחד.
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }
}
