# Design Document

## Overview

שילוב מלא של אפליקציית "שמור וזכור" במסך "עוד" של האפליקציה הראשית. העיצוב מתבסס על ארכיטקטורת Provider pattern הקיימת בשמור וזכור, עם התאמות לסביבת האפליקציה הראשית. הפיצר יחליף את הטקסט "בקרוב..." בפונקציונליות מלאה של מעקב לימוד תורני.

## Architecture

### High-Level Architecture
```
Main App
├── lib/navigation/more_screen.dart (existing)
├── packages/shamor_zachor/ (new internal package)
│   ├── lib/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── screens/
│   │   ├── services/
│   │   ├── widgets/
│   │   └── shamor_zachor.dart (main export)
│   ├── assets/
│   │   ├── data/
│   │   └── images/
│   └── pubspec.yaml
└── assets/shamor_zachor/ (symlink or copy)
    ├── data/
    └── images/
```

### Integration Strategy
1. **Internal Package Structure**: יצירת package פנימי `packages/shamor_zachor/` עם pubspec.yaml נפרד
2. **Path Dependency**: הוספת תלות path ב-pubspec.yaml הראשי: `shamor_zachor: { path: ./packages/shamor_zachor }`
3. **Local Provider Scope**: עטיפת ה-Providers בתוך ShamorZachorWidget (לא גלובלי)
4. **State Preservation**: שימוש ב-AutomaticKeepAliveClientMixin ו-PageStorageKey לשמירת מצב
5. **Navigation Integration**: החלפת הטקסט "בקרוב..." בווידג'ט המלא של שמור וזכור

## Components and Interfaces

### Core Components

#### 1. ShamorZachorWidget
- **Purpose**: הווידג'ט הראשי שיוצג במסך "עוד"
- **Location**: `packages/shamor_zachor/lib/shamor_zachor_widget.dart`
- **Responsibilities**:
  - עטיפת ה-Providers המקומיים
  - ניהול הניווט הפנימי של שמור וזכור
  - הצגת המסכים השונים (מעקב, ספרים, הגדרות)
  - שמירה על מצב הניווט הפנימי עם AutomaticKeepAliveClientMixin
  - ניהול Navigator פנימי לשמירת מצב ניווט

#### 2. Data Models
- **BookModel**: מודל לייצוג ספרים וקטגוריות
- **ProgressModel**: מודל למעקב התקדמות
- **Location**: `packages/shamor_zachor/lib/models/`

#### 3. Providers (Local Scope)
- **ShamorZachorDataProvider**: ניהול נתוני הספרים והקטגוריות
- **ShamorZachorProgressProvider**: ניהול נתוני ההתקדמות
- **Location**: `packages/shamor_zachor/lib/providers/`
- **Scope**: מקומי בתוך ShamorZachorWidget, לא גלובלי

#### 4. Services
- **DataLoaderService**: טעינת נתונים מקבצי JSON
- **ProgressService**: שמירה וטעינה של נתוני התקדמות עם prefix "sz:"
- **Location**: `packages/shamor_zachor/lib/services/`

#### 5. Screens (with State Preservation)
- **TrackingScreen**: מסך מעקב כללי עם AutomaticKeepAliveClientMixin
- **BooksScreen**: מסך בחירת ספרים עם PageStorageKey לשמירת מצב גלילה וחיפוש
- **BookDetailScreen**: מסך פרטי ספר עם שמירת מצב התקדמות
- **Location**: `packages/shamor_zachor/lib/screens/`

### Integration Points

#### 1. MoreScreen Integration
```dart
// lib/navigation/more_screen.dart
Widget _buildCurrentWidget(int index) {
  switch (index) {
    case 1: // שמור וזכור
      return const ShamorZachorWidget();
    // ... other cases
  }
}
```

#### 2. Local Provider Integration
```dart
// packages/shamor_zachor/lib/shamor_zachor_widget.dart
class ShamorZachorWidget extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ShamorZachorDataProvider()),
        ChangeNotifierProvider(create: (_) => ShamorZachorProgressProvider()),
      ],
      child: ShamorZachorMainScreen(),
    );
  }
}
```

