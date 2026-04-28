import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/tour/bloc/tour_state.dart';
import 'package:otzaria/tour/models/tour_steps.dart';

class TourCubit extends Cubit<TourState> {
  TourCubit() : super(const TourState.inactive());

  Timer? _autoPlayTimer;

  void startIfNeeded({required bool libraryLoaded}) {
    final status = Settings.getValue<String>(TourSteps.statusKey);
    if (state.isActive) {
      return;
    }
    if (status == null ||
        (libraryLoaded && _wasHandledWithoutLibrary(status))) {
      start(libraryLoaded: libraryLoaded);
      return;
    }
  }

  Future<void> restart({required bool libraryLoaded}) async {
    start(libraryLoaded: libraryLoaded, isRestart: true);
  }

  void start({required bool libraryLoaded, bool isRestart = false}) {
    _cancelAutoPlay();
    emit(
      TourState(
        isActive: true,
        libraryLoaded: libraryLoaded,
        currentIndex: 0,
        steps:
            TourSteps.build(libraryLoaded: libraryLoaded, isRestart: isRestart),
      ),
    );
  }

  void goToStep(int index) {
    if (!state.isActive) return;
    if (index < 0 || index >= state.steps.length) return;
    _cancelAutoPlay();
    emit(state.copyWith(currentIndex: index, isAutoPlaying: false));
  }

  void toggleAutoPlay() {
    if (state.isAutoPlaying) {
      _cancelAutoPlay();
      emit(state.copyWith(isAutoPlaying: false));
    } else {
      emit(state.copyWith(isAutoPlaying: true));
      _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        next();
      });
    }
  }

  void _cancelAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }

  Future<void> next() async {
    if (!state.isActive) return;
    if (state.isLastStep) {
      await complete();
      return;
    }
    emit(state.copyWith(currentIndex: state.currentIndex + 1));
  }

  Future<void> skip() async {
    _cancelAutoPlay();
    final status = state.libraryLoaded
        ? TourSteps.skipped
        : TourSteps.skippedWithoutLibrary;
    await Settings.setValue<String>(TourSteps.statusKey, status);
    emit(const TourState.inactive());
  }

  Future<void> complete() async {
    _cancelAutoPlay();
    final status = state.libraryLoaded
        ? TourSteps.completed
        : TourSteps.completedWithoutLibrary;
    await Settings.setValue<String>(TourSteps.statusKey, status);
    emit(const TourState.inactive());
  }

  @override
  Future<void> close() {
    _cancelAutoPlay();
    return super.close();
  }

  bool _wasHandledWithoutLibrary(String status) {
    return status == TourSteps.completedWithoutLibrary ||
        status == TourSteps.skippedWithoutLibrary;
  }
}
