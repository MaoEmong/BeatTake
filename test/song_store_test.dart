import 'dart:io';

import 'package:everyday_beats/library_files_native.dart';
import 'package:everyday_beats/song.dart';
import 'package:everyday_beats/song_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'song updates survive reopening and track references stop after deletion',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'beats_song_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = SongStore(LocalLibraryFiles(directory));
      final song = await store.save(name: '첫 곡', placements: const []);
      await store.save(
        id: song.id,
        name: '수정한 곡',
        placements: const [
          SoundPlacement(clipId: 'clip_1.wav', track: 1, startMs: 125),
        ],
      );

      final reopened = SongStore(LocalLibraryFiles(directory));
      final loaded = (await reopened.list()).single;
      expect(loaded.id, song.id);
      expect(loaded.name, '수정한 곡');
      expect(loaded.placements.single.toJson(), {
        'clipId': 'clip_1.wav',
        'track': 1,
        'startMs': 125,
      });
      expect(await reopened.usesClip('clip_1.wav'), isTrue);
      await reopened.delete(loaded);
      expect(await reopened.list(), isEmpty);
      expect(await reopened.usesClip('clip_1.wav'), isFalse);
    },
  );
}
