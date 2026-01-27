import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/data/constants/database_constants.dart';
import 'package:otzaria/empty_library/bloc/empty_library_event.dart';
import 'package:otzaria/empty_library/bloc/empty_library_state.dart';
import 'package:otzaria/settings/settings_repository.dart';
import 'package:path/path.dart' as path;

class EmptyLibraryBloc extends Bloc<EmptyLibraryEvent, EmptyLibraryState> {
  EmptyLibraryBloc() : super(EmptyLibraryInitial()) {
    on<PickDirectoryRequested>(_onPickDirectoryRequested);
  }

  Future<void> _onPickDirectoryRequested(
      PickDirectoryRequested event, Emitter<EmptyLibraryState> emit) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory == null) {
      return;
    }

    emit(EmptyLibraryLoading(selectedPath: selectedDirectory));

    // בדיקה שקובץ seforim.db קיים בתיקייה שנבחרה
    // נבדוק שני מקרים:
    // 1. המשתמש בחר תיקייה שמכילה את תיקיית "אוצריא" (למשל: C:\Library שמכילה C:\Library\אוצריא\seforim.db)
    // 2. המשתמש בחר ישירות את תיקיית "אוצריא" (למשל: C:\Library\אוצריא שמכילה seforim.db)
    
    String libraryPath;
    
    // נתיב אפשרות 1: התיקייה שנבחרה מכילה את תיקיית אוצריא
    final databasePathWithOtzaria = DatabaseConstants.getDatabasePathForLibrary(selectedDirectory);
    final databaseFileWithOtzaria = File(databasePathWithOtzaria);
    
    // נתיב אפשרות 2: התיקייה שנבחרה היא תיקיית אוצריא עצמה (seforim.db ישירות בתוכה)
    final databasePathDirect = path.join(selectedDirectory, DatabaseConstants.databaseFileName);
    final databaseFileDirect = File(databasePathDirect);

    if (databaseFileWithOtzaria.existsSync()) {
      // אפשרות 1: נבחרה תיקייה שמכילה את תיקיית אוצריא
      libraryPath = selectedDirectory;
    } else if (databaseFileDirect.existsSync()) {
      // אפשרות 2: נבחרה ישירות תיקיית אוצריא - נשמור את התיקייה העליונה
      libraryPath = path.dirname(selectedDirectory);
    } else {
      emit(EmptyLibraryError(
        errorMessage: 'הקובץ ${DatabaseConstants.databaseFileName} לא נמצא.\n'
            'יש לבחור את התיקייה המכילה את תיקיית "${DatabaseConstants.otzariaFolderName}" עם הקובץ ${DatabaseConstants.databaseFileName},\n'
            'או לבחור ישירות את תיקיית "${DatabaseConstants.otzariaFolderName}".',
        selectedPath: selectedDirectory,
      ));
      return;
    }

    // שמירת הנתיב בהגדרות
    await Settings.setValue(SettingsRepository.keyLibraryPath, libraryPath);
    
    emit(EmptyLibraryDirectorySelected(selectedPath: libraryPath));
  }
}
