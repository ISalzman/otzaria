import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/bloc/search_bloc.dart';
import 'package:otzaria/search/bloc/search_event.dart';
import 'package:otzaria/search/bloc/search_state.dart';

void main() {
  group('SearchBloc facet counts', () {
    blocTest<SearchBloc, SearchState>(
      'UpdateFacetCounts ממזג עדכונים נקודתיים לקאש',
      build: SearchBloc.new,
      act: (bloc) {
        bloc.add(UpdateFacetCounts({'/א': 1}));
        bloc.add(UpdateFacetCounts({'/ב': 2}));
      },
      expect: () => [
        isA<SearchState>()
            .having((state) => state.facetCounts.length, 'length', 1)
            .having((state) => state.facetCounts['/א'], '/א', 1),
        isA<SearchState>()
            .having((state) => state.facetCounts.length, 'length', 2)
            .having((state) => state.facetCounts['/א'], '/א', 1)
            .having((state) => state.facetCounts['/ב'], '/ב', 2),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'ReplaceFacetCounts מחליף אגרגציה מלאה ומסיר מפתחות ישנים',
      build: SearchBloc.new,
      act: (bloc) {
        bloc.add(UpdateFacetCounts({'/ישן': 1, '/נשאר': 2}));
        bloc.add(ReplaceFacetCounts({'/נשאר': 3}));
      },
      expect: () => [
        isA<SearchState>()
            .having((state) => state.facetCounts.length, 'length', 2)
            .having((state) => state.facetCounts['/ישן'], '/ישן', 1)
            .having((state) => state.facetCounts['/נשאר'], '/נשאר', 2),
        isA<SearchState>()
            .having((state) => state.facetCounts.length, 'length', 1)
            .having((state) => state.facetCounts['/ישן'], '/ישן', isNull)
            .having((state) => state.facetCounts['/נשאר'], '/נשאר', 3),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'ניקוי query מאפס גם את facetCounts',
      build: SearchBloc.new,
      act: (bloc) {
        bloc.add(UpdateFacetCounts({'/א': 1}));
        bloc.add(UpdateSearchQuery(''));
      },
      expect: () => [
        isA<SearchState>()
            .having((state) => state.facetCounts.length, 'length', 1)
            .having((state) => state.facetCounts['/א'], '/א', 1),
        isA<SearchState>()
            .having((state) => state.searchQuery, 'searchQuery', '')
            .having((state) => state.facetCounts.isEmpty, 'facetCounts empty',
                true),
      ],
    );
  });
}
