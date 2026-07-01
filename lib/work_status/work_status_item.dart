import 'package:flutter/foundation.dart';

enum WorkStatusKind { running, failed, cancelled }

class WorkStatusItem {
  final String id;
  final String title;
  final String message;
  final String? detail;
  final double? progress;
  final WorkStatusKind kind;

  /// פעולה בלחיצה על החיווי. פריט ללא ערך אינו לחיץ.
  final VoidCallback? onTap;

  const WorkStatusItem({
    required this.id,
    required this.title,
    required this.message,
    this.detail,
    this.progress,
    this.kind = WorkStatusKind.running,
    this.onTap,
  });

  WorkStatusItem copyWith({
    String? id,
    String? title,
    String? message,
    String? detail,
    Object? progress = _sentinel,
    WorkStatusKind? kind,
    Object? onTap = _sentinel,
  }) {
    return WorkStatusItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      detail: detail ?? this.detail,
      progress: progress == _sentinel ? this.progress : progress as double?,
      kind: kind ?? this.kind,
      onTap: onTap == _sentinel ? this.onTap : onTap as VoidCallback?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkStatusItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          message == other.message &&
          detail == other.detail &&
          progress == other.progress &&
          kind == other.kind &&
          onTap == other.onTap;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      message.hashCode ^
      detail.hashCode ^
      progress.hashCode ^
      kind.hashCode ^
      onTap.hashCode;
}

const Object _sentinel = Object();
