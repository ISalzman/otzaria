import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/data/data_providers/database_library_provider.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/library/bloc/library_bloc.dart';
import 'package:otzaria/library/bloc/library_event.dart';
import 'package:otzaria/migration/models/category.dart';
import 'package:otzaria/migration/sync/background_db_sync_worker.dart';
import 'package:otzaria/migration/sync/file_sync_service.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';
import 'package:otzaria/settings/services/custom_folders/custom_folder.dart';

part 'custom_folders_event.dart';
part 'custom_folders_state.dart';

class CustomFoldersBloc extends Bloc<CustomFoldersEvent, CustomFoldersState> {
  final LibraryBloc _libraryBloc;

  CustomFoldersBloc({required LibraryBloc libraryBloc})
      : _libraryBloc = libraryBloc,
        super(const CustomFoldersState()) {
    on<LoadCustomFolders>(_onLoad);
    on<AddCustomFolder>(_onAdd);
    on<RemoveCustomFolder>(_onRemove);
    on<ToggleAddToDatabase>(_onToggleAddToDatabase);
    on<RescanCustomFolders>(_onRescan);
  }

  void _onLoad(LoadCustomFolders event, Emitter<CustomFoldersState> emit) {
    final jsonString =
        Settings.getValue<String>(SettingsRepository.keyCustomFolders);
    emit(state.copyWith(folders: CustomFoldersManager.loadFolders(jsonString)));
  }

  Future<void> _onAdd(
      AddCustomFolder event, Emitter<CustomFoldersState> emit) async {
    final newFolders =
        CustomFoldersManager.addFolder(state.folders, event.path);
    await _saveFolders(newFolders);
    emit(state.copyWith(folders: newFolders, isSyncing: true, message: null, error: null));

    try {
      final sqliteProvider = SqliteDataProvider.instance;
      if (!sqliteProvider.isInitialized) await sqliteProvider.initialize();
      final repository = sqliteProvider.repository;
      if (repository == null) {
        emit(state.copyWith(isSyncing: false, error: 'מסד הנתונים לא זמין'));
        return;
      }
      final folderName = event.path.split(RegExp(r'[/\\]')).last;
      final result = await DatabaseLibraryProvider.instance
          .scanAndAddExternalBooksFromFolder(event.path, folderName, repository);

      if (result.isSuccess) {
        _libraryBloc.add(RefreshLibrary());
        if (result.hasPartialFailure) {
          emit(state.copyWith(
            isSyncing: false,
            error:
                '${result.addedBooks} ספרים נוספו, ${result.updatedBooks} עודכנו (כשל: ${result.failedBooks})',
          ));
        } else {
          emit(state.copyWith(isSyncing: false));
        }
      } else {
        emit(state.copyWith(
            isSyncing: false, error: 'שגיאת סריקה: ${result.fatalError}'));
      }
    } catch (e) {
      emit(state.copyWith(isSyncing: false, error: 'שגיאה בסריקת התיקייה: $e'));
    }
  }

  Future<void> _onRemove(
      RemoveCustomFolder event, Emitter<CustomFoldersState> emit) async {
    final newFolders =
        CustomFoldersManager.removeFolder(state.folders, event.folder.path);
    await _saveFolders(newFolders);
    emit(state.copyWith(folders: newFolders, message: null, error: null));

    if (event.deleteFromDb) {
      emit(state.copyWith(isSyncing: true, message: null, error: null));
      await _deleteFromDatabase(event.folder);
      emit(state.copyWith(
        isSyncing: false,
        message: 'התיקייה והספרים נמחקו ממסד הנתונים.',
      ));
    } else {
      emit(state.copyWith(
        message: 'התיקייה הוסרה. הספרים נשארו במסד הנתונים.',
      ));
    }
    _libraryBloc.add(RefreshLibrary());
  }

