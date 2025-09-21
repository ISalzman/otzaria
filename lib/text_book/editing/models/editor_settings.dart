import 'package:equatable/equatable.dart';

/// Sanitization levels for HTML content
enum SanitizationLevel {
  strict,   // Very restrictive, minimal HTML allowed
  standard, // Standard level with common formatting tags
}

/// Configuration settings for the text editor
class EditorSettings extends Equatable {
  /// Whether the text editor feature is enabled
  final bool enableEditor;
  
  /// Debounce duration for preview updates
  final Duration previewDebounce;
  
  /// Maximum section size in KB for editing
  final int maxSectionSizeKB;
  
  /// Auto-save interval in seconds
  final int autosaveIntervalSec;
  
  /// Maximum number of drafts to keep per section
  final int maxDraftsPerSection;
  
  /// Maximum draft size in MB per section
  final int maxDraftSizeMBPerSection;
  
  /// Global quota for all drafts in MB
  final int globalDraftsQuotaMB;
  
  /// Number of days after which to clean up old drafts
  final int draftCleanupDays;
  
  /// Whether to show "נערך" badges for edited sections
  final bool showEditedBadge;
  
  /// List of enabled markdown features
  final List<String> enabledMarkdownFeatures;
  
  /// Level of HTML sanitization to apply
  final SanitizationLevel sanitizationLevel;
  
  /// Whether to show preview by default when opening editor
  final bool showPreviewByDefault;

  const EditorSettings({
    this.enableEditor = true,
    this.previewDebounce = const Duration(milliseconds: 150),
    this.maxSectionSizeKB = 200,
    this.autosaveIntervalSec = 10,
    this.maxDraftsPerSection = 10,
    this.maxDraftSizeMBPerSection = 5,
    this.globalDraftsQuotaMB = 100,
    this.draftCleanupDays = 30,
    this.showEditedBadge = true,
    this.enabledMarkdownFeatures = const [
      'bold',
      'italic', 
      'headers',
      'lists',
      'links',
      'code',
      'quotes'
    ],
    this.sanitizationLevel = SanitizationLevel.standard,
    this.showPreviewByDefault = true,
  });

  /// Creates a copy with updated values
  EditorSettings copyWith({
    bool? enableEditor,
    Duration? previewDebounce,
    int? maxSectionSizeKB,
    int? autosaveIntervalSec,
    int? maxDraftsPerSection,
    int? maxDraftSizeMBPerSection,
    int? globalDraftsQuotaMB,
    int? draftCleanupDays,
    bool? showEditedBadge,
    List<String>? enabledMarkdownFeatures,
    SanitizationLevel? sanitizationLevel,
    bool? showPreviewByDefault,
  }) {
    return EditorSettings(
      enableEditor: enableEditor ?? this.enableEditor,
      previewDebounce: previewDebounce ?? this.previewDebounce,
      maxSectionSizeKB: maxSectionSizeKB ?? this.maxSectionSizeKB,
      autosaveIntervalSec: autosaveIntervalSec ?? this.autosaveIntervalSec,
      maxDraftsPerSection: maxDraftsPerSection ?? this.maxDraftsPerSection,
      maxDraftSizeMBPerSection: maxDraftSizeMBPerSection ?? this.maxDraftSizeMBPerSection,
      globalDraftsQuotaMB: globalDraftsQuotaMB ?? this.globalDraftsQuotaMB,
      draftCleanupDays: draftCleanupDays ?? this.draftCleanupDays,
      showEditedBadge: showEditedBadge ?? this.showEditedBadge,
      enabledMarkdownFeatures: enabledMarkdownFeatures ?? this.enabledMarkdownFeatures,
      sanitizationLevel: sanitizationLevel ?? this.sanitizationLevel,
      showPreviewByDefault: showPreviewByDefault ?? this.showPreviewByDefault,
    );
  }

  @override
  List<Object?> get props => [
    enableEditor,
    previewDebounce,
    maxSectionSizeKB,
    autosaveIntervalSec,
    maxDraftsPerSection,
    maxDraftSizeMBPerSection,
    globalDraftsQuotaMB,
    draftCleanupDays,
    showEditedBadge,
    enabledMarkdownFeatures,
    sanitizationLevel,
    showPreviewByDefault,
  ];
}