import 'package:everyday_beats/app_preferences.dart';
import 'package:everyday_beats/copy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'defaults to English and restores locale and recording workflow',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const store = PreferenceStore();
      final defaults = await store.load();
      expect(defaults.language, AppLanguage.en);
      expect(defaults.openEditor, isTrue);
      await store.save(
        defaults.copyWith(language: AppLanguage.ja, openEditor: false),
      );
      final saved = await const PreferenceStore().load();
      expect(saved.language, AppLanguage.ja);
      expect(saved.openEditor, isFalse);
    },
  );

  test(
    'upgrades previous AI settings and retains the stored OpenAI key',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'studio_preferences':
            '{"language":"ko","openEditor":false,"aiProvider":"claude"}',
        'gemini_api_key': 'legacy-gemini-key',
        'claude_api_key': 'legacy-claude-key',
        'openai_api_key': 'legacy-openai-key',
      });
      const store = PreferenceStore();
      final previous = await store.load();
      expect(await store.readOpenAiKey(), 'legacy-openai-key');
      await store.save(previous);

      const reopened = PreferenceStore();
      final preferences = await reopened.load();
      expect(preferences.language, AppLanguage.ko);
      expect(preferences.openEditor, isFalse);
      expect(await reopened.readOpenAiKey(), 'legacy-openai-key');
      await reopened.saveOpenAiKey('replacement-openai-key');
      expect(await reopened.readOpenAiKey(), 'replacement-openai-key');
      await reopened.saveOpenAiKey(null);
      expect(await reopened.readOpenAiKey(), isNull);
      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'gemini_api_key'), 'legacy-gemini-key');
      expect(await storage.read(key: 'claude_api_key'), 'legacy-claude-key');
    },
  );
}
