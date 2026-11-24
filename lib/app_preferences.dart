import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'copy.dart';

class AppPreferences {
  const AppPreferences({
    this.language = AppLanguage.en,
    this.openEditor = true,
  });

  final AppLanguage language;
  final bool openEditor;

  AppPreferences copyWith({AppLanguage? language, bool? openEditor}) =>
      AppPreferences(
        language: language ?? this.language,
        openEditor: openEditor ?? this.openEditor,
      );
}

class PreferenceStore {
  const PreferenceStore();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  static const _preferencesKey = 'studio_preferences';
  static const _openAiKey = 'openai_api_key';

  Future<AppPreferences> load() async {
    final data = await _storage.read(key: _preferencesKey);
    if (data == null) return const AppPreferences();
    try {
      if (jsonDecode(data) case final Map<String, dynamic> values) {
        return AppPreferences(
          language: AppLanguage.fromCode(
            values['language'] is String ? values['language'] as String : null,
          ),
          openEditor: values['openEditor'] != false,
        );
      }
    } on FormatException {
      // A damaged preference file should not prevent the studio from opening.
    }
    return const AppPreferences();
  }

  Future<void> save(AppPreferences value) => _storage.write(
    key: _preferencesKey,
    value: jsonEncode({
      'language': value.language.name,
      'openEditor': value.openEditor,
    }),
  );

  Future<String?> readOpenAiKey() => _storage.read(key: _openAiKey);

  Future<void> saveOpenAiKey(String? key) => key == null
      ? _storage.delete(key: _openAiKey)
      : _storage.write(key: _openAiKey, value: key);
}
