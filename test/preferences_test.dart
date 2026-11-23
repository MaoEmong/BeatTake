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
}
