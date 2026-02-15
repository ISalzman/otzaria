import 'package:equatable/equatable.dart';

abstract class EmptyLibraryState extends Equatable {
  final bool isLoading;
  final String? selectedPath;
  final String? errorMessage;
  final List<String>? zipFiles;

  const EmptyLibraryState({
    this.isLoading = false,
    this.selectedPath,
    this.errorMessage,
    this.zipFiles,
  });

  @override
  List<Object?> get props => [
        isLoading,
        selectedPath,
        errorMessage,
        zipFiles,
      ];
}

class EmptyLibraryInitial extends EmptyLibraryState {}

class EmptyLibraryLoading extends EmptyLibraryState {
  const EmptyLibraryLoading({
    super.selectedPath,
  }) : super(isLoading: true);
}

class EmptyLibraryDirectorySelected extends EmptyLibraryState {
  const EmptyLibraryDirectorySelected({
    required String selectedPath,
  }) : super(selectedPath: selectedPath);
}

class EmptyLibraryError extends EmptyLibraryState {
  const EmptyLibraryError({
    super.errorMessage,
    super.selectedPath,
    super.zipFiles,
  });
}

class EmptyLibraryZipExtracted extends EmptyLibraryState {
  final String extractedFileName;

  const EmptyLibraryZipExtracted({
    required String selectedPath,
    required this.extractedFileName,
  }) : super(selectedPath: selectedPath);

  @override
  List<Object?> get props => [
        ...super.props,
        extractedFileName,
      ];
}

class EmptyLibraryExtracting extends EmptyLibraryState {
  final double progress;
  final String message;

  const EmptyLibraryExtracting({
    required String selectedPath,
    required this.progress,
    required this.message,
  }) : super(selectedPath: selectedPath, isLoading: true);

  @override
  List<Object?> get props => [
        ...super.props,
        progress,
        message,
      ];
}

class EmptyLibraryDownloading extends EmptyLibraryState {
  final double progress;
  final String message;

  const EmptyLibraryDownloading({
    required this.progress,
    required this.message,
  }) : super(isLoading: true);

  @override
  List<Object?> get props => [
        ...super.props,
        progress,
        message,
      ];
}

class EmptyLibraryAskingDeleteZip extends EmptyLibraryState {
  final String zipPath;
  final String extractedPath;

  const EmptyLibraryAskingDeleteZip({
    required this.zipPath,
    required this.extractedPath,
  }) : super(isLoading: true);

  @override
  List<Object?> get props => [
        ...super.props,
        zipPath,
        extractedPath,
      ];
}
