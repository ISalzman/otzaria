/// מיפוי משמות שיטות API לשמות ההרשאות הנדרשות - לשימוש בהודעות שגיאה מועילות
const Map<String, String> apiCallToPermissionHint = {
  'app.getUserEmail': 'app.user_email.read',
  'app.getInfo': 'app.info.read',
  'app.getTheme': 'app.info.read',
  'app.getLocale': 'app.info.read',
  'app.getGrantedPermissions': 'app.info.read',
};

const pluginValidPermissions = <String>[
  'app.info.read',
  'app.user_email.read',
  'library.books.read',
  'library.content.read',
  'search.fulltext.read',
  'reader.open',
  'navigation.write',
  'notes.read',
  'notes.write',
  'calendar.read',
  'settings.read',
  'ui.feedback',
  'plugin.storage.read',
  'plugin.storage.write',
  'published_data.write',
  'network.access',
  'events.subscribe:navigation.changed',
  'events.subscribe:reader.current_book_changed',
  'events.subscribe:theme.changed',
  'events.subscribe:settings.changed',
  'events.subscribe:calendar.date_changed',
  'events.subscribe:workspace.changed',
  'events.subscribe:plugin.permissions_changed',
];
