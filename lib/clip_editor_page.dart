import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'recording_store.dart';
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
  Directory? _scratch;
  RangeValues _range = const RangeValues(0, 0);
  bool _busy = false;
  bool _playing = false;
  int _semitones = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _complete = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    final path = widget.recording.file.path;
    try {
      final audio = await compute(WavFile.open, path);
      if (!mounted) return;
      setState(() {
        _audio = audio;
        _range = RangeValues(0, audio.frames / audio.sampleRate);
      });
    } catch (error) {
      assert(() {
        debugPrint('Cannot open recording for editing: $error');
        return true;
      }());
      if (mounted) setState(() => _error = '녹음 파일을 열지 못했어요.');
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
      setState(() => _error = '소리 이름을 조금 더 짧게 입력해 주세요.');
      return;
    }
    if (end <= start || _range.end - _range.start > WavFile.maxPreviewSeconds) {
      setState(() => _error = '0초보다 길고 5분 이하인 구간을 골라 주세요.');
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
      final directory = _scratch ??= await Directory.systemTemp.createTemp(
        'beats_clip_',
      );
      final output = File.fromUri(directory.uri.resolve('selection.wav'));
      final outputPath = output.path;
      await compute(_renderSelection, (
        path: outputPath,
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
        await _player.play(DeviceFileSource(outputPath, mimeType: 'audio/wav'));
      }
    } on FormatException {
      if (mounted) {
        setState(() => _error = '편집한 소리가 5분 이내가 되도록 구간을 더 짧게 골라 주세요.');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _error = save ? '다듬은 소리를 저장하지 못했어요.' : '선택한 구간을 재생하지 못했어요.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disposePreview() async {
    try {
      await _player.dispose();
      await _scratch?.delete(recursive: true);
    } on FileSystemException {
      // A preview can be discarded by the operating system at any time.
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
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('녹음 다듬기')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (audio == null && _error == null)
              const LinearProgressIndicator(),
            if (audio != null) ...[
              Text(
                '${_range.start.toStringAsFixed(2)}초 ~ ${_range.end.toStringAsFixed(2)}초',
              ),
              RangeSlider(
                values: _range,
                max: audio.frames / audio.sampleRate,
                onChanged: _busy || _playing
                    ? null
                    : (value) => setState(() => _range = value),
              ),
              Text('음 높이 ${_semitones > 0 ? '+' : ''}$_semitones 반음'),
              Slider(
                min: -12,
                max: 12,
                divisions: 24,
                label: '$_semitones 반음',
                value: _semitones.toDouble(),
                onChanged: _busy || _playing
                    ? null
                    : (value) => setState(() => _semitones = value.round()),
              ),
              const Text('음을 높이면 짧아지고, 낮추면 길어져요.'),
              TextField(
                controller: _name,
                maxLength: 24,
                decoration: const InputDecoration(labelText: '소리 이름 (선택)'),
                enabled: !_busy,
              ),
              Wrap(
                spacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: _busy ? null : () => _useSelection(save: false),
                    child: Text(_playing ? '재생 정지' : '미리 듣기'),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : () => _useSelection(save: true),
                    child: const Text('다듬은 소리 저장'),
                  ),
                ],
              ),
            ],
            if (_busy) const LinearProgressIndicator(),
            if (_error case final message?) Text(message),
          ],
        ),
      ),
    );
  }
}

void _renderSelection(
  ({String path, WavFile audio, int start, int end, int semitones}) selection,
) {
  final audio = selection.audio;
  WavFile.write(
    selection.path,
    audio.sampleRate,
    audio.edit(selection.start, selection.end, selection.semitones),
  );
}
