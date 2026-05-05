import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/empty_library/bloc/empty_library_bloc.dart';
import 'package:otzaria/empty_library/bloc/empty_library_event.dart';
import 'package:otzaria/empty_library/bloc/empty_library_state.dart';
import 'package:otzaria/empty_library/empty_library_screen.dart';

class MockEmptyLibraryBloc
    extends MockBloc<EmptyLibraryEvent, EmptyLibraryState>
    implements EmptyLibraryBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EmptyLibraryScreen', () {
    late MockEmptyLibraryBloc bloc;
    late StreamController<EmptyLibraryState> stateController;

    setUp(() {
      bloc = MockEmptyLibraryBloc();
      stateController = StreamController<EmptyLibraryState>.broadcast();

      whenListen(
        bloc,
        stateController.stream,
        initialState: const EmptyLibraryInitial(),
      );
    });

    tearDown(() async {
      await stateController.close();
    });

    testWidgets('קורא ל-onLibraryLoaded אחרי בחירת ספריה', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var callbackCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: EmptyLibraryScreen(
            bloc: bloc,
            onLibraryLoaded: () async {
              callbackCount++;
            },
          ),
        ),
      );

      stateController.add(
        const EmptyLibraryDirectorySelected(selectedPath: 'C:/library'),
      );

      await tester.pump();

      expect(callbackCount, 1);
    });

    testWidgets('לא קורא ל-onLibraryLoaded בלי בחירת ספריה', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var callbackCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: EmptyLibraryScreen(
            bloc: bloc,
            onLibraryLoaded: () async {
              callbackCount++;
            },
          ),
        ),
      );

      await tester.pump();

      expect(callbackCount, 0);
    });
  });
}
