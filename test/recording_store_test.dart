import 'dart:io';

import 'package:everyday_beats/recording_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'saved audio can be loaded by a new store from the same directory',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'everyday_beats_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = RecordingStore(directory);
      final draft = store.newDraft();
      final audio = [
        // A WAV header followed by one 16-bit PCM sample.
        82, 73, 70, 70, 38, 0, 0, 0, 87, 65, 86, 69,
        102, 109, 116, 32, 16, 0, 0, 0, 1, 0, 1, 0,
        68, 172, 0, 0, 136, 88, 1, 0, 2, 0, 16, 0,
        100, 97, 116, 97, 2, 0, 0, 0, 1, 0,
      ];
      await draft.writeAsBytes(audio);

      expect(await store.list(), isEmpty);
      final saved = await store.save(draft);
      expect(await draft.exists(), isFalse);

      final reopened = RecordingStore(directory);
      final loaded = (await reopened.list()).single;
      expect(loaded.file.path, saved.file.path);
      expect(loaded.recordedAt, saved.recordedAt);
      expect(await loaded.file.readAsBytes(), audio);
    },
  );

  test('an empty recording is not published', () async {
    final directory = await Directory.systemTemp.createTemp('everyday_beats_');
    addTearDown(() => directory.delete(recursive: true));
    final store = RecordingStore(directory);
    final draft = await store.newDraft().writeAsBytes(List.filled(44, 0));

    await expectLater(store.save(draft), throwsA(isA<FileSystemException>()));
    expect(await store.list(), isEmpty);
  });
}
