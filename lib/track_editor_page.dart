import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ai_arranger.dart';
import 'ai_settings_page.dart';
import 'recording_store.dart';
import 'song.dart';
import 'song_store.dart';
import 'wav_audio.dart';

class TrackEditorPage extends StatefulWidget {
  const TrackEditorPage({
    super.key,
    required this.clips,
    required this.store,
    this.song,
  });

  final List<SavedRecording> clips;
  final SongStore store;
  final SavedSong? song;

  @override
  State<TrackEditorPage> createState() => _TrackEditorPageState();
}

class _TrackEditorPageState extends State<TrackEditorPage> {
  final _player = AudioPlayer();
  late final StreamSubscription<void> _complete;
  late final List<SoundPlacement> _placements;
  late final TextEditingController _name;
  Directory? _scratch;
  bool _busy = false;
  bool _playing = false;
  String? _error;

  Map<String, String> get _clipNames => {
    for (final (index, clip) in widget.clips.indexed)
      clip.id: clip.name ?? '다듬은 소리 ${widget.clips.length - index}',
  };

  @override
  void initState() {
    super.initState();
    _placements = [...?widget.song?.placements];
    _name = TextEditingController(text: widget.song?.name ?? '');
    _complete = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  Future<void> _saveSong() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '곡 이름을 입력해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.save(
        id: widget.song?.id,
        name: name,
        placements: _placements,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = '곡을 저장하지 못했어요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _arrange() async {
    if (_busy || _playing) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final key = await AiSettingsPage.readKey();
      if (!mounted) return;
      if (key == null || key.isEmpty) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => const AiSettingsPage()),
        );
        return;
      }
      final names = _clipNames;
      final options = await showDialog<({Set<String> ids, String style})>(
        context: context,
        builder: (_) =>
            _ArrangementDialog(names: names, replacing: _placements.isNotEmpty),
      );
      if (!mounted || options == null) return;
      final selected = {
        for (final clip in widget.clips)
          if (options.ids.contains(clip.id)) clip.id: clip.file.path,
      };
      final sounds = await compute(_readArrangementSounds, (
        paths: selected,
        names: names,
      ));
      final placements = await AiArranger().arrange(
        key: key,
        sounds: sounds,
        request: options.style,
      );
      if (mounted) {
        setState(() {
          _placements
            ..clear()
            ..addAll(placements);
        });
      }
    } on ArrangementException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '등록한 키나 선택한 소리를 읽지 못했어요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePlacement([int? index]) async {
    final placement = await showDialog<SoundPlacement>(
      context: context,
      builder: (_) => _PlacementDialog(
        names: _clipNames,
        initial: index == null ? null : _placements[index],
      ),
    );
    if (!mounted || placement == null) return;
    setState(() {
      if (index == null) {
        _placements.add(placement);
      } else {
        _placements[index] = placement;
      }
      _error = null;
    });
  }

  Future<void> _togglePlayback() async {
    if (_busy || _placements.isEmpty) return;
    final wasPlaying = _playing;
    setState(() {
      _busy = true;
      _playing = false;
      _error = null;
    });
    try {
      await _player.stop();
      if (wasPlaying) return;
      final directory = _scratch ??= await Directory.systemTemp.createTemp(
        'beats_mix_',
      );
      final path = File.fromUri(directory.uri.resolve('mix.wav')).path;
      final placements = List<SoundPlacement>.of(_placements);
      final clipPaths = {
        for (final clip in widget.clips) clip.id: clip.file.path,
      };
      await compute(_renderMix, (
        placements: placements,
        paths: clipPaths,
        output: path,
      ));
      if (!mounted) return;
      setState(() => _playing = true);
      await _player.play(DeviceFileSource(path, mimeType: 'audio/wav'));
    } catch (_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _error = '곡을 재생하지 못했어요. 소리 파일이 남아 있고 곡이 5분 이내인지 확인해 주세요.';
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
    final editable = !_busy && !_playing;
    final names = _clipNames;
    final tracks =
        _placements.map((placement) => placement.track).toSet().toList()
          ..sort();
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('트랙 편집')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _name,
              maxLength: 40,
              enabled: editable,
              decoration: const InputDecoration(labelText: '곡 이름'),
            ),
            Wrap(
              spacing: 12,
              children: [
                FilledButton.tonal(
                  onPressed:
                      editable &&
                          names.isNotEmpty &&
                          _placements.length < SoundPlacement.maxCount
                      ? _changePlacement
                      : null,
                  child: const Text('소리 추가'),
                ),
                OutlinedButton(
                  onPressed: !_busy && _placements.isNotEmpty
                      ? _togglePlayback
                      : null,
                  child: Text(_playing ? '재생 정지' : '곡 재생'),
                ),
                FilledButton(
                  onPressed: editable ? _saveSong : null,
                  child: const Text('곡 저장'),
                ),
                OutlinedButton(
                  onPressed: editable && names.isNotEmpty ? _arrange : null,
                  child: const Text('AI 편곡'),
                ),
              ],
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error case final message?) Text(message),
            if (names.isEmpty) const Text('녹음을 다듬어 저장하면 곡에 추가할 수 있어요.'),
            if (names.isNotEmpty && _placements.isEmpty)
              const Text('소리를 추가하고 재생할 위치를 골라 주세요.'),
            for (final track in tracks) ...[
              const SizedBox(height: 20),
              Text(
                '트랙 ${track + 1}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final index in _placementsOnTrack(track))
                ListTile(
                  title: Text(names[_placements[index].clipId] ?? '찾을 수 없는 소리'),
                  subtitle: Text('${_placements[index].startMs / 1000}초에 시작'),
                  onTap: editable && names.isNotEmpty
                      ? () => _changePlacement(index)
                      : null,
                  trailing: IconButton(
                    tooltip: '배치 삭제',
                    onPressed: editable
                        ? () => setState(() => _placements.removeAt(index))
                        : null,
                    icon: const Icon(Icons.close),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  List<int> _placementsOnTrack(int track) => [
    for (final (index, placement) in _placements.indexed)
      if (placement.track == track) index,
  ]..sort((a, b) => _placements[a].startMs.compareTo(_placements[b].startMs));
}

List<ArrangementSound> _readArrangementSounds(
  ({Map<String, String> paths, Map<String, String> names}) input,
) {
  return input.paths.entries.map((entry) {
    final audio = WavFile.open(entry.value);
    return (
      clipId: entry.key,
      name: input.names[entry.key]!,
      durationMs: (audio.frames * 1000 / audio.sampleRate).ceil(),
    );
  }).toList();
}

void _renderMix(
  ({List<SoundPlacement> placements, Map<String, String> paths, String output})
  input,
) {
  SongMix.render(input.placements, input.paths, input.output);
}

class _ArrangementDialog extends StatefulWidget {
  const _ArrangementDialog({required this.names, required this.replacing});

  final Map<String, String> names;
  final bool replacing;

  @override
  State<_ArrangementDialog> createState() => _ArrangementDialogState();
}

class _ArrangementDialogState extends State<_ArrangementDialog> {
  late final _ids = widget.names.keys.take(AiArranger.maxSounds).toSet();
  String _style = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI로 소리 배치하기'),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('선택한 소리의 이름과 길이, 편곡 요청만 Gemini에 보내요.'),
          if (widget.replacing) const Text('만든 배치안이 편집 화면의 현재 배치를 바꿔요.'),
          const Text('편곡에 쓸 소리를 최대 12개 골라 주세요.'),
          for (final entry in widget.names.entries)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.value),
              value: _ids.contains(entry.key),
              onChanged:
                  _ids.contains(entry.key) || _ids.length < AiArranger.maxSounds
                  ? (checked) => setState(() {
                      if (checked == true) {
                        _ids.add(entry.key);
                      } else {
                        _ids.remove(entry.key);
                      }
                    })
                  : null,
            ),
          TextField(
            maxLength: 120,
            decoration: const InputDecoration(labelText: '원하는 분위기 (선택)'),
            onChanged: (text) => _style = text.trim(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _ids.isEmpty
              ? null
              : () => Navigator.pop(context, (ids: _ids, style: _style)),
          child: const Text('배치안 만들기'),
        ),
      ],
    );
  }
}

