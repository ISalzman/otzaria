import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/file_sync/bloc/file_sync_bloc.dart';
import 'package:otzaria/file_sync/bloc/file_sync_event.dart';
import 'package:otzaria/file_sync/bloc/file_sync_state.dart';
import 'package:otzaria/file_sync/file_sync_widget.dart';

class MockFileSyncBloc extends MockBloc<FileSyncEvent, FileSyncState>
    implements FileSyncBloc {}

void main() {
  testWidgets('בזמן syncing אייקון הסנכרון ממשיך להסתובב',
      (WidgetTester tester) async {
    final bloc = MockFileSyncBloc();
    const syncingState = FileSyncState(
      status: FileSyncStatus.syncing,
      message: 'בודק עדכוני ספרייה...',
    );

    whenListen(
      bloc,
      const Stream<FileSyncState>.empty(),
      initialState: syncingState,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<FileSyncBloc>.value(
          value: bloc,
          child: const Scaffold(
            body: SyncIconButton(),
          ),
        ),
      ),
    );

    final rotationFinder = find.descendant(
      of: find.byType(SyncIconButton),
      matching: find.byType(RotationTransition),
    );

    final initialTurns =
        tester.widget<RotationTransition>(rotationFinder.first).turns.value;

    await tester.pump(const Duration(milliseconds: 500));

    final updatedTurns =
        tester.widget<RotationTransition>(rotationFinder.first).turns.value;

    expect(updatedTurns, greaterThan(initialTurns));
  });
}
