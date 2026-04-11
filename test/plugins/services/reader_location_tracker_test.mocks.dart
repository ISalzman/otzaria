// Mocks generated manually for reader_location_tracker_test.dart

import 'package:mockito/mockito.dart' as mockito;
import 'package:otzaria/tabs/bloc/tabs_bloc.dart' as tabs_bloc;
import 'package:otzaria/tabs/bloc/tabs_state.dart' as tabs_state;

class MockTabsBloc extends mockito.Mock implements tabs_bloc.TabsBloc {
  @override
  tabs_state.TabsState get state => super.noSuchMethod(
        Invocation.getter(#state),
        returnValue: tabs_state.TabsState.initial(),
        returnValueForMissingStub: tabs_state.TabsState.initial(),
      );

  @override
  Stream<tabs_state.TabsState> get stream => super.noSuchMethod(
        Invocation.getter(#stream),
        returnValue: Stream<tabs_state.TabsState>.empty(),
        returnValueForMissingStub: Stream<tabs_state.TabsState>.empty(),
      );

  @override
  bool get isClosed => super.noSuchMethod(
        Invocation.getter(#isClosed),
        returnValue: false,
        returnValueForMissingStub: false,
      );
}
