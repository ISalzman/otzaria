import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/links.dart';

void main() {
  test('getLinksforIndexs שומר קישורים נפרדים משורות מקור שונות', () async {
    final links = [
      Link(
        heRef: 'רש"י פסוק א',
        index1: 22,
        path2: 'רש"י על בראשית',
        index2: 5,
        connectionType: 'COMMENTARY',
      ),
      Link(
        heRef: 'רש"י פסוק א',
        index1: 23,
        path2: 'רש"י על בראשית',
        index2: 5,
        connectionType: 'COMMENTARY',
      ),
    ];

    final result = await getLinksforIndexs(
      indexes: const [21, 22],
      links: links,
      commentatorsToShow: const ['רש"י על בראשית'],
    );

    expect(result, hasLength(2));
    expect(result.first.path2, 'רש"י על בראשית');
    expect(result.first.index2, 5);
  });
}
