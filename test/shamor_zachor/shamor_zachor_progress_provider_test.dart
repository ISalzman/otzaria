import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/tools/shamor_zachor/models/progress_model.dart';
import 'package:otzaria/tools/shamor_zachor/providers/shamor_zachor_progress_provider.dart';
import 'package:otzaria/tools/shamor_zachor/services/progress_service.dart';

class _FakeProgressService extends ProgressService {
  _FakeProgressService({
    required this.fullProgress,
    required this.completionDates,
    required this.progressById,
    required this.completionDatesById,
  });

  FullProgressMap fullProgress;
  CompletionDatesMap completionDates;
  ProgressMapById progressById;
  CompletionDatesByIdMap completionDatesById;

  @override
  Future<FullProgressMap> loadFullProgressData() async => fullProgress;

  @override
  Future<CompletionDatesMap> loadCompletionDates() async => completionDates;

  @override
  Future<ProgressMapById> loadProgressDataById() async => progressById;

  @override
  Future<CompletionDatesByIdMap> loadCompletionDatesById() async =>
      completionDatesById;

  @override
  Future<void> saveProgressDataById(ProgressMapById data) async {
    progressById = data;
  }

  @override
  Future<void> saveCompletionDatesById(CompletionDatesByIdMap dates) async {
    completionDatesById = dates;
  }
}

void main() {
  group('ShamorZachorProgressProvider', () {
    test('clearBookProgressById clears both id-based and legacy progress',
        () async {
      final service = _FakeProgressService(
        fullProgress: {
          'תלמוד בבלי': {
            'ברכות': {
              '0': PageProgress(learn: true),
            },
          },
        },
        completionDates: {
          'תלמוד בבלי': {
            'ברכות': '2026-04-06',
          },
        },
        progressById: {
          42: {
            '0': PageProgress(learn: true, review1: true),
          },
        },
        completionDatesById: {
          42: '2026-04-06',
        },
      );

      final provider = ShamorZachorProgressProvider(progressService: service);

      await provider.ensureLoaded();
      await provider.clearBookProgressById(
        42,
        categoryName: 'תלמוד בבלי',
        bookName: 'ברכות',
      );

      expect(provider.getProgressForBookById(42), isEmpty);
      expect(provider.getCompletionDateSyncById(42), isNull);
      expect(provider.getProgressForBook('תלמוד בבלי', 'ברכות'), isEmpty);
      expect(provider.getCompletionDateSync('תלמוד בבלי', 'ברכות'), isNull);
      expect(service.progressById.containsKey(42), isFalse);
      expect(service.completionDatesById.containsKey(42), isFalse);
    });
  });
}