class _PlacementDialog extends StatefulWidget {
  const _PlacementDialog({required this.names, required this.initial});

  final Map<String, String> names;
  final SoundPlacement? initial;

  @override
  State<_PlacementDialog> createState() => _PlacementDialogState();
}

class _PlacementDialogState extends State<_PlacementDialog> {
  late String _clip = widget.names.containsKey(widget.initial?.clipId)
      ? widget.initial!.clipId
      : widget.names.keys.first;
  late int _track = widget.initial?.track ?? 0;
  late String _seconds = ((widget.initial?.startMs ?? 0) / 1000).toString();
  String? _error;

  void _confirm() {
    final seconds = double.tryParse(_seconds.trim().replaceAll(',', '.'));
    if (seconds == null ||
        !seconds.isFinite ||
        seconds < 0 ||
        seconds * 1000 > SoundPlacement.maxStartMs) {
      setState(() => _error = '0초 이상 300초 미만으로 입력해 주세요.');
      return;
    }
    Navigator.pop(
      context,
      SoundPlacement(
        clipId: _clip,
        track: _track,
        startMs: (seconds * 1000).round(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? '소리 추가' : '배치 수정'),
      scrollable: true,
      content: Column(
        children: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _clip,
            decoration: const InputDecoration(labelText: '소리'),
            items: [
              for (final entry in widget.names.entries)
                DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => _clip = value!,
          ),
          DropdownButtonFormField<int>(
            initialValue: _track,
            decoration: const InputDecoration(labelText: '트랙'),
            items: [
              for (var track = 0; track < SoundPlacement.trackCount; track++)
                DropdownMenuItem(value: track, child: Text('트랙 ${track + 1}')),
            ],
            onChanged: (value) => _track = value!,
          ),
          TextFormField(
            initialValue: _seconds,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '시작 시간 (초)',
              errorText: _error,
            ),
            onChanged: (text) => _seconds = text,
            onFieldSubmitted: (_) => _confirm(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('적용')),
      ],
    );
  }
}
