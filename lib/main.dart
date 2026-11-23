import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import 'ai_settings_page.dart';
import 'clip_editor_page.dart';
import 'recording_store.dart';
import 'song_store.dart';
import 'songs_page.dart';

void main() => runApp(const EverydayBeatsApp());

class EverydayBeatsApp extends StatelessWidget {
  const EverydayBeatsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Everyday Beats',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC8F578),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF111410),
      ),
      home: const RecordingsPage(),
    );
  }
}

class RecordingsPage extends StatefulWidget {
  const RecordingsPage({super.key});

  @override
  State<RecordingsPage> createState() => _RecordingsPageState();
}

class _RecordingsPageState extends State<RecordingsPage> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _clock = Stopwatch();

  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<void> _playbackComplete;
  RecordingStore? _store;
  File? _activeDraft;
  Timer? _ticker;
  String? _playingPath;
  List<SavedRecording> _recordings = [];
  List<SavedRecording> _clips = [];
  bool _busy = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onPause: () {
        if (_activeDraft != null && !_busy) {
          unawaited(_finishRecording());
        }
      },
    );
    _playbackComplete = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _playingPath = null);
      }
    });
    unawaited(_loadRecordings());
  }

  Future<void> _loadRecordings() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final store = await RecordingStore.open();
      final recordings = await store.list();
      final clips = await store.listClips();
      if (mounted) {
        setState(() {
          _store = store;
          _recordings = recordings;
          _clips = clips;
        });
      }
    } catch (error, stack) {
      debugPrint('Cannot load recordings: $error\n$stack');
      if (mounted) {
        setState(() => _status = '저장된 녹음을 불러오지 못했어요.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _startRecording() async {
    final store = _store;
    if (_busy || _activeDraft != null || store == null) {
      return;
    }

    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          setState(() => _status = '녹음하려면 설정에서 마이크 사용을 허용해 주세요.');
        }
        return;
      }

      await _player.stop();
      if (!mounted) return;
      setState(() => _playingPath = null);

      final draft = store.newDraft();
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: draft.path,
      );
      if (!mounted) return;
      _clock
        ..reset()
        ..start();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      setState(() => _activeDraft = draft);
    } catch (error, stack) {
      debugPrint('Cannot start recording: $error\n$stack');
      if (mounted) {
        setState(() => _status = '녹음을 시작하지 못했어요. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_activeDraft != null &&
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.paused) {
          unawaited(_finishRecording());
        }
      }
    }
  }

  Future<void> _finishRecording() async {
    final draft = _activeDraft;
    final store = _store;
    if (_busy || draft == null || store == null) {
      return;
    }

    _ticker?.cancel();
    _clock.stop();
    setState(() {
      _busy = true;
      _status = '녹음을 저장하는 중…';
    });
    try {
      await _recorder.stop();
      final recording = await store.save(draft);
      if (mounted) {
        setState(() {
          _recordings.insert(0, recording);
          _status = '휴대폰에 저장했어요.';
        });
      }
    } catch (error, stack) {
      debugPrint('Cannot finish recording: $error\n$stack');
      if (mounted) {
        setState(() => _status = '녹음을 저장하지 못했어요. 다시 녹음해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _activeDraft = null;
          _busy = false;
        });
      }
    }
  }

  Future<void> _togglePlayback(SavedRecording recording) async {
    if (_busy || _activeDraft != null) {
      return;
    }

    final path = recording.file.path;
    final shouldStop = _playingPath == path;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await _player.stop();
      if (!mounted) return;
      setState(() => _playingPath = shouldStop ? null : path);
      if (!shouldStop) {
        await _player.play(DeviceFileSource(path, mimeType: 'audio/wav'));
      }
    } catch (error, stack) {
      debugPrint('Cannot play recording: $error\n$stack');
      if (mounted) {
        setState(() {
          _playingPath = null;
          _status = '이 녹음을 재생하지 못했어요.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _editRecording(SavedRecording recording) async {
    final store = _store;
    if (_busy || _activeDraft != null || store == null) return;
    setState(() => _busy = true);
    try {
      await _player.stop();
      if (!mounted) return;
      setState(() => _playingPath = null);
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ClipEditorPage(recording: recording, store: store),
        ),
      );
      if (saved == true) {
        final clips = await store.listClips();
        if (mounted) setState(() => _clips = clips);
      }
    } catch (_) {
      if (mounted) setState(() => _status = '다듬은 소리 목록을 불러오지 못했어요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPage(Widget page, String errorMessage) async {
    if (_busy || _activeDraft != null) return;
    setState(() => _busy = true);
    try {
      await _player.stop();
      if (!mounted) return;
      setState(() => _playingPath = null);
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    } catch (_) {
      if (mounted) setState(() => _status = errorMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSound(
    SavedRecording sound, {
    required bool edited,
  }) async {
    final store = _store;
    if (store == null || _busy || _activeDraft != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(edited ? '다듬은 소리를 삭제할까요?' : '원본 녹음을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _busy = true);
    try {
      if (edited && await SongStore(store.directory).usesClip(sound.id)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('저장한 곡에서 이 소리의 배치를 먼저 지워 주세요.')),
          );
        }
        return;
      }
      if (_playingPath == sound.file.path) {
        await _player.stop();
        if (mounted) setState(() => _playingPath = null);
      }
      await store.delete(sound, edited: edited);
      if (mounted) {
        setState(() => (edited ? _clips : _recordings).remove(sound));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('소리를 삭제하지 못했어요.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _ticker?.cancel();
    unawaited(_playbackComplete.cancel());
    unawaited(_recorder.dispose());
    unawaited(_player.dispose());
    super.dispose();
  }

  String _recordingTime() {
    final elapsed = _clock.elapsed;
    final mins = elapsed.inMinutes.toString().padLeft(2, '0');
    final secs = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String _recordingDate(DateTime time) {
    final date = MaterialLocalizations.of(context).formatMediumDate(time);
    final clock = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(time),
      alwaysUse24HourFormat: true,
    );
    return '$date · $clock';
  }

  Widget _soundTile(
    SavedRecording sound,
    String title, {
    bool editable = false,
  }) {
    final enabled = !_busy && _activeDraft == null;
    final playing = _playingPath == sound.file.path;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        key: ValueKey(sound.file.path),
        title: Text(sound.name ?? title),
        subtitle: Text(_recordingDate(sound.recordedAt)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (editable)
              IconButton(
                tooltip: '녹음 다듬기',
                icon: const Icon(Icons.content_cut),
                onPressed: enabled ? () => _editRecording(sound) : null,
              ),
            IconButton(
              tooltip: playing ? '재생 정지' : '재생',
              isSelected: playing,
              icon: const Icon(Icons.play_arrow_rounded),
              selectedIcon: const Icon(Icons.stop_rounded),
              onPressed: enabled ? () => _togglePlayback(sound) : null,
            ),
            IconButton(
              tooltip: '소리 삭제',
              icon: const Icon(Icons.delete_outline),
              onPressed: enabled
                  ? () => _deleteSound(sound, edited: !editable)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final store = _store;
    final isRecording = _activeDraft != null;
    final recordColor = isRecording
        ? const Color(0xFFFF9485)
        : const Color(0xFFC8F578);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Everyday Beats'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '내 곡',
            onPressed: _busy || isRecording || store == null
                ? null
                : () => _openPage(
                    SongsPage(clips: _clips, store: SongStore(store.directory)),
                    '곡 목록을 열지 못했어요.',
                  ),
            icon: const Icon(Icons.library_music_outlined),
          ),
          IconButton(
            tooltip: 'AI 설정',
            onPressed: _busy || isRecording
                ? null
                : () => _openPage(const AiSettingsPage(), 'AI 설정을 열지 못했어요.'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Built for Vibe Forge by Everyday Beats',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: SizedBox(
              width: 640,
              height: constraints.maxHeight,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C2219),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            '소리 녹음',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            key: const ValueKey('record-button'),
                            onPressed: _busy || _store == null
                                ? null
                                : isRecording
                                ? _finishRecording
                                : _startRecording,
                            style: FilledButton.styleFrom(
                              backgroundColor: recordColor,
                              foregroundColor: const Color(0xFF171B14),
                              fixedSize: const Size(88, 88),
                              shape: const CircleBorder(),
                              padding: EdgeInsets.zero,
                            ),
                            child: Icon(
                              isRecording
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded,
                              size: 36,
                              semanticLabel: isRecording ? '녹음 정지' : '녹음 시작',
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            isRecording ? _recordingTime() : '녹음 시작',
                            style: theme.textTheme.titleMedium,
                          ),
                          if (_status case final status?) ...[
                            const SizedBox(height: 10),
                            Semantics(
                              liveRegion: true,
                              child: Text(status, textAlign: TextAlign.center),
                            ),
                          ],
                          if (_store == null && !_busy)
                            TextButton(
                              onPressed: _loadRecordings,
                              child: const Text('다시 불러오기'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('저장한 녹음', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (_recordings.isEmpty && _store != null)
                    Text(
                      '녹음을 마치면 여기에 표시돼요.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  for (final (index, recording) in _recordings.indexed)
                    _soundTile(
                      recording,
                      '녹음 ${_recordings.length - index}',
                      editable: true,
                    ),
                  const SizedBox(height: 28),
                  Text('다듬은 소리', style: theme.textTheme.titleLarge),
                  if (_clips.isEmpty) const Text('녹음을 다듬어 저장하면 여기에 표시돼요.'),
                  for (final (index, clip) in _clips.indexed)
                    _soundTile(clip, '다듬은 소리 ${_clips.length - index}'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
