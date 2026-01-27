import 'package:equatable/equatable.dart';

abstract class EmptyLibraryState extends Equatable {
  final bool isLoading;
  final String? selectedPath;
  final String? errorMessage;

  const EmptyLibraryState({
    this.isLoading = false,
    this.selectedPath,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [
        isLoading,
        selectedPath,
        errorMessage,
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
  });
}
