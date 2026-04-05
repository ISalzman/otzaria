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

    blocTest<SearchBloc, SearchState>(
      'SetFacetsWithoutSearch מעדכן גם currentFacets וגם searchScopeFacets',
      build: SearchBloc.new,
      act: (bloc) => bloc.add(const SetFacetsWithoutSearch(['/תנ"ך'])),
      expect: () => [
        isA<SearchState>().having(
            (state) => state.currentFacets, 'currentFacets', [
          '/תנ"ך'
        ]).having((state) => state.searchScopeFacets, 'searchScopeFacets', [
          '/תנ"ך'
        ]).having((state) => state.hasScopedFacetFilter, 'hasScopedFacetFilter',
            true),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'SetFacet משנה פילטר נוכחי אבל שומר על טווח החיפוש המקורי',
      build: SearchBloc.new,
      act: (bloc) {
        bloc.add(const SetFacetsWithoutSearch(['/תנ"ך']));
        bloc.add(SetFacet('/תנ"ך/ראשונים'));
      },
      expect: () => [
        isA<SearchState>().having(
            (state) => state.currentFacets, 'currentFacets', [
          '/תנ"ך'
        ]).having(
            (state) => state.searchScopeFacets, 'searchScopeFacets', ['/תנ"ך']),
        isA<SearchState>().having(
            (state) => state.currentFacets, 'currentFacets', [
          '/תנ"ך/ראשונים'
        ]).having(
            (state) => state.searchScopeFacets, 'searchScopeFacets', ['/תנ"ך']),
        isA<SearchState>()
            .having((state) => state.isLoading, 'isLoading', false)
            .having((state) => state.searchQuery, 'searchQuery', '')
            .having((state) => state.currentFacets, 'currentFacets', [
          '/תנ"ך/ראשונים'
        ]).having(
            (state) => state.searchScopeFacets, 'searchScopeFacets', ['/תנ"ך']),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'SetFacetsWithoutSearch עם בחירה ריקה מסמן שלא נבחרו קטגוריות',
      build: SearchBloc.new,
      act: (bloc) => bloc.add(const SetFacetsWithoutSearch([])),
      expect: () => [
        isA<SearchState>()
            .having((state) => state.currentFacets, 'currentFacets', [])
            .having(
                (state) => state.searchScopeFacets, 'searchScopeFacets', [])
            .having(
                (state) => state.hasNoSelectedFacets, 'hasNoSelectedFacets',
                true),
      ],
    );
  });
}
