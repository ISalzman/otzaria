import 'package:equatable/equatable.dart';
import 'package:otzaria/tour/models/tour_step.dart';

class TourState extends Equatable {
  final bool isActive;
  final bool libraryLoaded;
  final int currentIndex;
  final List<TourStep> steps;
  final bool isAutoPlaying;

  const TourState({
    required this.isActive,
    required this.libraryLoaded,
    required this.currentIndex,
    required this.steps,
    this.isAutoPlaying = false,
  });

  const TourState.inactive()
      : isActive = false,
        libraryLoaded = true,
        currentIndex = 0,
        steps = const [],
        isAutoPlaying = false;

  TourStep? get currentStep {
    if (!isActive || steps.isEmpty || currentIndex >= steps.length) {
      return null;
    }
    return steps[currentIndex];
  }

  bool get isLastStep => currentIndex >= steps.length - 1;
  int get totalSteps => steps.length;

  List<TourStep> get progressSteps => steps.where((s) => !s.isDialog).toList();

  int get progressIndex {
    final step = currentStep;
    if (step == null || step.isDialog) return -1;
    return progressSteps.indexWhere((s) => s.id == step.id);
  }

  TourState copyWith({
    bool? isActive,
    bool? libraryLoaded,
    int? currentIndex,
    List<TourStep>? steps,
    bool? isAutoPlaying,
  }) {
    return TourState(
      isActive: isActive ?? this.isActive,
      libraryLoaded: libraryLoaded ?? this.libraryLoaded,
      currentIndex: currentIndex ?? this.currentIndex,
      steps: steps ?? this.steps,
      isAutoPlaying: isAutoPlaying ?? this.isAutoPlaying,
    );
  }

  @override
  List<Object?> get props =>
      [isActive, libraryLoaded, currentIndex, steps, isAutoPlaying];
}