#### 3. Package Dependency & Asset Integration
```yaml
# Main pubspec.yaml
dependencies:
  shamor_zachor:
    path: ./packages/shamor_zachor

flutter:
  assets:
    - assets/shamor_zachor/data/
    - assets/shamor_zachor/images/

# packages/shamor_zachor/pubspec.yaml
name: shamor_zachor
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.5
  shared_preferences: ^2.2.0
  # ... other dependencies

flutter:
  assets:
    - assets/data/
    - assets/images/
```

## Data Models

### BookCategory Model
```dart
class BookCategory {
  final String name;
  final String contentType;
  final Map<String, BookDetails> books;
  final int defaultStartPage;
  final List<BookCategory>? subcategories;
  // ... methods
}
```

### BookDetails Model
```dart
class BookDetails {
  final String contentType;
  final List<BookPart> parts;
  final num? originalPageCount;
  // ... methods for learnable items
}
```

### Progress Model
```dart
class ProgressModel {
  final Map<String, Map<String, List<bool>>> bookProgress;
  // bookProgress[categoryName][bookName][itemIndex] = [learned, review1, review2, review3]
}
```

## Error Handling

### Data Loading Errors
- **File Not Found**: הצגת הודעת שגיאה ידידותית למשתמש
- **JSON Parse Error**: לוגינג של השגיאה והצגת הודעה כללית
- **Network Issues**: (לא רלוונטי כרגע - הכל מקומי)

### Storage Errors
- **SharedPreferences Unavailable**: שימוש בזיכרון זמני עד לפתרון הבעיה
- **Storage Full**: הצגת הודעה למשתמש על מחסור במקום
- **Permission Denied**: הצגת הודעה על בעיית הרשאות

### UI Error Handling
```dart
class ErrorBoundary extends StatelessWidget {
  final Widget child;
  final String fallbackMessage;
  
  @override
  Widget build(BuildContext context) {
    return Consumer<ShamorZachorDataProvider>(
      builder: (context, provider, child) {
        if (provider.error != null) {
          return ErrorWidget(provider.error!);
        }
        return child;
      },
    );
  }
}
```

## Testing Strategy

### Unit Tests
1. **Model Tests**:
   - BookCategory parsing from JSON
   - BookDetails calculations (learnable items, progress)
   - Progress calculations and validations

2. **Service Tests**:
   - DataLoaderService JSON loading
   - ProgressService save/load operations
   - Error handling scenarios

3. **Provider Tests**:
   - State management correctness
   - Notification behavior
   - Error state handling

### Widget Tests
1. **Screen Tests**:
   - TrackingScreen rendering with different states
   - BooksScreen search functionality
   - BookDetailScreen progress updates

2. **Integration Tests**:
   - Navigation between screens
   - Data persistence across app restarts
   - Provider state synchronization

### Test Data
- יצירת קבצי JSON מדומים לבדיקות
- מוקים של SharedPreferences
- בדיקת edge cases (ספרים ריקים, נתונים פגומים)

## Performance Considerations

### Data Loading
- **Lazy Loading**: טעינת נתונים רק כשנדרש
- **Caching**: שמירת נתונים בזיכרון לאחר טעינה ראשונה
- **Background Loading**: טעינת נתונים כבדים ברקע

### Memory Management
- **Dispose Providers**: וידוא שחרור משאבים
- **Image Caching**: שימוש ב-Flutter image cache
- **Large Lists**: שימוש ב-ListView.builder לרשימות גדולות

### Storage Optimization
```dart
class ProgressService {
  static const String _keyPrefix = 'sz:';
  
  // שמירה רק של שינויים, לא של כל הנתונים
  Future<void> saveProgressDelta(String key, dynamic value) async {
    final prefixedKey = '$_keyPrefix$key';
    // implementation
  }
  
  // דחיסת נתונים לפני שמירה
  Future<void> saveCompressedProgress(Map<String, dynamic> data) async {
    // implementation with prefixed keys
  }
  
  // מניעת התנגשות עם אחסון האפליקציה הראשית
  String _getPrefixedKey(String key) => '$_keyPrefix$key';
}
```

## Security Considerations

### Data Validation
- **Input Sanitization**: וידוא שנתוני המשתמש תקינים
- **JSON Schema Validation**: בדיקת תקינות קבצי הנתונים
- **Progress Data Integrity**: וידוא שנתוני ההתקדמות לא פגומים

