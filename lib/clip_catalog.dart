import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'copy.dart';
import 'library_files.dart';
import 'recording_store.dart';
import 'wav_audio.dart';

typedef ClipDetails = ({int durationMs, List<double> peaks});

Future<Map<String, ClipDetails>> inspectClips(
  Map<String, String> keys,
  LibraryFiles files,
) async {
  if (kIsWeb) {
    final details = <String, ClipDetails>{};
    for (final entry in keys.entries) {
      try {
        details[entry.key] = _details(await files.audio(entry.value));
      } on FormatException {
        continue;
      } on LibraryFileException {
        continue;
      }
    }
    return details;
  }
  final inputs = {
    for (final entry in keys.entries) entry.key: await files.audio(entry.value),
  };
  return compute(_inspect, inputs);
}

Map<String, ClipDetails> _inspect(Map<String, AudioInput> files) {
  final details = <String, ClipDetails>{};
  for (final entry in files.entries) {
    try {
      details[entry.key] = _details(entry.value);
    } on FormatException {
      continue;
    } on FileSystemException {
      continue;
    }
  }
  return details;
}

ClipDetails _details(AudioInput input) {
  final source = WavFile.read(input);
  return (durationMs: source.durationMs, peaks: source.peaks());
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
