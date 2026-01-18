import 'package:otzaria/models/books.dart'; // Import Book model
import 'package:equatable/equatable.dart';
import 'package:otzaria/find_ref/db_reference_result.dart';

abstract class FindRefState extends Equatable {
  const FindRefState();

  @override
  List<Object> get props => [];
}

class FindRefInitial extends FindRefState {}

class FindRefLoading extends FindRefState {}

class FindRefSuccess extends FindRefState {
  final List<DbReferenceResult> refs;
  const FindRefSuccess(this.refs);

  @override
  List<Object> get props => [refs];
}

class FindRefError extends FindRefState {
  final String message;
  const FindRefError(this.message);

  @override
  List<Object> get props => [message];
}

class FindRefBookOpening extends FindRefState {
  final Book book;
  final int index;

  const FindRefBookOpening({required this.book, required this.index});

  @override
  List<Object> get props => [book, index];
}
