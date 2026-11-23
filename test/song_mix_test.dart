import 'dart:io';
import 'dart:typed_data';

import 'package:everyday_beats/song.dart';
import 'package:everyday_beats/wav_audio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'clips are mixed at their start times, including overlapping tracks',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'beats_mix_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final input = File.fromUri(directory.uri.resolve('clip.wav')).path;
      final output = File.fromUri(directory.uri.resolve('mix.wav')).path;
      WavFile.write(input, 44100, Int16List.fromList(List.filled(88, 900)));
      SongMix.render(
        const [
          SoundPlacement(clipId: 'clip', track: 0, startMs: 1),
          SoundPlacement(clipId: 'clip', track: 1, startMs: 2),
        ],
        {'clip': input},
        output,
      );

      final wav = WavFile.open(output);
      expect(wav.frames, 176);
      expect(wav.readFrames(0, 44), everyElement(0));
      expect(wav.readFrames(44, 88), everyElement(900));
      expect(wav.readFrames(88, 132), everyElement(1800));
      expect(wav.readFrames(132, 176), everyElement(900));
    },
  );
}
