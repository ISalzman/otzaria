import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/printing/safer_printer_filter.dart';
import 'package:printing/printing.dart';

Printer _printer(
  String name, {
  String? model,
  bool isAvailable = true,
  bool isDefault = false,
}) => Printer(
  url: name,
  name: name,
  model: model,
  isAvailable: isAvailable,
  isDefault: isDefault,
);

void main() {
  group('SaferPrinterFilter.isFileOutputPort', () {
    test('מזהה את פורטי הקובץ של Windows ללא תלות ברישיות', () {
      for (final port in ['PORTPROMPT:', 'FILE:', 'nul:', 'SHRFAX:', 'Nul:']) {
        expect(SaferPrinterFilter.isFileOutputPort(port), isTrue, reason: port);
      }
    });

    test('פורטים פיזיים ורשת אינם קובץ', () {
      for (final port in ['USB001', 'LPT1:', '192.168.1.20', 'WSD-abc', null]) {
        expect(
          SaferPrinterFilter.isFileOutputPort(port),
          isFalse,
          reason: '$port',
        );
      }
    });
  });

  group('SaferPrinterFilter.allowed', () {
    test('מסנן לפי פורט כשהוא ידוע', () {
      final printers = [
        _printer('Microsoft Print to PDF'),
        _printer('HP LaserJet'),
      ];
      final ports = {
        'Microsoft Print to PDF': 'PORTPROMPT:',
        'HP LaserJet': 'USB001',
      };
      expect(
        SaferPrinterFilter.allowed(printers, ports).map((p) => p.name),
        ['HP LaserJet'],
      );
    });

    test('מדפסת PDF של צד שלישי עם פורט ייעודי נחסמת לפי שמה', () {
      final printers = [_printer('PDF24', model: 'PDF24 Driver')];
      expect(SaferPrinterFilter.allowed(printers, {'PDF24': 'PDF24'}), isEmpty);
    });

    test('בלי מידע על פורטים — זיהוי לפי שם ודרייבר', () {
      final printers = [
        _printer('Brother HL-2130', model: 'Brother HL-2130 series'),
        _printer('Microsoft XPS Document Writer'),
        _printer('Send To OneNote 16'),
        _printer('Fax'),
        _printer('Virtual', model: 'Print to File'),
      ];
      expect(
        SaferPrinterFilter.allowed(printers, const {}).map((p) => p.name),
        ['Brother HL-2130'],
      );
    });

    test('מדפסת לא זמינה אינה מוצעת', () {
      final printers = [_printer('HP LaserJet', isAvailable: false)];
      expect(
        SaferPrinterFilter.allowed(printers, {'HP LaserJet': 'USB001'}),
        isEmpty,
      );
    });
  });
}
