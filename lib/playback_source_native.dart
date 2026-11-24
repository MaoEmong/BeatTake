import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

import 'wav_audio.dart';

class PlaybackSource {
  Directory? _scratch;

  Future<Source> prepare(AudioInput input) async {
    var path = input.path;
    if (path == null) {
      final folder = _scratch ??= await Directory.systemTemp.createTemp(
        'beats_preview_',
      );
      final file = File.fromUri(folder.uri.resolve('preview.wav'));
      await file.writeAsBytes(input.bytes!);
      path = file.path;
    }
    return DeviceFileSource(path, mimeType: 'audio/wav');
  }

  Future<void> dispose() async {
    try {
      await _scratch?.delete(recursive: true);
    } on FileSystemException {
      // The operating system may already have removed the preview.
    }
  }
}
