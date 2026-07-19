import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/navigation_repository.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/tabs/tabs_repository.dart';

class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  final NavigationRepository _repository;

  NavigationBloc({
    required this._repository,
    required TabsRepository tabsRepository,
  }) : super(NavigationState.initial(tabsRepository.loadTabs().isNotEmpty)) {
    on<NavigateToScreen>(_onNavigateToScreen);
    on<CheckLibrary>(_onCheckLibrary);
  }

  void _onNavigateToScreen(
    NavigateToScreen event,
    Emitter<NavigationState> emit,
  ) {
    emit(state.copyWith(currentScreen: event.screen));
  }

  void _onCheckLibrary(
    CheckLibrary event,
    Emitter<NavigationState> emit,
  ) {
    final isEmpty = _repository.checkLibraryIsEmpty();
    emit(state.copyWith(isLibraryEmpty: isEmpty, hasCheckedLibrary: true));
  }

  Future<void> refreshLibrary() async {
    await _repository.refreshLibrary();
    add(const CheckLibrary());
  }
}
