import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'gematria_search.dart';

class GematriaSearchScreen extends StatefulWidget {
  const GematriaSearchScreen({super.key});

  @override
  State<GematriaSearchScreen> createState() => _GematriaSearchScreenState();
}

class _GematriaSearchScreenState extends State<GematriaSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<GematriaSearchResult> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final searchText = _searchController.text.trim();
    if (searchText.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      // חישוב הגימטריה של הטקסט שהוזן
      final targetGimatria = GimatriaSearch.gimatria(searchText);

      // קבלת נתיב הספרייה מההגדרות
      final libraryPath = Settings.getValue<String>('key-library-path') ?? '.';

      // חיפוש בתיקיות ספציפיות בלבד: תנך/תורה, תנך/נביאים, תנך/כתובים
      final searchPaths = [
        '$libraryPath/אוצריא/תנך/תורה',
        '$libraryPath/אוצריא/תנך/נביאים',
        '$libraryPath/אוצריא/תנך/כתובים',
      ];

      final List<SearchResult> allResults = [];
      for (final path in searchPaths) {
        final results = await GimatriaSearch.searchInFiles(
          path,
          targetGimatria,
          maxPhraseWords: 8,
          fileLimit: 100,
        );
        allResults.addAll(results);
        if (allResults.length >= 100) break;
      }

      final results = allResults.take(100).toList();

      // המרת התוצאות לפורמט של המסך
      setState(() {
        _searchResults = results.map((result) {
          // חילוץ שם הקובץ
          final relativePath =
              result.file.replaceFirst(libraryPath, '').replaceAll('\\', '/');
          final fileName = relativePath.split('/').last.replaceAll('.txt', '');

          return GematriaSearchResult(
            bookTitle: fileName,
            internalPath:
                result.path.isNotEmpty ? result.path : 'שורה ${result.line}',
            preview: result.text,
            data: result,
          );
        }).toList();
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('שגיאה בחיפוש: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'חפש גימטריה...',
                hintStyle: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _performSearch,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                child: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'לא נמצאו תוצאות',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calculate_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'הזן ערך לחיפוש גימטריה',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildResultCard(index + 1, _searchResults[index]);
      },
    );
  }

  Widget _buildResultCard(int number, GematriaSearchResult result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // כאן תוסיף פעולה בלחיצה על התוצאה
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // מספר התוצאה
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // תוכן התוצאה
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // נתיב (כותרות) - אם קיים, אחרת שם הקובץ
                    Text(
                      result.internalPath.isNotEmpty
                          ? result.internalPath
                          : result.bookTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // המילים שנמצאו - בולטות
                    if (result.preview.isNotEmpty)
                      Text(
                        result.preview,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.right,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GematriaSearchResult {
  final String bookTitle;
  final String internalPath;
  final String preview;
  final dynamic data; // מידע נוסף שתרצה לשמור

  GematriaSearchResult({
    required this.bookTitle,
    required this.internalPath,
    this.preview = '',
    this.data,
  });
}
