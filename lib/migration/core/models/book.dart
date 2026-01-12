import 'package:collection/collection.dart';
import 'package:otzaria/migration/core/extentions/types_helper.dart';

import 'author.dart';
import 'pub_date.dart';
import 'pub_place.dart';
import 'topic.dart';

/// Represents a book in the library
class Book {
  /// The unique identifier of the book
  final int id;

  /// The identifier of the category this book belongs to
  final int categoryId;

  /// The identifier of the source this book originates from
  final int sourceId;

  /// The title of the book
  final String title;

  /// The list of authors of this book
  final List<Author> authors;

  /// The list of topics associated with this book
  final List<Topic> topics;

  /// The list of publication places for this book
  final List<PubPlace> pubPlaces;

  /// The list of publication dates for this book
  final List<PubDate> pubDates;

  /// A short description of the book in Hebrew
  final String? heShortDesc;

  /// Optional notes content: when a companion file named "הערות על <title>" exists,
  /// its content is attached here instead of being inserted as a separate book.
  final String? notesContent;

  /// The display order of the book within its category
  final double order;

  /// The total number of lines in the book
  final int totalLines;

  final bool isBaseBook;
  final bool hasTargumConnection;
  final bool hasReferenceConnection;
  final bool hasCommentaryConnection;
  final bool hasOtherConnection;

  /// Whether this book is external (file-based, metadata only in DB)
  final bool isExternal;

  /// File path for external books (null for internal books)
  final String? filePath;

  /// File type for external books (pdf, txt, docx, etc.)
  final String? fileType;

  /// File size in bytes for external books
  final int? fileSize;

  /// Last modified timestamp for external books (milliseconds since epoch)
  final int? lastModified;

  /// Optional external ID for books from external sources
  final String? externalId;

  const Book({
    this.id = 0,
    required this.categoryId,
    required this.sourceId,
    required this.title,
    this.authors = const [],
    this.topics = const [],
    this.pubPlaces = const [],
    this.pubDates = const [],
    this.heShortDesc,
    this.notesContent,
    this.order = 999.0,
    this.totalLines = 0,
    this.isBaseBook = false,
    this.hasTargumConnection = false,
    this.hasReferenceConnection = false,
    this.hasCommentaryConnection = false,
    this.hasOtherConnection = false,
    this.isExternal = false,
    this.filePath,
    this.fileType,
    this.fileSize,
    this.lastModified,
    this.externalId,
  });

