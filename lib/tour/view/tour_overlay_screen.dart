import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/tour/bloc/tour_cubit.dart';
import 'package:otzaria/tour/bloc/tour_state.dart';
import 'package:otzaria/tour/models/live_tip.dart';
import 'package:otzaria/tour/models/tour_step.dart';
import 'package:otzaria/tour/widgets/live_tip_card.dart';
import 'package:otzaria/tour/widgets/spotlight_overlay.dart';
import 'package:otzaria/tour/widgets/tour_tooltip_card.dart';

class TourOverlayScreen extends StatefulWidget {
  final ValueChanged<TourStep> onStepChanged;
  final ValueChanged<TourStep>? onNext;
  final Rect? Function(TourStep step)? targetRectResolver;
  final List<Rect> Function(TourStep step)? targetRectsResolver;

  const TourOverlayScreen({
    super.key,
    required this.onStepChanged,
    this.onNext,
    this.targetRectResolver,
    this.targetRectsResolver,
  });

  @override
  State<TourOverlayScreen> createState() => _TourOverlayScreenState();
}

class _TourOverlayScreenState extends State<TourOverlayScreen> {
  String? _lastStepId;
  Rect? _lastResolvedRect;
  bool _retryScheduled = false;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TourCubit, TourState>(
      listenWhen: (previous, current) =>
          current.isActive &&
          current.currentStep != null &&
          previous.currentStep?.id != current.currentStep?.id,
      listener: (context, state) {
        final step = state.currentStep;
        if (step != null) {
          _lastStepId = step.id;
          _lastResolvedRect = null;
          widget.onStepChanged(step);
        }
      },
      builder: (context, state) {
        final step = state.currentStep;
        if (!state.isActive || step == null) {
          if (state.activeLiveTipId == null) {
            return const SizedBox.shrink();
          }
          return _LiveTipOverlay(
            tip: liveTipSpecById(state.activeLiveTipId!),
            targetRectResolver: widget.targetRectResolver,
          );
        }

        if (state.hasActiveLiveTip) {
          return const SizedBox.shrink();
        }

        return Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final resolvedRect = widget.targetRectResolver?.call(step);
              final resolvedRects = widget.targetRectsResolver?.call(step);
              if (resolvedRect != null) {
                _lastStepId = step.id;
                _lastResolvedRect = resolvedRect;
              }

              final targetRect = _targetRectForStep(
                step: step,
                size: size,
                context: context,
                resolvedRect: resolvedRect,
              );
              final targetRects = resolvedRects == null || resolvedRects.isEmpty
                  ? [targetRect]
                  : resolvedRects;
              final combinedTargetRect =
                  targetRects.skip(1).fold(targetRects.first, (rect, next) {
                return rect.expandToInclude(next);
              });
              final cardAlignment =
                  _cardAlignmentFor(step, combinedTargetRect, size);
              final isWelcomeStep = step.id == 'welcome';
              final isRestartEntry = step.id == 'restart_welcome';

              return Stack(
                children: [
                  if (step.isDialog)
                    IgnorePointer(
                      child: Container(
                        color: Theme.of(context)
                            .colorScheme
                            .scrim
                            .withValues(alpha: 0.62),
                      ),
                    )
                  else
                    SpotlightOverlay(
                      targetRect: combinedTargetRect,
                      targetRects: targetRects,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  Align(
                    alignment: cardAlignment,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (child, animation) {
                          final blur = Tween<double>(begin: 8.0, end: 0.0)
                              .animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          ));
                          return AnimatedBuilder(
                            animation: blur,
                            builder: (context, inner) => ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(
                                sigmaX: blur.value,
                                sigmaY: blur.value,
                                tileMode: TileMode.decal,
                              ),
                              child: FadeTransition(
                                opacity: animation,
                                child: inner,
                              ),
                            ),
                            child: child,
                          );
                        },
                        child: TourTooltipCard(
                          key: ValueKey(step.id),
                          title: step.title,
                          body: step.body,
                          currentIndex: state.progressIndex,
                          totalSteps: state.progressSteps.length,
                          isLastStep: state.isLastStep,
                          isWelcomeStep: isWelcomeStep,
                          isRestartEntry: isRestartEntry,
                          isAutoPlaying: state.isAutoPlaying,
                          isDialog: step.isDialog,
                          onNext: () {
                            final onNext = widget.onNext;
                            if (onNext != null) {
                              onNext(step);
                            } else {
                              context.read<TourCubit>().next();
                            }
                          },
                          onSkip: () => context.read<TourCubit>().skip(),
                          onToggleAutoPlay: () =>
                              context.read<TourCubit>().toggleAutoPlay(),
                          onDotTap: (i) {
                            final targetId = state.progressSteps[i].id;
                            final actualIndex =
                                state.steps.indexWhere((s) => s.id == targetId);
                            context.read<TourCubit>().goToStep(actualIndex);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Rect _targetRectForStep({
    required TourStep step,
    required Size size,
    required BuildContext context,
    required Rect? resolvedRect,
  }) {
    if (resolvedRect != null) {
      return resolvedRect;
    }

    if (step.area == TourSpotlightArea.bookCard) {
      if (_lastStepId == step.id && _lastResolvedRect != null) {
        _scheduleRetry();
        return _lastResolvedRect!;
      }
      _scheduleRetry();
      return Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: 1,
        height: 1,
      );
    }

    return tourTargetRectFor(
      step.area,
      size,
      Directionality.of(context),
    );
  }

  void _scheduleRetry() {
    if (_retryScheduled) {
      return;
    }
    _retryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _retryScheduled = false;
      setState(() {});
    });
  }

  Alignment _cardAlignmentFor(TourStep step, Rect targetRect, Size size) {
    if (step.isDialog) {
      return Alignment.center;
    }
    return Alignment.bottomLeft;
  }
}

class _LiveTipOverlay extends StatelessWidget {
  final LiveTipSpec tip;
  final Rect? Function(TourStep step)? targetRectResolver;

  const _LiveTipOverlay({
    required this.tip,
    required this.targetRectResolver,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final targetRect = targetRectResolver?.call(
                TourStep(
                  id: 'live_tip_${tip.id.name}',
                  title: tip.title,
                  body: tip.description,
                  area: tip.area,
                ),
              ) ??
              tourTargetRectFor(
                tip.area,
                size,
                Directionality.of(context),
              );
          final cardWidth = size.width < 392 ? size.width - 32 : 360.0;
          final left = ((targetRect.right - cardWidth)
                  .clamp(16.0, size.width - cardWidth - 16.0))
              .toDouble();
          final top = ((targetRect.bottom + 12)
                  .clamp(16.0, math.max(16.0, size.height - 190)))
              .toDouble();

          return Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                width: cardWidth,
                child: LiveTipCard(
                  title: tip.title,
                  description: tip.description,
                  onDismiss: () => context.read<TourCubit>().dismissLiveTip(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Rect tourTargetRectFor(
  TourSpotlightArea area,
  Size size,
  TextDirection textDirection,
) {
  final width = size.width;
  final height = size.height;
  final isLandscape = width >= height;
  final isRtl = textDirection == TextDirection.rtl;
  const navigationRailWidth = 74.0;
  const navigationSpotlightPadding = 4.0;
  const toolbarTop = 32.0;
  const toolbarButtonSize = 52.0;
  const toolbarButtonStep = 42.0;

  double toolbarActionLeft(int indexFromEdge) {
    if (isRtl) {
      return 8 + indexFromEdge * toolbarButtonStep;
    }
    final rightEdge = isLandscape ? width - 8 : width - 8;
    return rightEdge - toolbarButtonSize - indexFromEdge * toolbarButtonStep;
  }

  Rect toolbarActionRect(int indexFromEdge) {
    return Rect.fromLTWH(
      toolbarActionLeft(indexFromEdge),
      toolbarTop,
      toolbarButtonSize,
      toolbarButtonSize,
    );
  }

  Rect readerNavigationButtonRect() {
    final contentRight =
        isLandscape && isRtl ? width - navigationRailWidth : width;
    final contentLeft = isLandscape && !isRtl ? navigationRailWidth : 0.0;
    return Rect.fromLTWH(
      isRtl ? contentRight - 66 : contentLeft + 14,
      toolbarTop,
      toolbarButtonSize,
      toolbarButtonSize,
    );
  }

  Rect rect;

  switch (area) {
    case TourSpotlightArea.center:
      rect = Rect.fromCenter(
        center: Offset(width / 2, height / 2),
        width: width.clamp(320, 520),
        height: 300,
      );
    case TourSpotlightArea.fullScreen:
    case TourSpotlightArea.reading:
    case TourSpotlightArea.tools:
    case TourSpotlightArea.settings:
    case TourSpotlightArea.emptyLibrary:
      rect = isLandscape
          ? Rect.fromLTRB(
              isRtl ? 8 : navigationRailWidth,
              38,
              isRtl ? width - navigationRailWidth : width - 8,
              height - 8,
            )
          : Rect.fromLTWH(8, 38, width - 16, height - 124);
    case TourSpotlightArea.navigation:
      rect = isLandscape
          ? Rect.fromLTWH(
              isRtl
                  ? width - navigationRailWidth - navigationSpotlightPadding
                  : -navigationSpotlightPadding,
              48,
              navigationRailWidth + navigationSpotlightPadding * 2,
              height - 50,
            )
          : Rect.fromLTWH(0, height - 86, width, 86);
    case TourSpotlightArea.librarySearch:
      rect = Rect.fromLTRB(
        isLandscape && !isRtl ? navigationRailWidth + 36 : 112,
        40,
        isLandscape && isRtl ? width - navigationRailWidth - 36 : width - 112,
        92,
      );
    case TourSpotlightArea.libraryCategories:
      rect = isLandscape
          ? Rect.fromLTRB(
              isRtl ? width * 0.37 : navigationRailWidth + 30,
              96,
              isRtl ? width - navigationRailWidth : width * 0.63,
              height - 42,
            )
          : Rect.fromLTWH(16, 140, width - 32, height - 240);
    case TourSpotlightArea.bookCard:
      rect = isLandscape
          ? Rect.fromLTRB(
              isRtl ? width * 0.62 : navigationRailWidth + 46,
              116,
              isRtl ? width - navigationRailWidth - 46 : width * 0.38,
              250,
            )
          : Rect.fromLTWH(24, 150, width - 48, 132);
    case TourSpotlightArea.searchDialog:
      rect = Rect.fromCenter(
        center: Offset(width / 2, height / 2),
        width: width.clamp(320, 680),
        height: height.clamp(320, 520),
      );
    case TourSpotlightArea.findRef:
      rect = Rect.fromCenter(
        center: Offset(width / 2, height / 2),
        width: width.clamp(320, 620),
        height: (height - 48).clamp(320, 760),
      );
    case TourSpotlightArea.tabs:
      final tabStripWidth = (width * 0.22).clamp(180.0, 360.0).toDouble();
      rect = Rect.fromCenter(
        center: Offset(width / 2, 24),
        width: tabStripWidth,
        height: 40,
      );
    case TourSpotlightArea.tableOfContents:
      rect = readerNavigationButtonRect();
    case TourSpotlightArea.commentators:
      rect = toolbarActionRect(7);
    case TourSpotlightArea.bookmark:
      rect = toolbarActionRect(0);
    case TourSpotlightArea.bookSearch:
      rect = toolbarActionRect(5);
    case TourSpotlightArea.readingSettings:
      rect = Rect.fromLTWH(82, 4, 230, 52);
    case TourSpotlightArea.print:
      rect = toolbarActionRect(0);
    case TourSpotlightArea.sideBySide:
      rect = Rect.fromLTWH(130, 54, 260, 58);
    case TourSpotlightArea.toolsTabs:
      rect = Rect.fromLTWH(110, 80, width - 220, 78);
    case TourSpotlightArea.designSettings:
      rect = Rect.fromLTWH(width - 310, 78, 260, 70);
    case TourSpotlightArea.backupSettings:
      rect = Rect.fromLTWH(110, 240, width - 220, 170);
    case TourSpotlightArea.shortcutsSettings:
      rect = Rect.fromLTWH(width - 310, 360, 260, 70);
  }

  final safeBounds = area == TourSpotlightArea.navigation
      ? Rect.fromLTRB(0, 8, width, height - 2)
      : Rect.fromLTWH(8, 8, width - 16, height - 16);
  return rect.intersect(safeBounds);
}
