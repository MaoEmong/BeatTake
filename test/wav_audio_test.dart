import 'dart:io';
import 'dart:typed_data';

import 'package:everyday_beats/recording_store.dart';
import 'package:everyday_beats/wav_audio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'an octave shifts pitch by changing sample spacing and duration',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'beats_pitch_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = File.fromUri(directory.uri.resolve('tone.wav')).path;
      WavFile.write(path, 44100, Int16List.fromList([0, 100, -100, 200]));
      final audio = WavFile.open(path);
      expect(audio.edit(0, 4, 0), [0, 100, -100, 200]);
      expect(audio.edit(0, 4, 12), [0, -100]);
      expect(audio.edit(0, 4, -12), [0, 50, 100, 0, -100, 50, 200, 200]);
    },
  );

  test(
    'a selected WAV range is saved separately and survives reopening',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'beats_audio_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = RecordingStore(directory);
      final draft = store.newDraft();
      final original = Int16List.fromList([-900, 100, -200, 300, 900]);
      WavFile.write(draft.path, 44100, original);
      final recording = await store.save(draft);
      final audio = WavFile.open(recording.file.path);
      final preview = File.fromUri(directory.uri.resolve('preview.wav'));
      WavFile.write(preview.path, audio.sampleRate, audio.readFrames(1, 4));
      await store.saveClip(preview, '책상 두드리기');

      final reopened = RecordingStore(directory);
      final clip = (await reopened.listClips()).single;
      expect(clip.name, '책상 두드리기');
      final savedAudio = WavFile.open(clip.file.path);
      expect(savedAudio.sampleRate, 44100);
      expect(savedAudio.readFrames(0, savedAudio.frames), [100, -200, 300]);
      expect((await reopened.list()).single.id, recording.id);
      expect(audio.readFrames(0, audio.frames), original);
    },
  );
}
