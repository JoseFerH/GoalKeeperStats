/// Configuraciones de usuario
class UserSettings {
  final String language;
  final bool darkMode;
  final bool notificationsEnabled;

  UserSettings({
    required this.language,
    required this.darkMode,
    required this.notificationsEnabled,
  });

  factory UserSettings.defaultSettings() {
    return UserSettings(
      language: 'es',
      darkMode: false,
      notificationsEnabled: true,
    );
  }

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      language: map['language'] ?? 'es',
      darkMode: map['darkMode'] ?? false,
      notificationsEnabled: map['notificationsEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'language': language,
      'darkMode': darkMode,
      'notificationsEnabled': notificationsEnabled,
    };
  }

  UserSettings copyWith({
    String? language,
    bool? darkMode,
    bool? notificationsEnabled,
  }) {
    return UserSettings(
      language: language ?? this.language,
      darkMode: darkMode ?? this.darkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
