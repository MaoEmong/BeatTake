import 'package:everyday_beats/ai_provider.dart';
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
    'upgrades Gemini settings and stores provider keys independently',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'studio_preferences': '{"language":"ko","openEditor":false}',
        'gemini_api_key': 'legacy-gemini-key',
      });
      const store = PreferenceStore();
      final previous = await store.load();
      expect(previous.aiProvider, AiProvider.gemini);
      expect(await store.readAiKey(AiProvider.gemini), 'legacy-gemini-key');
      expect(await store.readAiKey(AiProvider.claude), isNull);
      await store.saveAiKey(AiProvider.claude, 'claude-key');
      await store.saveAiKey(AiProvider.openai, 'openai-key');
      await store.save(previous.copyWith(aiProvider: AiProvider.openai));

      const reopened = PreferenceStore();
      final preferences = await reopened.load();
      expect(preferences.aiProvider, AiProvider.openai);
      expect(preferences.language, AppLanguage.ko);
      expect(preferences.openEditor, isFalse);
      expect(await reopened.readAiKey(AiProvider.claude), 'claude-key');
      expect(await reopened.readAiKey(AiProvider.openai), 'openai-key');
      await reopened.saveAiKey(AiProvider.openai, null);
      expect(await reopened.readAiKey(AiProvider.openai), isNull);
      expect(await reopened.readAiKey(AiProvider.claude), 'claude-key');
      expect(await reopened.readAiKey(AiProvider.gemini), 'legacy-gemini-key');
    },
  );
}
