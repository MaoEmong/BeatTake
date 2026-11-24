import 'dart:js_interop';

import 'package:audioplayers/audioplayers.dart';
import 'package:web/web.dart' as web;

import 'wav_audio.dart';

class PlaybackSource {
  String? _url;

  Future<Source> prepare(AudioInput input) async {
    await dispose();
    final blob = web.Blob(
      [input.bytes!.toJS].toJS,
      web.BlobPropertyBag(type: 'audio/wav'),
    );
    final url = _url = web.URL.createObjectURL(blob);
    return UrlSource(url, mimeType: 'audio/wav');
  }

  Future<void> dispose() async {
    if (_url case final url?) web.URL.revokeObjectURL(url);
    _url = null;
  }
}
