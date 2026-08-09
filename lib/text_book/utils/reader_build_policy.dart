import 'package:otzaria/text_book/bloc/text_book_state.dart';

/// מסנן עדכוני גלילה ומטא-בחירה שאינם משנים את עץ הקורא.
bool shouldRebuildReader(TextBookState previous, TextBookState current) {
  if (previous is! TextBookLoaded || current is! TextBookLoaded) return true;
  return previous.copyWith(
        visibleIndices: current.visibleIndices,
        clearSelectedText: true,
      ) !=
      current.copyWith(clearSelectedText: true);
}
