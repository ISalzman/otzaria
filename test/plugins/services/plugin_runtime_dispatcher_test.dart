import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/services/plugin_runtime_dispatcher.dart';

class _FakeWebViewController extends Fake implements InAppWebViewController {
  int loadUrlCalls = 0;
  int evaluateJavascriptCalls = 0;
  URLRequest? lastUrlRequest;

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    WebUri? allowingReadAccessTo,
    Uri? iosAllowingReadAccessTo,
  }) async {
    loadUrlCalls++;
    lastUrlRequest = urlRequest;
  }

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async {
    evaluateJavascriptCalls++;
    return null;
  }
}

void main() {
  late PluginRuntimeDispatcher dispatcher;

  setUp(() async {
    dispatcher = PluginRuntimeDispatcher.instance;
    await dispatcher.prepareForAppRestart();
  });

  test('prepareForAppShutdown tears down controllers and blocks re-registering',
      () async {
    final firstController = _FakeWebViewController();
    dispatcher.registerController('plugin-a', firstController);

    await dispatcher.prepareForAppShutdown();

    expect(firstController.loadUrlCalls, 1);
    expect(
      firstController.lastUrlRequest?.url?.toString(),
      'about:blank',
    );

    final lateController = _FakeWebViewController();
    dispatcher.registerController('plugin-a', lateController);

    await dispatcher.dispatchEventToPlugin(
      'plugin-a',
      'reader.current_ref_changed',
      {'currentBook': 'בראשית'},
    );

    expect(lateController.evaluateJavascriptCalls, 0);

    await dispatcher.prepareForAppRestart();
  });
}
