class PluginManifest {
  static const String toolTabIconVariantRegular = 'regular';
  static const String toolTabIconVariantFilled = 'filled';
  static const Set<String> supportedToolTabIconVariants = {
    toolTabIconVariantRegular,
    toolTabIconVariantFilled,
  };

  final int schemaVersion;
  final String id;
  final String name;
  final String version;
  final String description;
  final String author;
  final String homepage;
  final String entrypoint;
  final String? icon;
  final String minAppVersion;
  final String? maxAppVersion;
  final String sdkVersion;
  final List<String> permissions;
  final bool networkEnabled;
  final List<String> networkAllowlist;
  final String toolTabTitle;
  final int toolTabOrder;
  final bool defaultPinned;
  final int? toolTabIconCodepoint;
  final String? toolTabIconVariant;
  final List<String> publishedDataTypes;

  PluginManifest({
    required this.schemaVersion,
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.author,
    required this.homepage,
    required this.entrypoint,
    this.icon,
    required this.minAppVersion,
    this.maxAppVersion,
    required this.sdkVersion,
    required this.permissions,
    required this.networkEnabled,
    required this.networkAllowlist,
    required this.toolTabTitle,
    required this.toolTabOrder,
    required this.defaultPinned,
    this.toolTabIconCodepoint,
    this.toolTabIconVariant,
    required this.publishedDataTypes,
  });

  String? get toolTabIconFontFamily {
    if (toolTabIconCodepoint == null) {
      return null;
    }

    switch (toolTabIconVariant ?? toolTabIconVariantRegular) {
      case toolTabIconVariantFilled:
        return 'FluentSystemIcons-Filled';
      case toolTabIconVariantRegular:
      default:
        return 'FluentSystemIcons-Regular';
    }
  }

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    final network = json['network'] as Map<String, dynamic>? ?? {};
    final contributes = json['contributes'] as Map<String, dynamic>? ?? {};
    final toolTab = contributes['toolTab'] as Map<String, dynamic>? ?? {};

    return PluginManifest(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      description: json['description'] as String? ?? '',
      author: json['author'] as String? ?? '',
      homepage: json['homepage'] as String? ?? '',
      entrypoint: json['entrypoint'] as String,
      icon: json['icon'] as String?,
      minAppVersion: json['minAppVersion'] as String? ?? '0.0.0',
      maxAppVersion: json['maxAppVersion'] as String?,
      sdkVersion: json['sdkVersion'] as String? ?? '1.x',
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      networkEnabled: network['enabled'] as bool? ?? false,
      networkAllowlist: (network['allowlist'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      toolTabTitle: toolTab['title'] as String? ?? json['name'] as String,
      toolTabOrder: toolTab['order'] as int? ?? 900,
      defaultPinned: toolTab['defaultPinned'] as bool? ?? true,
      toolTabIconCodepoint: toolTab['iconCodepoint'] as int?,
      toolTabIconVariant: toolTab['iconVariant'] as String?,
      publishedDataTypes: (contributes['publishedDataTypes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'id': id,
      'name': name,
      'version': version,
      'description': description,
      'author': author,
      'homepage': homepage,
      'entrypoint': entrypoint,
      'icon': icon,
      'minAppVersion': minAppVersion,
      'maxAppVersion': maxAppVersion,
      'sdkVersion': sdkVersion,
      'permissions': permissions,
      'network': {
        'enabled': networkEnabled,
        'allowlist': networkAllowlist,
      },
      'contributes': {
        'toolTab': {
          'title': toolTabTitle,
          'order': toolTabOrder,
          'defaultPinned': defaultPinned,
          if (toolTabIconCodepoint != null)
            'iconCodepoint': toolTabIconCodepoint,
          if (toolTabIconVariant != null) 'iconVariant': toolTabIconVariant,
        },
        'publishedDataTypes': publishedDataTypes,
      }
    };
  }
}
