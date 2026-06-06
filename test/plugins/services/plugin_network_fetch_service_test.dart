import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:otzaria/plugins/services/plugin_network_fetch_service.dart';

void main() {
  test('GET כברירת מחדל עם Accept כללי */*', () async {
    late http.Request captured;
    final service = PluginNetworkFetchService(
      client: MockClient((req) async {
        captured = req;
        return http.Response('hello', 200);
      }),
    );

    final result = await service.fetch(Uri.parse('https://api.example.com/x'));

    expect(captured.method, 'GET');
    expect(captured.headers['accept'], '*/*');
    expect(result.status, 200);
    expect(result.ok, isTrue);
    expect(result.body, 'hello');
  });

  test('POST מעביר method, headers ו-body', () async {
    late http.Request captured;
    final service = PluginNetworkFetchService(
      client: MockClient((req) async {
        captured = req;
        return http.Response('{"data":[]}', 200);
      }),
    );

    final result = await service.fetch(
      Uri.parse('https://nakdan.dicta.org.il/api'),
      method: 'POST',
      headers: {'Content-Type': 'application/json;charset=UTF-8'},
      body: '{"task":"nakdan"}',
    );

    expect(captured.method, 'POST');
    expect(captured.headers['content-type'], 'application/json;charset=UTF-8');
    expect(captured.body, '{"task":"nakdan"}');
    expect(result.ok, isTrue);
    expect(result.body, '{"data":[]}');
  });

  test('headers מפורשים דורסים את ברירת המחדל של Accept', () async {
    late http.Request captured;
    final service = PluginNetworkFetchService(
      client: MockClient((req) async {
        captured = req;
        return http.Response('', 200);
      }),
    );

    await service.fetch(
      Uri.parse('https://api.example.com/x'),
      headers: {'Accept': 'application/json'},
    );

    expect(captured.headers['accept'], 'application/json');
  });

  test('סטטוס שאינו 2xx מחזיר ok=false עם הסטטוס והגוף', () async {
    final service = PluginNetworkFetchService(
      client: MockClient((req) async => http.Response('nope', 404)),
    );

    final result = await service.fetch(Uri.parse('https://api.example.com/x'));

    expect(result.status, 404);
    expect(result.ok, isFalse);
    expect(result.body, 'nope');
  });
}
