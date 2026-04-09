import 'package:flutter/material.dart';
import 'package:otzaria/settings/settings_exports.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/widgets/context_overlay_panel.dart';

class GematriaSettingsPanel extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onToggle;

  static const double _panelWidth = 360.0;
  static const double _narrowBreakpoint = 800.0;

  const GematriaSettingsPanel({
    super.key,
    required this.isVisible,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < _narrowBreakpoint;

    if (isNarrow) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: AppTokens.animSlow,
      curve: Curves.easeInOut,
      width: isVisible ? _panelWidth : 0,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerRight,
          maxWidth: _panelWidth,
          minWidth: 0,
          child: SizedBox(
            width: _panelWidth,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: _buildPanelContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildNarrowOverlay(BuildContext context) {
    return ContextOverlayPanel(
      isOpen: isVisible,
      onClose: onToggle,
      width: _panelWidth,
      alignment: AlignmentDirectional.centerStart,
      child: _buildPanelContent(context),
    );
  }

  Widget _buildPanelContent(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppTokens.spaceSM),
          child: Row(
            children: [
              Text(
                'הגדרות',
                textDirection: TextDirection.rtl,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const Expanded(
          child: SingleChildScrollView(
            child: GematriaSettingsTab(),
          ),
        ),
      ],
    );
  }
}