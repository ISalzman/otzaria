import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/tools/measurement_converter/measurement_data.dart';

void main() {
  group('time conversion factors', () {
    test('heiluch meah amah equals 100 heiluch amah', () {
      expect(timeConversionFactors['הילוך מאה אמה']!['הילוך אמה'], 100);
      expect(timeConversionFactors['הילוך אמה']!['הילוך מאה אמה'], 1 / 100);
    });

    test('ancient time ratios match modern time factors', () {
      for (final opinion in modernTimeFactors.values) {
        final amaSeconds = opinion['הילוך אמה']!;
        final meahAmahSeconds = opinion['הילוך מאה אמה']!;
        final milSeconds = opinion['הילוך מיל']!;

        expect(meahAmahSeconds / amaSeconds, closeTo(100, 1e-9));
        expect(milSeconds / amaSeconds, closeTo(2000, 1e-9));
      }
    });
  });
}
