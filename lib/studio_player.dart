import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'song.dart';

class StudioPlayer extends ChangeNotifier {
  StudioPlayer() {
    _finished = _audio.onPlayerComplete.listen((_) {
      _playing = null;
      _position = Duration.zero;
      _refresh();
    });
    _positions = _audio.onPositionChanged.listen((position) {
      if (_playing == null) return;
      _position = position;
      _refresh();
    });
  }

  final _audio = AudioPlayer();
  late final StreamSubscription<void> _finished;
  late final StreamSubscription<Duration> _positions;
  Directory? _scratch;
  Future<void>? _pending;
  String? _playing;
  Duration _position = Duration.zero;
  bool _busy = false;
  bool _closed = false;

  String? get playing => _playing;
  Duration get position => _position;
  bool get busy => _busy;

  Future<void> toggleFile(String path) => _toggle(path, () async => path);

  Future<void> toggleSong(
    String id,
    List<SoundPlacement> placements,
    Map<String, String> paths,
  ) => _toggle(id, () async {
    final directory = _scratch ??= await Directory.systemTemp.createTemp(
      'beats_mix_',
    );
    final output = File.fromUri(directory.uri.resolve('mix.wav')).path;
    await compute(_renderMix, (
      placements: placements,
      paths: paths,
      output: output,
    ));
    return output;
  });

  Future<void> _toggle(String id, Future<String> Function() source) async {
    if (_busy || _closed) return;
    final operation = _play(id, source);
    _pending = operation;
    try {
      await operation;
    } finally {
      _pending = null;
    }
  }

  Future<void> _play(String id, Future<String> Function() source) async {
    final shouldStop = _playing == id;
    _busy = true;
    _refresh();
    try {
      await stop();
      if (shouldStop || _closed) return;
      final path = await source();
      if (_closed) return;
      _playing = id;
      await _audio.play(DeviceFileSource(path, mimeType: 'audio/wav'));
    } catch (_) {
      _playing = null;
      rethrow;
    } finally {
      _busy = false;
      _refresh();
    }
  }

  Future<void> stop() async {
    _playing = null;
    _position = Duration.zero;
    await _audio.stop();
    _refresh();
  }

  void _refresh() {
    if (!_closed) notifyListeners();
  }

  Future<void> _close() async {
    try {
      await _pending;
    } catch (_) {
      // The screen already handles playback errors.
    }
    await _finished.cancel();
    await _positions.cancel();
    await _audio.dispose();
    try {
      await _scratch?.delete(recursive: true);
    } on FileSystemException {
      // The operating system may already have removed the preview.
    }
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(_close());
    super.dispose();
  }
}

void _renderMix(
  ({List<SoundPlacement> placements, Map<String, String> paths, String output})
  input,
) {
  SongMix.render(input.placements, input.paths, input.output);
}
