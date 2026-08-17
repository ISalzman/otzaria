import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:otzaria/plugins/services/plugin_report_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PackageInfo.setMockInitialValues(
    appName: 'Otzaria',
    packageName: 'com.otzaria.app',
    version: '0.9.97',
    buildNumber: '1',
    buildSignature: '',
  );

  group('PluginReportService.generateReportId', () {
    test('מייצר UUID v4 תקין וייחודי', () {
      final id = PluginReportService.generateReportId();
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(id),
        isTrue,
        reason: 'מזהה לא בפורמט UUID v4: $id',
      );
      expect(id, isNot(PluginReportService.generateReportId()));
    });
  });

  group('PluginReportService.sendReport', () {
    test('שולח את כל שדות החוזה לכתובת הנכונה', () async {
      late http.Request captured;
      final service = PluginReportService(
        client: MockClient((request) async {
          captured = request;
          return http.Response('{"success":true}', 200);
        }),
      );

      final result = await service.sendReport(
        pluginUid: 'test.plugin',
        pluginName: 'תוסף בדיקה',
        pluginVersion: '1.2.3',
        details: '  התוסף קורס  ',
        reportType: 'bug',
        reporterEmail: ' me@example.com ',
      );

      expect(result['success'], isTrue);
      expect(captured.url, PluginReportService.endpoint);
      expect(captured.method, 'POST');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['pluginUid'], 'test.plugin');
      expect(body['pluginName'], 'תוסף בדיקה');
      expect(body['pluginVersion'], '1.2.3');
      expect(body['reportType'], 'bug');
      expect(body['details'], 'התוסף קורס');
      expect(body['reporterEmail'], 'me@example.com');
      expect(body['appVersion'], '0.9.97');
      expect(body['platform'], Platform.operatingSystem);
      expect(body['reportId'], isA<String>());
    });

    test('סוג דיווח לא מוכר מתורגם ל-other, ומייל ריק מושמט', () async {
      late Map<String, dynamic> body;
      final service = PluginReportService(
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{"success":true}', 200);
        }),
      );

      await service.sendReport(
        pluginUid: 'test.plugin',
        pluginName: 'Test',
        pluginVersion: '1.0.0',
        details: 'משהו',
        reportType: 'whatever',
        reporterEmail: '   ',
      );

      expect(body['reportType'], 'other');
      expect(body.containsKey('reporterEmail'), isFalse);
    });

    test('פירוט ארוך נחתך ל-5000 תווים', () async {
      late Map<String, dynamic> body;
      final service = PluginReportService(
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{"success":true}', 200);
        }),
      );

      await service.sendReport(
        pluginUid: 'test.plugin',
        pluginName: 'Test',
        pluginVersion: '1.0.0',
        details: 'א' * 6000,
      );

      expect((body['details'] as String).length, 5000);
    });

    test('פירוט ריק נדחה לפני קריאת רשת', () async {
      var called = false;
      final service = PluginReportService(
        client: MockClient((request) async {
          called = true;
          return http.Response('{"success":true}', 200);
        }),
      );

      await expectLater(
        service.sendReport(
          pluginUid: 'test.plugin',
          pluginName: 'Test',
          pluginVersion: '1.0.0',
          details: '   ',
        ),
        throwsA(isA<Exception>()),
      );
      expect(called, isFalse);
    });

    test('תשובה שאינה 2xx זורקת עם קוד הסטטוס', () async {
      final service = PluginReportService(
        client: MockClient(
          (request) async => http.Response('rate limited', 429),
        ),
      );

      await expectLater(
        service.sendReport(
          pluginUid: 'test.plugin',
          pluginName: 'Test',
          pluginVersion: '1.0.0',
          details: 'משהו',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('429'),
          ),
        ),
      );
    });

    test('שגיאת רשת נזרקת ואינה נבלעת', () async {
      final service = PluginReportService(
        client: MockClient((request) async {
          throw const SocketException('no route to host');
        }),
      );

      await expectLater(
        service.sendReport(
          pluginUid: 'test.plugin',
          pluginName: 'Test',
          pluginVersion: '1.0.0',
          details: 'משהו',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('failed to send report'),
          ),
        ),
      );
    });

    test('תשובת 200 עם duplicate מוחזרת כמות שהיא', () async {
      final service = PluginReportService(
        client: MockClient(
          (request) async =>
              http.Response('{"success":true,"duplicate":true}', 200),
        ),
      );

      final result = await service.sendReport(
        pluginUid: 'test.plugin',
        pluginName: 'Test',
        pluginVersion: '1.0.0',
        details: 'משהו',
      );

      expect(result['duplicate'], isTrue);
    });
  });
}
