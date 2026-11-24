import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ai_provider.dart';
import 'copy.dart';

class AppPreferences {
  const AppPreferences({
    this.language = AppLanguage.en,
    this.openEditor = true,
    this.aiProvider = AiProvider.gemini,
  });

  final AppLanguage language;
  final bool openEditor;
  final AiProvider aiProvider;

  AppPreferences copyWith({
    AppLanguage? language,
    bool? openEditor,
    AiProvider? aiProvider,
  }) => AppPreferences(
    language: language ?? this.language,
    openEditor: openEditor ?? this.openEditor,
    aiProvider: aiProvider ?? this.aiProvider,
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
          aiProvider: AiProvider.fromCode(values['aiProvider']),
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
      'aiProvider': value.aiProvider.name,
    }),
  );

  Future<String?> readAiKey(AiProvider provider) =>
      _storage.read(key: _credentialName(provider));

  Future<void> saveAiKey(AiProvider provider, String? key) {
    final name = _credentialName(provider);
    return key == null
        ? _storage.delete(key: name)
        : _storage.write(key: name, value: key);
  }

  // Gemini keeps the storage name used by previous installations.
  String _credentialName(AiProvider provider) => '${provider.name}_api_key';
}