  Book copyWith({
    int? id,
    int? categoryId,
    int? sourceId,
    String? title,
    List<Author>? authors,
    List<Topic>? topics,
    List<PubPlace>? pubPlaces,
    List<PubDate>? pubDates,
    String? heShortDesc,
    String? notesContent,
    double? order,
    int? totalLines,
    bool? isBaseBook,
    bool? hasTargumConnection,
    bool? hasReferenceConnection,
    bool? hasCommentaryConnection,
    bool? hasOtherConnection,
    bool? isExternal,
    String? filePath,
    String? fileType,
    int? fileSize,
    int? lastModified,
    String? externalId,
  }) {
    return Book(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      topics: topics ?? this.topics,
      pubPlaces: pubPlaces ?? this.pubPlaces,
      pubDates: pubDates ?? this.pubDates,
      heShortDesc: heShortDesc ?? this.heShortDesc,
      notesContent: notesContent ?? this.notesContent,
      order: order ?? this.order,
      totalLines: totalLines ?? this.totalLines,
      isBaseBook: isBaseBook ?? this.isBaseBook,
      hasTargumConnection: hasTargumConnection ?? this.hasTargumConnection,
      hasReferenceConnection:
          hasReferenceConnection ?? this.hasReferenceConnection,
      hasCommentaryConnection:
          hasCommentaryConnection ?? this.hasCommentaryConnection,
      hasOtherConnection: hasOtherConnection ?? this.hasOtherConnection,
      isExternal: isExternal ?? this.isExternal,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      lastModified: lastModified ?? this.lastModified,
      externalId: externalId ?? this.externalId,
    );
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as int? ?? 0,
      categoryId: json['categoryId'] as int,
      sourceId: json['sourceId'] as int,
      title: json['title'] as String,
      authors: (json['authors'] as List<dynamic>?)
              ?.map((e) => Author.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      topics: (json['topics'] as List<dynamic>?)
              ?.map((e) => Topic.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pubPlaces: (json['pubPlaces'] as List<dynamic>?)
              ?.map((e) => PubPlace.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pubDates: (json['pubDates'] as List<dynamic>?)
              ?.map((e) => PubDate.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      heShortDesc: json['heShortDesc'] as String?,
      notesContent: json['notesContent'] as String?,
      order: (json['orderIndex'] as num?)?.toDouble() ??
          (json['order'] as num?)?.toDouble() ??
          999.0,
      totalLines: json['totalLines'] as int? ?? 0,
      isBaseBook: safeBoolFromJson(json['isBaseBook'], false),
      hasTargumConnection: safeBoolFromJson(json['hasTargumConnection'], false),
      hasReferenceConnection:
          safeBoolFromJson(json['hasReferenceConnection'], false),
      hasCommentaryConnection:
          safeBoolFromJson(json['hasCommentaryConnection'], false),
      hasOtherConnection: safeBoolFromJson(json['hasOtherConnection'], false),
      isExternal: safeBoolFromJson(json['isExternal'], false),
      filePath: json['filePath'] as String?,
      fileType: json['fileType'] as String?,
      fileSize: json['fileSize'] as int?,
      lastModified: json['lastModified'] as int?,
      externalId: json['externalId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'sourceId': sourceId,
      'title': title,
      'authors': authors.map((e) => e.toJson()).toList(),
      'topics': topics.map((e) => e.toJson()).toList(),
      'pubPlaces': pubPlaces.map((e) => e.toJson()).toList(),
      'pubDates': pubDates.map((e) => e.toJson()).toList(),
      'heShortDesc': heShortDesc,
      'notesContent': notesContent,
      'order': order,
      'totalLines': totalLines,
      'isBaseBook': isBaseBook,
      'hasTargumConnection': hasTargumConnection,
      'hasReferenceConnection': hasReferenceConnection,
      'hasCommentaryConnection': hasCommentaryConnection,
      'hasOtherConnection': hasOtherConnection,
      'isExternal': isExternal,
      'filePath': filePath,
      'fileType': fileType,
      'fileSize': fileSize,
      'lastModified': lastModified,
      'externalId': externalId,
    };
  }

  @override
  String toString() =>
      'Book(id: $id, title: $title, isExternal: $isExternal, externalId: $externalId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Book &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          categoryId == other.categoryId &&
          sourceId == other.sourceId &&
          title == other.title &&
          const ListEquality().equals(authors, other.authors) &&
          const ListEquality().equals(topics, other.topics) &&
          const ListEquality().equals(pubPlaces, other.pubPlaces) &&
          const ListEquality().equals(pubDates, other.pubDates) &&
          heShortDesc == other.heShortDesc &&
          notesContent == other.notesContent &&
          order == other.order &&
          totalLines == other.totalLines &&
          isBaseBook == other.isBaseBook &&
          hasTargumConnection == other.hasTargumConnection &&
          hasReferenceConnection == other.hasReferenceConnection &&
          hasCommentaryConnection == other.hasCommentaryConnection &&
          hasOtherConnection == other.hasOtherConnection &&
          isExternal == other.isExternal &&
          filePath == other.filePath &&
          fileType == other.fileType &&
          fileSize == other.fileSize &&
          lastModified == other.lastModified &&
          externalId == other.externalId;

  @override
  int get hashCode =>
      id.hashCode ^
      categoryId.hashCode ^
      sourceId.hashCode ^
      title.hashCode ^
      const ListEquality().hash(authors) ^
      const ListEquality().hash(topics) ^
      const ListEquality().hash(pubPlaces) ^
      const ListEquality().hash(pubDates) ^
      heShortDesc.hashCode ^
      notesContent.hashCode ^
      order.hashCode ^
      totalLines.hashCode ^
      isBaseBook.hashCode ^
      hasTargumConnection.hashCode ^
      hasReferenceConnection.hashCode ^
      hasCommentaryConnection.hashCode ^
      hasOtherConnection.hashCode ^
      isExternal.hashCode ^
      filePath.hashCode ^
      fileType.hashCode ^
      fileSize.hashCode ^
      lastModified.hashCode ^
      externalId.hashCode;
}