  Future<void> _onToggleAddToDatabase(
      ToggleAddToDatabase event, Emitter<CustomFoldersState> emit) async {
    final newFolders = CustomFoldersManager.updateFolderDbSetting(
        state.folders, event.folder.path, event.value);
    await _saveFolders(newFolders);
    emit(state.copyWith(folders: newFolders, isSyncing: true, message: null, error: null));

    try {
      final result = await _runSync(newFolders);
      if (!event.value) {
        emit(state.copyWith(
          isSyncing: false,
          message: 'תוכן הספרים נסרק ועודכן.\nמעתה הספרים ייקראו ישירות מהקבצים.',
        ));
      } else {
        final hasChanges =
            result.addedBooks > 0 || result.updatedBooks > 0;
        emit(state.copyWith(
          isSyncing: false,
          message: hasChanges
              ? 'הסריקה הושלמה: ${result.addedBooks} ספרים נוספו, ${result.updatedBooks} עודכנו'
              : null,
        ));
      }
      _libraryBloc.add(RefreshLibrary());
    } catch (e) {
      emit(state.copyWith(isSyncing: false, error: 'שגיאה בסנכרון: $e'));
    }
  }

  Future<void> _onRescan(
      RescanCustomFolders event, Emitter<CustomFoldersState> emit) async {
    emit(state.copyWith(isSyncing: true, message: null, error: null));
    try {
      final result = await _runSync(state.folders);
      final hasChanges = result.addedBooks > 0 || result.updatedBooks > 0;
      final message = hasChanges
          ? 'הסריקה הושלמה: ${result.addedBooks} ספרים נוספו, ${result.updatedBooks} עודכנו'
          : event.showNoChangesMessage
              ? 'הסריקה הושלמה. לא נמצאו ספרים חדשים.'
              : null;
      emit(state.copyWith(isSyncing: false, message: message));
      _libraryBloc.add(RefreshLibrary());
    } catch (e) {
      emit(state.copyWith(
          isSyncing: false, error: 'שגיאה בסריקת תיקיות אישיות: $e'));
    }
  }

  Future<FileSyncResult> _runSync(List<CustomFolder> folders) async {
    final sqliteProvider = SqliteDataProvider.instance;
    if (!sqliteProvider.isInitialized) await sqliteProvider.initialize();
    if (!sqliteProvider.isInitialized) throw Exception('מסד הנתונים לא זמין');

    final dbPath = sqliteProvider.dbPath;
    final libraryPath = Settings.getValue<String>('key-library-path');
    if (libraryPath == null || libraryPath.isEmpty) {
      throw Exception('נתיב הספרייה לא מוגדר');
    }

    final folderName =
        Settings.getValue<String>(SettingsRepository.keyLibraryFolderName) ??
            '';
    final result = await runCustomFoldersDbSyncInIsolate(
      dbPath: dbPath,
      libraryPath: libraryPath,
      customFolders: folders,
      folderName: folderName,
    );
    await FileSyncService.saveCustomFoldersSignature(folders);
    return result;
  }

  Future<void> _deleteFromDatabase(CustomFolder folder) async {
    final sqliteProvider = SqliteDataProvider.instance;
    if (!sqliteProvider.isInitialized) await sqliteProvider.initialize();
    final repository = sqliteProvider.repository;
    if (repository == null) return;

    final rootCategories = await repository.getRootCategories();
    Category? personalCategory;
    for (final cat in rootCategories) {
      if (cat.title == 'ספרים אישיים') {
        personalCategory = cat;
        break;
      }
    }
    if (personalCategory == null) return;

    final folderCategories =
        await repository.getCategoryChildren(personalCategory.id);
    Category? folderCategory;
    for (final cat in folderCategories) {
      if (cat.title == folder.name) {
        folderCategory = cat;
        break;
      }
    }
    if (folderCategory == null) return;

    await runDeleteFolderFromDbInIsolate(
      dbPath: sqliteProvider.dbPath,
      folderCategoryId: folderCategory.id,
      personalCategoryId: personalCategory.id,
    );
  }

  Future<void> _saveFolders(List<CustomFolder> folders) async {
    await Settings.setValue(
      SettingsRepository.keyCustomFolders,
      CustomFoldersManager.saveFolders(folders),
    );
  }
}