### Local Storage Security
- **No Sensitive Data**: אין נתונים רגישים הנשמרים מקומית
- **Data Encryption**: (לא נדרש כרגע - נתונים לא רגישים)

## Accessibility

### RTL Support
- **Text Direction**: תמיכה מלאה בכיוון RTL
- **Layout Mirroring**: התאמת הפריסה לעברית
- **Font Support**: שימוש בפונטים תומכי עברית

### Screen Reader Support
```dart
Semantics(
  label: 'ספר ${bookName}, התקדמות: ${progress}%',
  child: BookCard(...),
)
```

### Keyboard Navigation
- **Focus Management**: ניווט נכון בין אלמנטים
- **Shortcuts**: קיצורי מקלדת למשימות נפוצות

## Deployment Strategy

### Phase 1: Core Integration
1. העתקת קבצי המודלים והשירותים
2. יצירת הווידג'ט הבסיסי
3. שילוב במסך "עוד"

### Phase 2: Full Functionality
1. שילוב כל המסכים
2. הוספת הפונקציונליות המלאה
3. בדיקות יסודיות

### Phase 3: Polish & Optimization
1. אופטימיזציה של ביצועים
2. שיפור UX
3. תיקון באגים

## Migration Considerations

### Existing Data
- **No Existing Data**: זהו פיצר חדש, אין נתונים קיימים
- **Future Migrations**: תכנון למבנה נתונים שיתמוך בשדרוגים עתידיים

### Backward Compatibility
- **API Stability**: שמירה על יציבות ממשקי הנתונים
- **Data Format**: שימוש בפורמט JSON גמיש לשינויים עתידיים

## State Preservation Strategy

### Navigation State Management
```dart
class ShamorZachorWidget extends StatefulWidget {
  @override
  State<ShamorZachorWidget> createState() => _ShamorZachorWidgetState();
}

class _ShamorZachorWidgetState extends State<ShamorZachorWidget> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
  
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ShamorZachorDataProvider()),
        ChangeNotifierProvider(create: (_) => ShamorZachorProgressProvider()),
      ],
      child: Navigator(
        key: _navigatorKey,
        initialRoute: '/',
        onGenerateRoute: _generateRoute,
      ),
    );
  }
}
```

### Screen State Preservation
```dart
class BooksScreen extends StatefulWidget {
  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
  
  final PageStorageKey _listKey = const PageStorageKey('books_list');
  final TextEditingController _searchController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Column(
      children: [
        TextField(
          controller: _searchController,
          // search implementation
        ),
        Expanded(
          child: ListView.builder(
            key: _listKey, // Preserves scroll position
            // list implementation
          ),
        ),
      ],
    );
  }
}
```

## Package Structure Details

### Internal Package pubspec.yaml
```yaml
name: shamor_zachor
description: שמור וזכור - מערכת מעקב לימוד תורני
version: 1.0.0

environment:
  sdk: ^3.5.4

dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.5
  shared_preferences: ^2.2.0
  path_provider: ^2.1.1
  uuid: ^4.5.1
  kosher_dart: ^2.0.17
  confetti: ^0.8.0

flutter:
  assets:
    - assets/data/
    - assets/images/
```

### Main Export File
```dart
// packages/shamor_zachor/lib/shamor_zachor.dart
library shamor_zachor;

export 'shamor_zachor_widget.dart';
export 'models/book_model.dart';
export 'models/progress_model.dart';
// Export only necessary public APIs
```

## Storage Key Management

### Prefixed Keys Strategy
```dart
class StorageKeys {
  static const String prefix = 'sz:';
  
  // Progress keys
  static const String bookProgress = '${prefix}book_progress';
  static const String lastAccessed = '${prefix}last_accessed';
  static const String completionDates = '${prefix}completion_dates';
  
  // Settings keys
  static const String themeMode = '${prefix}theme_mode';
  static const String defaultStartPage = '${prefix}default_start_page';
  
  // Navigation state keys
  static const String lastSelectedTab = '${prefix}last_selected_tab';
  static const String lastBookCategory = '${prefix}last_book_category';
}
```