import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart';
import '../migration/core/models/generation_progress.dart';
import '../migration/dao/daos/database.dart';
import '../migration/dao/repository/seforim_repository.dart';
import '../migration/generator/progress_generator.dart';
import '../data/constants/database_constants.dart';
import '../core/app_paths.dart';

enum DuplicateBookStrategy {
  skip,
  replace,
  ask,
}

class DatabaseGenerationScreen extends StatefulWidget {
  const DatabaseGenerationScreen({super.key});

  @override
  State<DatabaseGenerationScreen> createState() =>
      _DatabaseGenerationScreenState();
}

class _DatabaseGenerationScreenState extends State<DatabaseGenerationScreen> {
  final _logger = Logger('DatabaseGenerationScreen');
  GenerationProgress _progress = GenerationProgress.initial();
  StreamSubscription<GenerationProgress>? _progressSubscription;
  ProgressDatabaseGenerator? _generator;
  DateTime? _startTime;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  String? _selectedLibraryPath;
  String? _selectedDbPath;
  final DuplicateBookStrategy _duplicateStrategy =
      DuplicateBookStrategy.replace; // Always replace duplicates

  // File validation status
  bool _dbFileExists = false;
  bool _dbFileExistsAtTarget =
      false; // DB file at target location (blocks generation)
  bool _otzariaFolderExists = false; // Otzaria folder exists
  bool _priorityFileExists = false;
  bool _acronymFileExists = false;
  bool _linksDirectoryExists = false;
  final List<Map<String, String>> _duplicateBooks =
      []; // Store book info with path
  final Map<String, String> _duplicateReasons = {};

  @override
  void initState() {
    super.initState();
    _loadDefaultLibraryPath();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _timer?.cancel();
    _generator?.dispose();
    super.dispose();
  }

  /// Load the default library path from settings and auto-select it
  Future<void> _loadDefaultLibraryPath() async {
    try {
      final libraryPath = await AppPaths.getLibraryPath();
      final dbPath = '$libraryPath/${DatabaseConstants.databaseFileName}';

      setState(() {
        _selectedLibraryPath = libraryPath;
        _selectedDbPath = dbPath;
      });

      // Check file status immediately after loading the path
      await _checkFileStatus();

      _logger.info('Auto-loaded library path: $libraryPath');
    } catch (e, stackTrace) {
      _logger.warning('Error loading default library path', e, stackTrace);
      // If no default path, still check file status to show "select path" message
      await _checkFileStatus();
    }
  }

  void _resetToInitialState() {
    setState(() {
      _progress = GenerationProgress.initial();
      _progressSubscription?.cancel();
      _progressSubscription = null;
      _timer?.cancel();
      _timer = null;
      _generator?.dispose();
      _generator = null;
      _startTime = null;
      _elapsed = Duration.zero;
    });
  }

