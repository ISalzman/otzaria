# Implementation Plan

- [x] 1. Set up internal package structure and define surface API


  - Create packages/shamor_zachor directory with proper pubspec.yaml
  - Set up basic package structure (lib/, assets/, pubspec.yaml)
  - Add path dependency in main pubspec.yaml
  - Create main export file (shamor_zachor.dart) with minimal public API: ShamorZachorWidget only
  - Define optional init() method for configuration (assets override, theme inheritance)
  - _Requirements: 1.1, 1.3_


- [x] 2. Copy and adapt core data models from Shamor-Zachor project

  - Copy BookCategory, BookDetails, BookPart, and LearnableItem models
  - Copy ProgressModel and related data structures
  - Adapt import paths for internal package structure
  - Add proper documentation and type safety improvements
  - _Requirements: 2.1, 2.2, 3.1, 3.2_

- [x] 3. Implement data loading services with versioned JSON schema


  - Copy and adapt DataLoaderService for loading JSON data files
  - Copy JSON data files (tanach.json, shas.json, mishna.json, etc.) to package assets
  - Add schemaVersion field to all JSON files and implement migration strategy
  - Update asset paths to work within the internal package
  - Implement lazy loading by category to prevent freeze on first load
  - Implement comprehensive error taxonomy (MissingAsset, ParseError, StorageUnavailable)
  - _Requirements: 1.2, 2.1, 5.4_

- [x] 4. Implement progress service with optimized storage strategy


  - Copy and adapt ProgressService for saving/loading user progress
  - Implement storage key prefixing (sz:) to avoid conflicts with main app
  - Add debounced delta saving to reduce frequent SharedPreferences writes
  - Implement batch operations for "mark all" functionality
  - Add data validation and error recovery for corrupted progress data
  - _Requirements: 3.2, 5.1, 5.2, 5.3_

- [x] 5. Create local-scoped providers for state management


  - Copy and adapt DataProvider as ShamorZachorDataProvider
  - Copy and adapt ProgressProvider as ShamorZachorProgressProvider
  - Remove global dependencies and make providers self-contained
  - Add proper error state management and loading states
  - _Requirements: 1.2, 2.1, 3.1, 5.1_

- [x] 6. Implement main widget with navigation and theming integration


  - Create ShamorZachorWidget as the main entry point
  - Wrap providers locally within the widget (not globally)
  - Implement AutomaticKeepAliveClientMixin for state preservation
  - Set up internal Navigator with proper back button handling
  - Inherit theme from host app (colors, fonts, RTL) with fallback defaults
  - Add deep-link support hooks for future category/book navigation
  - _Requirements: 1.1, 1.3, 6.1, 6.2_

- [x] 7. Implement tracking screen with progress display


  - Copy and adapt TrackingScreen for displaying learning progress
  - Implement progress bars with percentage calculations
  - Add Hebrew date display for completion dates
  - Implement filtering for "in progress" vs "completed" books
  - Add AutomaticKeepAliveClientMixin for state preservation
  - _Requirements: 4.1, 4.2, 4.3, 6.2_

- [x] 8. Implement books screen with search and category navigation


  - Copy and adapt BooksScreen for displaying book categories
  - Implement search functionality with real-time filtering
  - Add category navigation with subcategory support
  - Implement completion checkmarks (✔️) for finished books
  - Add PageStorageKey for preserving scroll position and search state
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 6.3_

- [x] 9. Implement book detail screen with progress tracking
  - Copy and adapt BookDetailScreen for individual book progress
  - Implement checkbox system for learning + 3 reviews per item
  - Add "mark all as learned" bulk action functionality
  - Implement real-time progress updates and auto-save
  - Add proper RTL support for Hebrew text and layout
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 6.4_

- [x] 10. Implement navigation integration in more_screen.dart
  - Update MoreScreen to import and use ShamorZachorWidget
  - Replace "בקרוב..." text with the full ShamorZachorWidget
  - Ensure proper integration with existing navigation rail
  - Test navigation between different sections of "More" screen
  - _Requirements: 1.1, 4.4_

- [x] 11. Implement comprehensive error handling with user-friendly messages
  - Create error taxonomy enum (MissingAsset, ParseError, StorageUnavailable, etc.)
  - Implement ErrorBoundary widget with contextual error messages
  - Add loading states and progress indicators for heavy operations
  - Create user-friendly Hebrew error messages with retry options
  - Implement logging strategy (what goes to console vs user display)
  - Test error scenarios (missing files, storage issues, corrupted data)
  - _Requirements: 5.4, 6.2_

- [x] 12. Implement RTL support, accessibility, and i18n strategy
  - Ensure all text displays correctly in RTL direction inherited from host app
  - Distinguish between data-driven text (from JSON) and UI text (hardcoded Hebrew)
  - Add proper Semantics labels for screen readers
  - Implement keyboard navigation support
  - Test with Hebrew fonts and text rendering
  - Add focus management for better accessibility
  - _Requirements: 6.4_

- [x] 13. Add comprehensive unit tests for models and services
  - Write tests for BookCategory and BookDetails model parsing
  - Write tests for progress calculations and validations
  - Write tests for DataLoaderService JSON loading and error handling
  - Write tests for ProgressService save/load operations with prefixed keys
  - Write tests for provider state management and notifications
  - _Requirements: All requirements (testing coverage)_

- [x] 14. Add widget tests for screens and user interactions
  - Write tests for TrackingScreen rendering with different progress states
  - Write tests for BooksScreen search functionality and category navigation
  - Write tests for BookDetailScreen progress updates and bulk actions
  - Write tests for navigation between screens and state preservation
  - Write tests for error states and loading indicators
  - _Requirements: All requirements (testing coverage)_

- [x] 15. Perform integration testing and final polish
  - Test complete user flow from book selection to progress tracking
  - Test data persistence across app restarts and navigation
  - Test performance with large datasets (many books and progress data)
  - Verify memory usage and cleanup when navigating away
  - Test on different screen sizes and orientations
  - _Requirements: All requirements (integration testing)_