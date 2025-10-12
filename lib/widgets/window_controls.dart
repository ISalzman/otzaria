import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowControls extends StatefulWidget {
  const WindowControls({super.key});

  @override
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> {
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _checkFullscreenStatus();
  }

  Future<void> _checkFullscreenStatus() async {
    final isFullscreen = await windowManager.isFullScreen();
    if (mounted) {
      setState(() {
        _isFullscreen = isFullscreen;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => windowManager.minimize(),
          icon: const Icon(Icons.minimize),
          tooltip: 'מזער',
        ),
        IconButton(
          onPressed: () async {
            setState(() {
              _isFullscreen = !_isFullscreen;
            });
            await windowManager.setFullScreen(_isFullscreen);
          },
          icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
          tooltip: _isFullscreen ? 'צא ממסך מלא' : 'מסך מלא',
        ),
        IconButton(
          onPressed: () => windowManager.close(),
          icon: const Icon(Icons.close),
          tooltip: 'סגור',
        ),
      ],
    );
  }
}
