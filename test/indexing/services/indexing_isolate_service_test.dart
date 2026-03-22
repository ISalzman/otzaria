import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/indexing/services/indexing_isolate_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IndexingDocumentBuilder', () {
    test('builds text book documents with hierarchical references', () {
      final documents = IndexingDocumentBuilder.buildTextBookDocuments(
        '<h1>פרק א</h1>\n'
        'שורה ראשונה\n'
        '<h2>סימן א</h2>\n'
        'שורה שניה',
      );

      expect(documents, hasLength(4));
      expect(documents[0].reference, 'פרק א');
      expect(documents[0].text, 'פרק א');
      expect(documents[1].reference, 'פרק א');
      expect(documents[1].text, 'שורה ראשונה');
      expect(documents[2].reference, 'פרק א, סימן א');
      expect(documents[2].text, 'סימן א');
      expect(documents[3].reference, 'פרק א, סימן א');
      expect(documents[3].text, 'שורה שניה');
    });

    test('replaces previous header branch when same level appears again', () {
      final documents = IndexingDocumentBuilder.buildTextBookDocuments(
        '<h1>חלק א</h1>\n'
        '<h2>סימן א</h2>\n'
        '<h1>חלק ב</h1>\n'
        'טקסט',
      );

      expect(documents.last.reference, 'חלק ב');
      expect(documents.last.text, 'טקסט');
    });
  });

  group('IndexingIsolateService', () {
    test('streams prepared text batches from isolate', () async {
      final service = await IndexingIsolateService.create();
      addTearDown(service.dispose);

      final stream = await service.processTextBook(
        text: '<h1>פרק א</h1>\nשורה א\nשורה ב',
      );

      final documents = <PreparedIndexDocument>[];
      var completed = false;

      await for (final update in stream) {
        if (update is IndexingBatchReady) {
          documents.addAll(update.documents);
          await update.acknowledge();
        } else if (update is IndexingWorkComplete) {
          completed = true;
        }
      }

      expect(completed, isTrue);
      expect(documents, hasLength(3));
      expect(documents[1].text, 'שורה א');
      expect(documents[2].text, 'שורה ב');
    });

    test('cancel stops further batch generation', () async {
      final service = await IndexingIsolateService.create();
      addTearDown(service.dispose);

      final text = List.generate(700, (index) => 'שורה $index').join('\n');
      final stream = await service.processTextBook(text: text);

      var batchesSeen = 0;
      var documentCount = 0;

      await for (final update in stream) {
        if (update is! IndexingBatchReady) {
          continue;
        }

        batchesSeen++;
        documentCount += update.documents.length;
        await service.cancelActiveWork();
        await update.acknowledge();
      }

      expect(batchesSeen, 1);
      expect(documentCount, lessThan(700));
    });
  });
}
