import 'dart:io';

import 'package:flutter/widgets.dart';

import 'copy.dart';
import 'recording_store.dart';
import 'wav_audio.dart';

typedef ClipDetails = ({int durationMs, List<double> peaks});

Map<String, ClipDetails> inspectClips(Map<String, String> files) {
  final details = <String, ClipDetails>{};
  for (final entry in files.entries) {
    try {
      final source = WavFile.open(entry.value);
      details[entry.key] = (
        durationMs: source.durationMs,
        peaks: source.peaks(),
      );
    } on FormatException {
      continue;
    } on FileSystemException {
      continue;
    }
  }
  return details;
}

Map<String, String> clipNames(
  BuildContext context,
  List<SavedRecording> clips,
) => {
  for (final (index, clip) in clips.indexed)
    clip.id: clip.name ?? L.clipName(context, clips.length - index),
};

String timeCode(Duration duration) {
  final seconds = duration.inSeconds;
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}
