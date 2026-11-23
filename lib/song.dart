import 'dart:math' as math;
import 'dart:typed_data';

import 'wav_audio.dart';

class SoundPlacement {
  const SoundPlacement({
    required this.clipId,
    required this.track,
    required this.startMs,
  });

  final String clipId;
  final int track;
  final int startMs;

  static const trackCount = 8;
  static const maxCount = 128;
  static const maxStartMs = WavFile.maxPreviewSeconds * 1000 - 1;

  factory SoundPlacement.fromJson(Object? value) {
    if (value
        case {
          'clipId': final String id,
          'track': final int track,
          'startMs': final int start,
        }
        when id.isNotEmpty &&
            track >= 0 &&
            track < trackCount &&
            start >= 0 &&
            start <= maxStartMs) {
      return SoundPlacement(clipId: id, track: track, startMs: start);
    }
    throw const FormatException('Invalid sound placement');
  }

  Map<String, Object> toJson() => {
    'clipId': clipId,
    'track': track,
    'startMs': startMs,
  };
}

class SongMix {
  static const sampleRate = 44100;

  static void render(
    List<SoundPlacement> placements,
    Map<String, String> clipPaths,
    String outputPath,
  ) {
    if (placements.isEmpty || placements.length > SoundPlacement.maxCount) {
      throw const FormatException('Invalid song size');
    }
    final byClip = <String, List<int>>{};
    final audioFiles = <String, WavFile>{};
    var totalFrames = 0;
    for (final placement in placements) {
      final path = clipPaths[placement.clipId];
      if (path == null ||
          placement.startMs < 0 ||
          placement.startMs > SoundPlacement.maxStartMs) {
        throw const FormatException('Missing or misplaced audio');
      }
      final audio = audioFiles.putIfAbsent(
        placement.clipId,
        () => WavFile.open(path),
      );
      final start = (placement.startMs * sampleRate / 1000).round();
      final length = math.max(
        1,
        (audio.frames * sampleRate / audio.sampleRate).round(),
      );
      totalFrames = math.max(totalFrames, start + length);
      byClip.putIfAbsent(placement.clipId, () => <int>[]).add(start);
    }
    if (totalFrames > WavFile.maxPreviewSeconds * sampleRate) {
      throw const FormatException('Song is longer than the preview limit');
    }

    final mixed = Int32List(totalFrames);
    for (final entry in byClip.entries) {
      final audio = audioFiles[entry.key]!;
      final samples = WavFile.changeRate(
        audio.readFrames(0, audio.frames),
        audio.sampleRate / sampleRate,
      );
      for (final start in entry.value) {
        for (var index = 0; index < samples.length; index++) {
          mixed[start + index] += samples[index];
        }
      }
    }

    var peak = 32767;
    for (final sample in mixed) {
      peak = math.max(peak, sample.abs());
    }
    final scale = 32767 / peak;
    final samples = Int16List(totalFrames);
    for (var index = 0; index < totalFrames; index++) {
      samples[index] = (mixed[index] * scale).round();
    }
    WavFile.write(outputPath, sampleRate, samples);
  }
}
