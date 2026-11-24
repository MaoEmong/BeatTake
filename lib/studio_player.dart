import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'library_files.dart';
import 'playback_source.dart';
import 'song.dart';
import 'wav_audio.dart';

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
  final _source = PlaybackSource();
  Future<void>? _pending;
  String? _playing;
  Duration _position = Duration.zero;
  bool _busy = false;
  bool _closed = false;

  String? get playing => _playing;
  Duration get position => _position;
  bool get busy => _busy;

  Future<void> toggleFile(String key, LibraryFiles files) =>
      _toggle(key, () => files.audio(key));

  Future<void> toggleSong(
    String id,
    List<SoundPlacement> placements,
    Map<String, String> keys,
    LibraryFiles files,
  ) => _toggle(id, () async {
    final clips = <String, AudioInput>{};
    for (final id in placements.map((placement) => placement.clipId).toSet()) {
      final key = keys[id];
      if (key == null) throw const FormatException('Missing audio');
      clips[id] = await files.audio(key);
    }
    final output = await compute(_renderMix, (
      placements: placements,
      clips: clips,
    ));
    return AudioInput.memory(output);
  });

  Future<void> _toggle(String id, Future<AudioInput> Function() source) async {
    if (_busy || _closed) return;
    final operation = _play(id, source);
    _pending = operation;
    try {
      await operation;
    } finally {
      _pending = null;
    }
  }

  Future<void> _play(String id, Future<AudioInput> Function() source) async {
    final shouldStop = _playing == id;
    _busy = true;
    _refresh();
    try {
      await stop();
      if (shouldStop || _closed) return;
      final input = await source();
      if (_closed) return;
      final playable = await _source.prepare(input);
      if (_closed) return;
      _playing = id;
      await _audio.play(playable);
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
    try {
      await _audio.dispose();
    } finally {
      await _source.dispose();
    }
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(_close());
    super.dispose();
  }
}

Uint8List _renderMix(
  ({List<SoundPlacement> placements, Map<String, AudioInput> clips}) input,
) => SongMix.preview(input.placements, input.clips);
