import 'dart:io';

import 'package:everyday_beats/song.dart';
import 'package:everyday_beats/song_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a malformed song does not hide other songs or permit clip deletion',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'beats_song_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = SongStore(directory);
      const sound = SoundPlacement(clipId: 'clip_1.wav', track: 0, startMs: 0);
      final saved = await store.save(
        name: 'Readable song',
        placements: [sound],
      );
      final malformed = File.fromUri(
        directory.uri.resolve('songs/song_1.json'),
      );
      await malformed.writeAsString('{"version":1,"name":');
      final badDate = File.fromUri(directory.uri.resolve('songs/song_2.json'));
      await badDate.writeAsString(
        '{"version":1,"name":"Bad date","updatedAt":8640000000000001,"placements":[]}',
      );

      var unreadable = 0;
      final songs = await store.list(onUnreadable: () => unreadable++);

      expect(unreadable, 2);
      expect(songs.single.id, saved.id);
      expect(songs.single.placements.single.toJson(), sound.toJson());
      await expectLater(store.usesClip(sound.clipId), throwsFormatException);
      await expectLater(store.usesClip('clip_2.wav'), throwsFormatException);
      expect(await malformed.readAsString(), '{"version":1,"name":');
    },
  );
}
