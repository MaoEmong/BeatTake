import 'dart:io';

import 'package:everyday_beats/app_preferences.dart';
import 'package:everyday_beats/copy.dart';
import 'package:everyday_beats/main.dart';
import 'package:everyday_beats/recording_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'English is the default and all four languages update the studio',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 780);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      FlutterSecureStorage.setMockInitialValues({});
      final directory = Directory.systemTemp.createTempSync(
        'beats_studio_test_',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      await tester.pumpWidget(
        BeatTakeApp(openRecordings: () async => RecordingStore(directory)),
      );
      await tester.pumpAndSettle();

      expect(find.text('BeatTake'), findsOneWidget);
      expect(find.text('Record a sound'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      for (final (language, heading) in [
        (AppLanguage.ko, '설정'),
        (AppLanguage.ja, '設定'),
        (AppLanguage.zh, '设置'),
        (AppLanguage.en, 'Settings'),
      ]) {
        await tester.tap(find.byType(DropdownButtonFormField<AppLanguage>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(language.label).last);
        await tester.pumpAndSettle();
        expect(find.text(heading), findsWidgets);
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
          language.locale,
        );
      }

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      await tester.runAsync(() async {
        expect((await const PreferenceStore().load()).openEditor, isFalse);
      });
      expect(tester.takeException(), isNull);
    },
  );
}
