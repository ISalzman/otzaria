import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/pdf_book/view/pdf_book_screen.dart';
import 'package:otzaria/widgets/layout/adaptive_side_pane.dart';
import 'package:otzaria/settings/services/per_book_settings_service.dart'
    show PdfLayoutMode;
import 'package:pdfrx/pdfrx.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (call) async => switch (call.method) {
            'getTemporaryDirectory' => '/tmp/otzaria-pdfrx-test',
            _ => null,
          },
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  Future<PdfDocument> openTestDocument(WidgetTester tester) async {
    final document = await tester.runAsync(() async {
      final source = pw.Document();
      source.addPage(
        pw.Page(
          build: (context) => pw.SizedBox(),
        ),
      );
      final bytes = await source.save();
      return PdfDocument.openData(
        bytes,
        sourceName: 'pdf-viewer-resize-test.pdf',
        useProgressiveLoading: false,
      );
    });
    return document!;
  }

  Future<void> waitForViewer(
    WidgetTester tester,
    PdfViewerController controller,
  ) async {
    var hasLayout = false;
    for (var i = 0; i < 30 && !hasLayout; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      if (controller.isReady) {
        try {
          controller.viewSize;
          hasLayout = true;
        } catch (_) {
          // pdfrx exposes isReady slightly before the first layout frame.
        }
      }
    }
    expect(hasLayout, isTrue);
  }

  Widget buildHost({
    required PdfDocument document,
    required PdfViewerController controller,
    required double width,
    required bool showRightPane,
    required ValueChanged<bool> onShowRightPaneChanged,
  }) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          width: width,
          height: 700,
          // אותה הרכבה שבמסך ה-PDF: חלונית המפרשים עוטפת את הקורא.
          child: AdaptiveSidePane(
            isOpen: showRightPane,
            alignment: AlignmentDirectional.centerStart,
            paneContent: const SizedBox.shrink(),
            paneWidth: 240,
            minPaneWidth: 180,
            onClose: () => onShowRightPaneChanged(false),
            minMainContentWidth: 500,
            mainContent: PdfViewer(
              PdfDocumentRefDirect(document),
              controller: controller,
              params: const PdfViewerParams(
                sizeDelegateProvider: PdfViewerSizeDelegateProviderSmart(
                  maxScale: 20,
                  smartMaxScale: 20,
                  maxPagesVisible: 1,
                ),
                behaviorControlParams: PdfViewerBehaviorControlParams(
                  trailingPageLoadingDelay: Duration.zero,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('PDF shrinks when a wide side pane opens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final document = await openTestDocument(tester);
    addTearDown(document.dispose);
    final controller = PdfViewerController();
    var showRightPane = false;
    late ValueChanged<bool> setShowRightPane;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setShowRightPane = (value) => setState(() {
            showRightPane = value;
          });
          return buildHost(
            document: document,
            controller: controller,
            width: 1400,
            showRightPane: showRightPane,
            onShowRightPaneChanged: setShowRightPane,
          );
        },
      ),
    );
    await waitForViewer(tester, controller);

    final initialWidth = controller.viewSize.width;
    final initialZoom = controller.value.zoom;
    setShowRightPane(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(controller.viewSize.width, lessThan(initialWidth));
    expect(controller.value.zoom, lessThan(initialZoom));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });

  test('PDF layout modes select the intended resize policies', () {
    expect(
      pdfSizeDelegateProviderForLayoutMode(PdfLayoutMode.regularView),
      isA<PdfViewerSizeDelegateProviderSmart>(),
    );
    expect(
      pdfSizeDelegateProviderForLayoutMode(PdfLayoutMode.bookView),
      isA<PdfViewerSizeDelegateProviderLegacy>(),
    );
  });

  testWidgets('PDF does not resize when a narrow side pane overlays it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(620, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final document = await openTestDocument(tester);
    addTearDown(document.dispose);
    final controller = PdfViewerController();
    var showRightPane = false;
    late ValueChanged<bool> setShowRightPane;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setShowRightPane = (value) => setState(() {
            showRightPane = value;
          });
          return buildHost(
            document: document,
            controller: controller,
            width: 620,
            showRightPane: showRightPane,
            onShowRightPaneChanged: setShowRightPane,
          );
        },
      ),
    );
    await waitForViewer(tester, controller);

    final initialWidth = controller.viewSize.width;
    final initialZoom = controller.value.zoom;
    setShowRightPane(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(controller.viewSize.width, closeTo(initialWidth, 0.1));
    expect(controller.value.zoom, closeTo(initialZoom, 0.01));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });

  Future<PdfDocument> openMultiPageDocument(WidgetTester tester) async {
    final document = await tester.runAsync(() async {
      final source = pw.Document();
      for (var i = 0; i < 8; i++) {
        source.addPage(pw.Page(build: (context) => pw.SizedBox()));
      }
      final bytes = await source.save();
      return PdfDocument.openData(
        bytes,
        sourceName: 'pdf-viewer-anchor-test.pdf',
        useProgressiveLoading: false,
      );
    });
    return document!;
  }

  test('top anchor keeps the document line at the head of the view', () {
    // מרכז שמציב את 500 בראש תצוגה בגובה 800 בזום 2 → 500 + 400/2 = 700.
    expect(
      pdfTopAnchoredCenter(
        anchorDocTop: 500,
        currentCenter: const Offset(120, 999),
        viewSize: const Size(600, 800),
        zoom: 2,
      ),
      const Offset(120, 700),
    );
    // האופק נשאר כפי שחישבה מדיניות שינוי-הגודל.
    expect(
      pdfTopAnchoredCenter(
        anchorDocTop: 0,
        currentCenter: const Offset(75, 10),
        viewSize: const Size(600, 800),
        zoom: 1,
      ),
      const Offset(75, 400),
    );
  });

  testWidgets('closing a wide side pane keeps the reading position', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final document = await openMultiPageDocument(tester);
    addTearDown(document.dispose);
    final controller = PdfViewerController();
    var showRightPane = true;
    late ValueChanged<bool> setShowRightPane;

    double? anchorDocTop;
    Size? anchorViewSize;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setShowRightPane = (value) {
            anchorDocTop = controller.visibleRect.top;
            anchorViewSize = controller.viewSize;
            setState(() => showRightPane = value);
          };
          return MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: SizedBox(
                width: 1400,
                height: 800,
                child: AdaptiveSidePane(
                  isOpen: showRightPane,
                  alignment: AlignmentDirectional.centerStart,
                  paneContent: const SizedBox.shrink(),
                  paneWidth: 300,
                  minPaneWidth: 180,
                  onClose: () => setShowRightPane(false),
                  minMainContentWidth: 500,
                  mainContent: PdfViewer(
                    PdfDocumentRefDirect(document),
                    controller: controller,
                    params: PdfViewerParams(
                      sizeDelegateProvider:
                          const PdfViewerSizeDelegateProviderSmart(
                            maxScale: 20,
                            smartMaxScale: 20,
                            maxPagesVisible: 1,
                          ),
                      behaviorControlParams:
                          const PdfViewerBehaviorControlParams(
                            trailingPageLoadingDelay: Duration.zero,
                          ),
                      // אותה חוליה שבמסך ה-PDF (issue #1023).
                      onViewSizeChanged: (viewSize, oldViewSize, c) {
                        final top = anchorDocTop;
                        final size = anchorViewSize;
                        anchorDocTop = null;
                        anchorViewSize = null;
                        if (top == null ||
                            oldViewSize != size ||
                            oldViewSize!.width == c.viewSize.width) {
                          return;
                        }
                        Future.microtask(() {
                          if (!c.isReady) return;
                          c.goTo(
                            c.calcMatrixFor(
                              pdfTopAnchoredCenter(
                                anchorDocTop: top,
                                currentCenter: c.centerPosition,
                                viewSize: c.viewSize,
                                zoom: c.currentZoom,
                              ),
                            ),
                            duration: Duration.zero,
                          );
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    await waitForViewer(tester, controller);

    // גלילה לאמצע המסמך, כמו ניווט לתוצאת חיפוש.
    final target = controller.layout.pageLayouts[3].top;
    await tester.runAsync(
      () => controller.goTo(
        controller.calcMatrixFor(
          pdfTopAnchoredCenter(
            anchorDocTop: target,
            currentCenter: controller.centerPosition,
            viewSize: controller.viewSize,
            zoom: controller.currentZoom,
          ),
        ),
        duration: Duration.zero,
      ),
    );
    await tester.pump();

    final topBefore = controller.visibleRect.top;
    final widthBefore = controller.viewSize.width;

    setShowRightPane(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(controller.viewSize.width, greaterThan(widthBefore));
    expect(controller.visibleRect.top, closeTo(topBefore, 1.0));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });
}
