import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/update/my_update_widget.dart';

void main() {
  group('pickPreferredReleaseForDevChannel', () {
    test('selects stable when stable core version is newer than dev', () {
      final selected = pickPreferredReleaseForDevChannel(
        stableRelease: {'tag_name': '0.9.93+674'},
        devRelease: {'tag_name': '0.9.92+631'},
      );

      expect(selected['tag_name'], '0.9.93+674');
    });

    test('selects dev when dev core version is newer than stable', () {
      final selected = pickPreferredReleaseForDevChannel(
        stableRelease: {'tag_name': '0.9.93+674'},
        devRelease: {'tag_name': '0.9.94+10'},
      );

      expect(selected['tag_name'], '0.9.94+10');
    });

    test('selects stable release metadata when core versions are equal', () {
      final selected = pickPreferredReleaseForDevChannel(
        stableRelease: {'tag_name': '0.9.92'},
        devRelease: {'tag_name': '0.9.92+631'},
      );

      expect(selected['tag_name'], '0.9.92');
    });
  });
}
