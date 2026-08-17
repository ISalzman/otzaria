import 'package:otzaria/plugins/models/plugin_book_identity.dart';
import 'package:otzaria/plugins/services/reader_selection_service.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/view/selection/selected_text_restore.dart';
import 'package:otzaria/widgets/smart_text/render_settings.dart';

/// בונה payload של בחירה לתוסף, בדיוק כמו תפריט הלחיצה הימנית על טקסט:
/// מרונדר את השורה, מאתר בה את הבחירה ובונה את ה-map המלא שמועבר לפלאגין.
/// משותף לתפריט ההקשר ולקיצורי המקלדת של פעולות תפריט ההקשר.
Map<String, dynamic> buildPluginSelectionPayload({
  required TextBookLoaded state,
  required String rawText,
  required String selectedText,
  required int sectionIndex,
  required int? startHint,
  required RenderSettings settings,
}) {
  const selectionService = ReaderSelectionService();
  final renderedLine = renderSelectionLine(
    rawText: rawText,
    settings: settings,
  );
  final localRange = selectionService.locateRenderedRange(
    renderedText: renderedLine,
    selectedText: selectedText,
    startHint: startHint,
  );
  return selectionService.buildPayload(
    bookId: state.book.title,
    bookTitle: state.book.title,
    sectionIndex: sectionIndex,
    rawText: rawText,
    settings: settings,
    selectedText: selectedText,
    renderedStartUtf16: localRange?.start,
    renderedEndUtf16: localRange?.end,
    currentRef: state.currentTitle,
    bookDbId: state.book.id,
    bookType: PluginBookIdentity.typeOf(state.book),
    bookSource: PluginBookIdentity.sourceOf(state.book),
  );
}
