import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/support_organization.dart';
import 'package:otzaria/services/support_organizations_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'השירות טוען את הקובץ דרך rootBundle — הנתיב שהאפליקציה משתמשת בו',
    () async {
      SupportOrganizationsService.resetCache();
      final organizations = await SupportOrganizationsService.load();
      expect(organizations.emergencyLines, isNotEmpty);
      expect(organizations.supportOrgs, isNotEmpty);
    },
  );

  group('SupportOrganization.fromJson', () {
    test('מחבר את שורות הפרטים לטקסט אחד', () {
      final org = SupportOrganization.fromJson(const {
        'name': 'ארגון',
        'phone': '*1234',
        'logo': 'assets/logos/x.png',
        'details': ['שורה א', 'שורה ב'],
      });

      expect(org.details, 'שורה א\nשורה ב');
      expect(org.phones, isEmpty);
      expect(org.registeredCount, isNull);
    });

    test('מציב את כמות הנרשמים עם מפריד אלפים במקום ה-placeholder', () {
      final org = SupportOrganization.fromJson(const {
        'name': 'ארגון',
        'phone': '*1234',
        'logo': 'assets/logos/x.png',
        'registeredCount': 102631,
        'details': ['7 - כמות הנרשמים (מעל {registered})'],
      });

      expect(org.details, '7 - כמות הנרשמים (מעל 102,631)');
    });
  });

  group('קובץ הנתונים ${SupportOrganizationsService.assetPath}', () {
    late SupportOrganizations organizations;
    late Map<String, dynamic> raw;

    setUpAll(() {
      final file = File(SupportOrganizationsService.assetPath);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'קובץ הנתונים חסר — הפופאפ ייפתח ריק',
      );
      raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      organizations = SupportOrganizations.fromJson(raw);
    });

    test('מוגדר ב-pubspec כדי שייארז לאפליקציה', () {
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains(SupportOrganizationsService.assetPath),
      );
    });

    test('שתי הקבוצות אינן ריקות', () {
      expect(organizations.emergencyLines, isNotEmpty);
      expect(organizations.supportOrgs, isNotEmpty);
    });

    test('לכל ארגון שם, טלפון וקובץ לוגו קיים', () {
      final all = [
        ...organizations.emergencyLines,
        ...organizations.supportOrgs,
      ];
      for (final org in all) {
        expect(org.name.trim(), isNotEmpty);
        expect(org.phone.trim(), isNotEmpty);
        expect(
          File(org.logo).existsSync(),
          isTrue,
          reason: 'הלוגו ${org.logo} של "${org.name}" לא קיים בדיסק',
        );
      }
    });

    test('כמות הנרשמים מוצבת — לא נשאר placeholder בטקסט המוצג', () {
      final all = [
        ...organizations.emergencyLines,
        ...organizations.supportOrgs,
      ];
      for (final org in all) {
        expect(
          org.details,
          isNot(contains('{registered}')),
          reason: 'ל"${org.name}" יש {registered} בלי registeredCount',
        );
      }
    });

    test('ארגון עם registeredCount מציג אותו בפרטים', () {
      final all = [
        ...organizations.emergencyLines,
        ...organizations.supportOrgs,
      ].where((org) => org.registeredCount != null);

      expect(all, isNotEmpty);
      for (final org in all) {
        expect(
          org.details,
          contains('כמות הנרשמים'),
          reason: 'ל"${org.name}" יש registeredCount שלא מופיע בפרטים',
        );
      }
    });

    test('details נשמר כמערך שורות, לא כמחרוזת אחת', () {
      for (final section in ['emergencyLines', 'supportOrgs']) {
        for (final org in raw[section] as List<dynamic>) {
          expect(
            (org as Map<String, dynamic>)['details'],
            isA<List<dynamic>>(),
            reason: 'details של "${org['name']}" חייב להיות מערך שורות',
          );
        }
      }
    });
  });
}
