import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/find_ref/repository/find_ref_repository.dart';

void main() {
  test('dispose מסיר repository מרשימת המופעים הפעילים', () {
    final countBefore = FindRefRepository.debugLiveInstanceCount;
    final repository = FindRefRepository();

    expect(FindRefRepository.debugLiveInstanceCount, countBefore + 1);

    repository.dispose();

    expect(FindRefRepository.debugLiveInstanceCount, countBefore);
  });
}
