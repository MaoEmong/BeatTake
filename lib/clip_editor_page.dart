import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'copy.dart';
import 'playback_source.dart';
import 'recording_store.dart';
import 'studio_widgets.dart';
import 'wav_audio.dart';

class ClipEditorPage extends StatefulWidget {
  const ClipEditorPage({
    super.key,
    required this.recording,
    required this.store,
  });

  final SavedRecording recording;
  final RecordingStore store;

  @override
  State<ClipEditorPage> createState() => _ClipEditorPageState();
}

class _ClipEditorPageState extends State<ClipEditorPage> {
  final _player = AudioPlayer();
  final _name = TextEditingController();
  late final StreamSubscription<void> _complete;
  WavFile? _audio;
  List<double> _peaks = [];
  final _source = PlaybackSource();
  RangeValues _range = const RangeValues(0, 0);
  bool _busy = false;
  bool _playing = false;
  int _semitones = 0;
  L? _error;

  @override
  void initState() {
    super.initState();
    _name.text = widget.recording.name ?? '';
    _complete = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final input = await widget.store.files.audio(widget.recording.key);
      final preview = await compute(_readPreview, input);
      if (!mounted) return;
      setState(() {
        _audio = preview.audio;
        _peaks = preview.peaks;
        _range = RangeValues(
          0,
          preview.audio.frames / preview.audio.sampleRate,
        );
      });
    } catch (error) {
      assert(() {
        debugPrint('Cannot open recording for editing: $error');
        return true;
      }());
      if (mounted) setState(() => _error = L.soundOpenFailed);
    }
  }

  Future<void> _useSelection({required bool save}) async {
    final audio = _audio;
    if (_busy || audio == null) return;
    final start = (_range.start * audio.sampleRate).round();
    final end = (_range.end * audio.sampleRate).round();
    final semitones = _semitones;
    final name = _name.text.trim();
    if (save && utf8.encode(name).length > 150) {
      setState(() => _error = L.nameTooLong);
      return;
    }
    if (end <= start || _range.end - _range.start > WavFile.maxPreviewSeconds) {
      setState(() => _error = L.clipRange);
      return;
    }
    final wasPlaying = _playing;
    setState(() {
      _busy = true;
      _playing = false;
      _error = null;
    });
    try {
      await _player.stop();
      if (!save && wasPlaying) return;
      final output = await compute(_renderSelection, (
        audio: audio,
        start: start,
        end: end,
        semitones: semitones,
      ));
      if (!mounted) return;
      if (save) {
        await widget.store.saveClip(output, name);
        if (mounted) Navigator.pop(context, true);
      } else {
        setState(() => _playing = true);
        await _player.play(await _source.prepare(AudioInput.memory(output)));
      }
    } on FormatException {
      if (mounted) {
        setState(() => _error = L.clipLimit);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _error = save ? L.clipSaveError : L.previewError;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disposePreview() async {
    try {
      await _player.dispose();
    } finally {
      await _source.dispose();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    unawaited(_complete.cancel());
    unawaited(_disposePreview());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = _audio;
    return PopScope<bool>(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(L.editSound(context))),
        body: StudioList(
          children: [
            if (audio == null && _error == null)
              const LinearProgressIndicator(),
            if (audio != null) ...[
              StudioPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      L.selection(context),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Waveform(
                      levels: _peaks,
                      height: 124,
                      selection: RangeValues(
                        _range.start * audio.sampleRate / audio.frames,
                        _range.end * audio.sampleRate / audio.frames,
                      ),
                    ),
                    RangeSlider(
                      values: _range,
                      max: audio.frames / audio.sampleRate,
                      labels: RangeLabels(
                        L.seconds(context, _range.start.toStringAsFixed(2)),
                        L.seconds(context, _range.end.toStringAsFixed(2)),
                      ),
                      onChanged: _busy || _playing
                          ? null
                          : (value) => setState(() => _range = value),
                    ),
                    Text(
                      '${L.seconds(context, _range.start.toStringAsFixed(2))} – ${L.seconds(context, _range.end.toStringAsFixed(2))}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              StudioPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${L.pitch(context)} · ${L.semitones(context, _semitones > 0 ? '+$_semitones' : _semitones)}',
                    ),
                    Slider(
                      min: -12,
                      max: 12,
                      divisions: 24,
                      label: L.semitones(context, _semitones),
                      value: _semitones.toDouble(),
                      onChanged: _busy || _playing
                          ? null
                          : (value) =>
                                setState(() => _semitones = value.round()),
                    ),
                    Text(L.pitchHelp(context)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                maxLength: 24,
                decoration: InputDecoration(labelText: L.soundName(context)),
                enabled: !_busy,
              ),
              Wrap(
                spacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: _busy ? null : () => _useSelection(save: false),
                    child: Text(
                      (_playing ? L.stopPlayback : L.preview)(context),
                    ),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : () => _useSelection(save: true),
                    child: Text(L.saveClip(context)),
                  ),
                ],
              ),
            ],
            if (_busy) const LinearProgressIndicator(),
            if (_error case final message?)
              Semantics(liveRegion: true, child: Text(message(context))),
          ],
        ),
      ),
    );
  }
}

({WavFile audio, List<double> peaks}) _readPreview(AudioInput input) {
  final audio = WavFile.read(input);
  return (audio: audio, peaks: audio.peaks());
}

Uint8List _renderSelection(
  ({WavFile audio, int start, int end, int semitones}) selection,
) {
  final audio = selection.audio;
  return WavFile.encode(
    audio.sampleRate,
    audio.edit(selection.start, selection.end, selection.semitones),
  );
}