  Future<void> _selectLibraryFolder() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'בחר תיקיית אוצריא (תיקיית האב)',
      );

      if (selectedDirectory != null) {
        _logger.info('Selected library folder: $selectedDirectory');

        // Verify that the selected directory contains the required structure
        final otzariaDir = Directory(
            '$selectedDirectory/${DatabaseConstants.otzariaFolderName}');

        if (!await otzariaDir.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'התיקייה "${DatabaseConstants.otzariaFolderName}" לא נמצאה בתיקייה שנבחרה'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Auto-set DB path to database file in the selected folder
        final dbPath =
            '$selectedDirectory/${DatabaseConstants.databaseFileName}';

        setState(() {
          _selectedLibraryPath = selectedDirectory;
          _selectedDbPath = dbPath;
        });

        // Check file status after setting paths
        await _checkFileStatus();

        _logger.info('Auto-set database path: $dbPath');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error selecting library folder', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בבחירת תיקייה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Check the status of required files and directories
  Future<void> _checkFileStatus() async {
    if (_selectedLibraryPath == null) return;

    try {
      // Check if Otzaria folder exists
      final otzariaDir = Directory(
          '$_selectedLibraryPath/${DatabaseConstants.otzariaFolderName}');
      _otzariaFolderExists = await otzariaDir.exists();
      _logger.info(
          'Checking Otzaria folder: ${otzariaDir.path} - exists: $_otzariaFolderExists');

      // Check if DB file exists at target location (blocks generation)
      if (_selectedDbPath != null) {
        final dbFileAtTarget = File(_selectedDbPath!);
        _dbFileExistsAtTarget = await dbFileAtTarget.exists();
        _logger.info(
            'Checking DB file at target: $_selectedDbPath - exists: $_dbFileExistsAtTarget');
      }

      // Check if DB file exists in Otzaria directory
      final dbFileInOtzaria = File(
          '$_selectedLibraryPath/${DatabaseConstants.otzariaFolderName}/${DatabaseConstants.databaseFileName}');
      _dbFileExists = await dbFileInOtzaria.exists();
      _logger.info(
          'Checking DB file: ${dbFileInOtzaria.path} - exists: $_dbFileExists');

      // Check priority file in "About Software" directory
      _priorityFileExists = false;
      _acronymFileExists = false;

      final aboutSoftwareDirHeb = Directory(
          '$_selectedLibraryPath/${DatabaseConstants.otzariaFolderName}/אודות התוכנה');

      if (await aboutSoftwareDirHeb.exists()) {
        final priorityFile = File('${aboutSoftwareDirHeb.path}/priority');
        _priorityFileExists = await priorityFile.exists();
        _logger.info(
            'Checking priority file (Hebrew): ${priorityFile.path} - exists: $_priorityFileExists');

        final acronymFile = File('${aboutSoftwareDirHeb.path}/acronym.json');
        _acronymFileExists = await acronymFile.exists();
        _logger.info(
            'Checking acronym file (Hebrew): ${acronymFile.path} - exists: $_acronymFileExists');
      } else {
        _logger.info(
            'About Software directory not found in either Hebrew or English');
      }

      // Check links directory
      final linksDir = Directory('$_selectedLibraryPath/links');
      _linksDirectoryExists = await linksDir.exists();
      _logger.info(
          'Checking links directory: ${linksDir.path} - exists: $_linksDirectoryExists');

      setState(() {});
    } catch (e, stackTrace) {
      _logger.warning('Error checking file status', e, stackTrace);
    }
  }

  // Removed - DB path is now auto-set based on library folder

  /// Backup existing database file if it exists
  Future<void> _backupExistingDatabase() async {
    if (_selectedLibraryPath == null) return;

    final dbFileInOtzaria = File(
        '$_selectedLibraryPath/${DatabaseConstants.otzariaFolderName}/${DatabaseConstants.databaseFileName}');
    if (await dbFileInOtzaria.exists()) {
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final backupPath = '${dbFileInOtzaria.path}.backup_$timestamp';
        await dbFileInOtzaria.copy(backupPath);
        _logger.info('Database backed up to: $backupPath');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'מסד הנתונים הקיים גובה ל: ${backupPath.split('/').last}'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e, stackTrace) {
        _logger.warning('Failed to backup existing database', e, stackTrace);
      }
    }
  }

  Future<void> _startGeneration() async {
    if (_selectedLibraryPath == null || _selectedDbPath == null) {
      _logger.warning(
          'Cannot start generation: missing library path or database path');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('יש לבחור תיקיית אוצריא (תיקיית האב)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _logger.info('Starting database generation');
    _logger.info('Library path: $_selectedLibraryPath');
    _logger.info('Database path: $_selectedDbPath');
    _logger.info('Duplicate strategy: $_duplicateStrategy');

    // Backup existing database if it exists
    await _backupExistingDatabase();

    setState(() {
      _progress = GenerationProgress(
        phase: GenerationPhase.initializing,
        message: 'מתחיל...',
      );
      _startTime = DateTime.now();
      _elapsed = Duration.zero;
      _duplicateBooks.clear();
      _duplicateReasons.clear();
    });

    // Start timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime!);
        });
      }
    });

    try {
      MyDatabase.initialize();
      final database = MyDatabase.withPath(_selectedDbPath!);
      final repository = SeforimRepository(database);
      await repository.ensureInitialized();

      // Always replace duplicates and track them
      Future<bool> duplicateCallback(String title) async {
        // Try to extract path information from the title or use a generic path
        final bookInfo = {
          'title': title,
          'path': 'נתיב לא זמין', // We'll improve this later if needed
          'reason': 'ספר קיים הוחלף'
        };
        _duplicateBooks.add(bookInfo);
        _duplicateReasons[title] = 'ספר קיים הוחלף';
        return true; // Always replace
      }

      _generator = ProgressDatabaseGenerator(
        _selectedLibraryPath!,
        repository,
        onDuplicateBook: duplicateCallback,
        createIndexes: true, // Always create indexes
      );

      _progressSubscription = _generator!.progressStream.listen(
        (progress) {
          setState(() {
            _progress = progress;
          });
        },
        onError: (error) {
          final errorMsg = error.toString();
          _logger.severe('Error during generation: $errorMsg');
          setState(() {
            _progress = GenerationProgress.error(errorMsg);
          });
        },
      );

      await _generator!.generate();
      await repository.close();

      _timer?.cancel();

      // Show duplicate books report if any were found
      if (_duplicateBooks.isNotEmpty) {
        _showDuplicateReport();
      }
    } catch (e, stackTrace) {
      final errorMsg = e.toString();
      _logger.severe('Error during generation: $errorMsg', e, stackTrace);
      setState(() {
        _progress = GenerationProgress.error(errorMsg);
      });
      _timer?.cancel();
    }
  }

  /// Show report of duplicate books that were replaced
  void _showDuplicateReport() {
    // Create report text for copying
    final reportText = StringBuffer();
    reportText
        .writeln('דוח ספרים כפולים - ${_duplicateBooks.length} ספרים הוחלפו:');
    reportText.writeln('=' * 50);

    for (int i = 0; i < _duplicateBooks.length; i++) {
      final bookInfo = _duplicateBooks[i];
      final title = bookInfo['title'] ?? 'לא ידוע';
      final path = bookInfo['path'] ?? 'נתיב לא זמין';
      final reason = bookInfo['reason'] ?? 'לא ידוע';

      reportText.writeln('${i + 1}. $title');
      reportText.writeln('   נתיב: $path');
      reportText.writeln('   סיבה: $reason');
      reportText.writeln();
    }

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.library_books, color: Colors.orange),
              const SizedBox(width: 8),
              const Expanded(child: Text('דוח ספרים כפולים')),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: reportText.toString()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('הדוח הועתק ללוח'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
                tooltip: 'העתק דוח',
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'נמצאו ${_duplicateBooks.length} ספרים כפולים שהוחלפו במהלך יצירת מסד הנתונים',
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: _duplicateBooks.length,
                    itemBuilder: (context, index) {
                      final bookInfo = _duplicateBooks[index];
                      final title = bookInfo['title'] ?? 'לא ידוע';
                      final path = bookInfo['path'] ?? 'נתיב לא זמין';
                      final reason = bookInfo['reason'] ?? 'לא ידוע';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.orange[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange[800],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.folder_outlined,
                                      size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'נתיב: $path',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    reason,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: reportText.toString()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('הדוח הועתק ללוח'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('העתק דוח'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('סגור'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('יצירת מסד נתונים'),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Configuration section
                if (_progress.phase == GenerationPhase.idle) ...[
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'הגדרות',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),

                          // Library folder selection
                          _buildPathSelector(
                            label: 'תיקיית אוצריא (תיקיית האב)',
                            path: _selectedLibraryPath,
                            onTap: _selectLibraryFolder,
                            icon: Icons.folder_open,
                          ),

                          const SizedBox(height: 8),

                          // Database path display (read-only)
                          if (_selectedDbPath != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.blue[700], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'מסד הנתונים: $_selectedDbPath',
                                      style: TextStyle(
                                        color: Colors.blue[900],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // File status section - always show
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),

                          Text(
                            'בדיקת קבצים נדרשים',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),

                          if (_selectedLibraryPath != null) ...[
                            // Check if DB file already exists at target - blocks generation
                            if (_dbFileExistsAtTarget)
                              _buildBlockingStatusItem(
                                'קובץ מסד נתונים קיים',
                                'קובץ DB כבר קיים במיקום היעד - לא ניתן ליצור מסד נתונים נוסף',
                              ),
                            // Check if Otzaria folder exists
                            _buildFileStatusItem(
                              'תיקיית אוצריא',
                              _otzariaFolderExists,
                              _otzariaFolderExists
                                  ? 'קיימת'
                                  : 'לא קיימת - נדרשת ליצירת מסד הנתונים',
                            ),
                            _buildDbStatusItem(
                              'קובץ מסד נתונים (אוצריא)',
                              _dbFileExists,
                              _dbFileExists
                                  ? 'קיים - הקובץ הישן יגובה ויווצר קובץ חדש'
                                  : 'לא קיים - יווצר קובץ חדש',
                            ),
                            _buildFileStatusItem(
                              'קובץ priority (אודות התוכנה)',
                              _priorityFileExists,
                              _priorityFileExists ? 'קיים' : 'לא קיים',
                            ),
                            _buildFileStatusItem(
                              'קובץ acronym.json (אודות התוכנה)',
                              _acronymFileExists,
                              _acronymFileExists ? 'קיים' : 'לא קיים',
                            ),
                            _buildFileStatusItem(
                              'תיקיית links',
                              _linksDirectoryExists,
                              _linksDirectoryExists
                                  ? 'קיימת - יווצרו קישורים'
                                  : 'לא קיימת - לא ייווצרו קישורים',
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber,
                                      color: Colors.orange[700], size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'יש לבחור תיקיית אוצריא כדי לבדוק את סטטוס הקבצים הנדרשים',
                                      style: TextStyle(
                                        color: Colors.orange[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Status Card
                if (_progress.phase != GenerationPhase.idle)
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          // Phase indicator
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _progress.phase.emoji,
                                style: const TextStyle(fontSize: 48),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                _progress.phase.displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Progress bar
                          if (_progress.phase != GenerationPhase.error)
                            Column(
                              children: [
                                LinearProgressIndicator(
                                  value: _progress.progress,
                                  minHeight: 8,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _progress.isComplete
                                        ? Colors.green
                                        : Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${(_progress.progress * 100).toStringAsFixed(1)}%',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),

                          const SizedBox(height: 16),

                          // Current message
                          Text(
                            _progress.message,
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),

                          // Current book
                          if (_progress.currentBook.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'ספר נוכחי: ${_progress.currentBook}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],

                          // Elapsed time
                          if (_startTime != null && !_progress.isComplete) ...[
                            const SizedBox(height: 8),
                            Text(
                              'זמן שעבר: ${_formatDuration(_elapsed)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Statistics Cards
                if (_progress.totalBooks > 0 || _progress.totalLinks > 0)
                  Row(
                    children: [
                      // Books card
                      if (_progress.totalBooks > 0)
                        Expanded(
                          child: _StatCard(
                            icon: Icons.book,
                            title: 'ספרים',
                            current: _progress.processedBooks,
                            total: _progress.totalBooks,
                            color: Colors.blue,
                          ),
                        ),

                      if (_progress.totalBooks > 0 && _progress.totalLinks > 0)
                        const SizedBox(width: 16),

                      // Links card
                      if (_progress.totalLinks > 0)
                        Expanded(
                          child: _StatCard(
                            icon: Icons.link,
                            title: 'קישורים',
                            current: _progress.processedLinks,
                            total: _progress.totalLinks,
                            color: Colors.green,
                          ),
                        ),
                    ],
                  ),

                const SizedBox(height: 24),

                // Error message
                if (_progress.error != null)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                constraints:
                                    const BoxConstraints(maxHeight: 120),
                                child: SingleChildScrollView(
                                  child: SelectableText(
                                    _progress.error!,
                                    style: TextStyle(color: Colors.red[700]),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: _progress.error!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('השגיאה הועתקה ללוח'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('העתק שגיאה'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_progress.error != null) const SizedBox(height: 16),

                // Action buttons
                if (_progress.error != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _resetToInitialState,
                          icon: const Icon(Icons.refresh),
                          label: const Text('חזור להתחלה'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _startGeneration,
                          icon: const Icon(Icons.replay),
                          label: const Text('נסה שוב'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else
                  ElevatedButton(
                    onPressed: (_progress.phase == GenerationPhase.idle ||
                                _progress.phase == GenerationPhase.complete) &&
                            !_dbFileExistsAtTarget &&
                            _otzariaFolderExists
                        ? _startGeneration
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor:
                          _progress.isComplete ? Colors.green : Colors.blue,
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: Text(
                      _getButtonText(),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),

                const SizedBox(height: 16),

                // Info text
                if (_progress.phase == GenerationPhase.idle)
                  Text(
                    'בחר את תיקיית האב של אוצריא (שמכילה את התיקיות "אוצריא" ו-"links").\n'
                    'מסד הנתונים ייווצר אוטומטית בתיקייה זו (${DatabaseConstants.databaseFileName}).\n'
                    'אינדקסים ייווצרו תמיד לשיפור ביצועי החיפוש.\n'
                    'ספרים כפולים יוחלפו תמיד ויוצג דוח לאחר היצירה.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),

                if (_progress.isComplete && _progress.error == null)
                  Text(
                    'מסד הנתונים נוצר בהצלחה!\n'
                    'זמן כולל: ${_formatDuration(_elapsed)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDbStatusItem(String label, bool exists, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.storage,
            color: Colors.blue,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileStatusItem(String label, bool exists, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            exists ? Icons.check_circle : Icons.cancel,
            color: exists ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockingStatusItem(String label, String description) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[300]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.block,
            color: Colors.red[700],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPathSelector({
    required String label,
    required String? path,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    path ?? 'לחץ לבחירה...',
                    style: TextStyle(
                      color: path != null ? Colors.black87 : Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_back_ios, size: 16, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getButtonText() {
    if (_dbFileExistsAtTarget) {
      return 'לא ניתן ליצור - קובץ DB כבר קיים';
    } else if (!_otzariaFolderExists && _selectedLibraryPath != null) {
      return 'לא ניתן ליצור - תיקיית אוצריא לא קיימת';
    } else if (_progress.phase == GenerationPhase.idle) {
      return 'התחל יצירת מסד נתונים';
    } else if (_progress.isComplete && _progress.error == null) {
      return 'הושלם בהצלחה ✓';
    } else {
      return 'מעבד...';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final int current;
  final int total;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.current,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage =
        total > 0 ? (current / total * 100).toStringAsFixed(0) : '0';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '$current / $total',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '$percentage%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
