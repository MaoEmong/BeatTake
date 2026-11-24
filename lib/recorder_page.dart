import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import 'clip_editor_page.dart';
import 'copy.dart';
import 'recording_store.dart';
import 'sounds_page.dart';
import 'studio_widgets.dart';

class RecorderPage extends StatefulWidget {
  const RecorderPage({
    super.key,
    required this.store,
    required this.openEditor,
  });

  final RecordingStore store;
  final bool openEditor;

  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  final _recorder = AudioRecorder();
  final _clock = Stopwatch();
  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<RecordState> _captureStates;
  late final StreamSubscription<RecordStop> _captureStops;
  StreamSubscription<Amplitude>? _meter;
  Timer? _ticker;
  File? _draft;
  List<double> _levels = [];
  bool _busy = false;
  bool _startingCapture = false;
  bool _leftDuringStart = false;
  bool _interruptedDuringStart = false;
  bool _hasRecording = false;
  L? _status;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.resumed) return;
        if (_startingCapture) _leftDuringStart = true;
        if (_draft != null && !_busy) unawaited(_finish());
      },
    );
    _captureStates = _recorder.onStateChanged().listen((state) {
      if (state == RecordState.pause) _captureInterrupted();
    }, onError: (Object _) {});
    _captureStops = _recorder.onStopped().listen((stop) {
      if (stop.reason != RecordStopReason.stop) _captureInterrupted();
    });
  }

  void _captureInterrupted() {
    if (!mounted) return;
    if (_startingCapture) {
      _interruptedDuringStart = true;
    } else if (_draft != null && !_busy) {
      unawaited(_finish(interrupted: true));
    }
  }

  Future<void> _start() async {
    if (_busy || _draft != null) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) setState(() => _status = L.micPermission);
        return;
      }
      if (!mounted) return;
      _startingCapture = true;
      _leftDuringStart = false;
      _interruptedDuringStart = false;
      final file = widget.store.newDraft();
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: file.path,
      );
      if (!mounted) return;
      _clock
        ..reset()
        ..start();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      setState(() {
        _draft = file;
        _levels = [];
      });
      _meter = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 85))
          .listen((value) {
            if (!mounted ||
                _draft == null ||
                _busy ||
                !value.current.isFinite) {
              return;
            }
            final level = ((value.current + 55) / 55)
                .clamp(0.0, 1.0)
                .toDouble();
            setState(
              () => _levels = [
                ..._levels.skip(_levels.length >= 48 ? 1 : 0),
                level,
              ],
            );
          }, onError: (Object _) {});
    } catch (error) {
      debugPrint('Recording could not start: $error');
      if (mounted) setState(() => _status = L.recordStartError);
    } finally {
      _startingCapture = false;
      if (mounted) {
        setState(() => _busy = false);
        if (_draft != null &&
            (_leftDuringStart ||
                _interruptedDuringStart ||
                _lifecycleState != AppLifecycleState.resumed)) {
          unawaited(_finish(interrupted: _interruptedDuringStart));
        }
      }
    }
  }

  AppLifecycleState? get _lifecycleState =>
      WidgetsBinding.instance.lifecycleState;

  Future<void> _finish({
    bool fromButton = false,
    bool leave = false,
    bool interrupted = false,
  }) async {
    final draft = _draft;
    if (draft == null || _busy) return;
    _ticker?.cancel();
    _clock.stop();
    setState(() {
      _busy = true;
      _status = L.saving;
    });
    SavedRecording? recording;
    try {
      await _meter?.cancel();
      _meter = null;
      await _recorder.stop();
      recording = await widget.store.save(draft);
      if (mounted) {
        setState(() {
          _hasRecording = true;
          _status = interrupted ? L.recordInterrupted : L.recordSaved;
        });
      }
    } catch (error) {
      debugPrint('Recording could not be saved: $error');
      if (mounted) setState(() => _status = L.recordSaveError);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _draft = null;
        });
      }
    }
    if (!mounted || recording == null) return;
    if (leave || (fromButton && !widget.openEditor)) {
      Navigator.pop(context, SoundTab.originals);
    } else if (fromButton && _lifecycleState == AppLifecycleState.resumed) {
      final original = recording;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ClipEditorPage(recording: original, store: widget.store),
        ),
      );
      if (mounted && saved == true) Navigator.pop(context, SoundTab.clips);
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _ticker?.cancel();
    unawaited(_captureStates.cancel());
    unawaited(_captureStops.cancel());
    unawaited(_meter?.cancel());
    unawaited(_recorder.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recording = _draft != null;
    final seconds = _clock.elapsed.inSeconds;
    final time =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return PopScope<SoundTab>(
      canPop: !_busy && !recording,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && recording && !_busy) unawaited(_finish(leave: true));
      },
      child: Scaffold(
        appBar: AppBar(title: Text(L.recordTitle(context))),
        body: SafeArea(
          child: StudioList(
            children: [
              const SizedBox(height: 32),
              StudioPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 9,
                          color: recording
                              ? const Color(0xffffa892)
                              : studioAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (recording ? L.recordingNow : L.readyRecord)(
                              context,
                            ),
                            style: const TextStyle(color: studioAccent),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Waveform(levels: _levels, height: 158),
                  ],
                ),
              ),
              if (_status case final status?)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(status(context)),
                  ),
                ),
              if (_hasRecording && !recording)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.pop(context, SoundTab.originals),
                  child: Text(L.viewSounds(context)),
                ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              key: const ValueKey('record-button'),
              onPressed: _busy
                  ? null
                  : recording
                  ? () => _finish(fromButton: true)
                  : _start,
              icon: Icon(recording ? Icons.stop_rounded : Icons.mic_rounded),
              label: Text(
                (recording ? L.stopRecording : L.startRecording)(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
