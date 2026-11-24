import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:everyday_beats/library_files_native.dart';
import 'package:everyday_beats/recorder_page.dart';
import 'package:everyday_beats/recording_store.dart';
import 'package:everyday_beats/wav_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

void main() {
  for (final (label, duringStart, stopped) in [
    ('a native pause', false, false),
    ('an unexpected native stop', false, true),
    ('a native pause during startup', true, false),
  ]) {
    testWidgets('$label saves the take and clears the recording state', (
      tester,
    ) async {
      final native = _TestRecorder(
        startGate: duringStart ? Completer<void>() : null,
      );
      final previousPlatform = RecordPlatform.instance;
      RecordPlatform.instance = native;
      addTearDown(() {
        RecordPlatform.instance = previousPlatform;
        return native.close();
      });
      final directory = Directory.systemTemp.createTempSync(
        'beats_recorder_test_',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final store = RecordingStore(LocalLibraryFiles(directory));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(home: RecorderPage(store: store, openEditor: false)),
      );
      await tester.tap(find.text('Start recording'));
      await tester.pump();
      await tester.pump();
      expect(native.recording, isTrue);
      if (!duringStart) expect(find.text('Recording'), findsOneWidget);

      native.interrupt(stopped: stopped);
      await tester.pump();
      native.startGate?.complete();
      final savedMessage = find.text(
        'Recording was interrupted. The sound so far was saved.',
      );
      for (
        var frame = 0;
        frame < 20 && savedMessage.evaluate().isEmpty;
        frame++
      ) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.pump();

      expect(find.text('Recording'), findsNothing);
      expect(find.text('Start recording'), findsOneWidget);
      expect(savedMessage, findsOneWidget);
      expect(native.stopCalls, 1);
      final saved = (await tester.runAsync(store.list))!.single;
      expect(
        WavFile.read(
          (await tester.runAsync(() => store.files.audio(saved.key)))!,
        ).durationMs,
        1000,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}

class _TestRecorder extends RecordPlatform {
  _TestRecorder({required this.startGate});

  final Completer<void>? startGate;
  final _states = StreamController<RecordState>.broadcast();
  final _stops = StreamController<RecordStop>.broadcast();
  bool recording = false;
  int stopCalls = 0;
  String? _output;

  void interrupt({required bool stopped}) {
    recording = false;
    if (stopped) {
      _states.add(RecordState.stop);
      _stops.add(RecordStop(reason: RecordStopReason.error, path: _output));
    } else {
      _states.add(RecordState.pause);
    }
  }

  Future<void> close() async {
    await _states.close();
    await _stops.close();
  }

  @override
  Future<void> create(String recorderId) async {}

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async =>
      true;

  @override
  Future<void> start(
    String recorderId,
    RecordConfig config, {
    required String path,
  }) async {
    WavFile.write(path, 44100, Int16List(44100));
    _output = path;
    recording = true;
    _states.add(RecordState.record);
    await startGate?.future;
  }

  @override
  Stream<RecordState> onStateChanged(String recorderId) => _states.stream;

  @override
  Stream<RecordStop> onStopped(String recorderId) => _stops.stream;

  @override
  Future<bool> isRecording(String recorderId) async => recording;

  @override
  Future<Amplitude> getAmplitude(String recorderId) async =>
      Amplitude(current: -12, max: -12);

  @override
  Future<String?> stop(String recorderId) async {
    stopCalls++;
    recording = false;
    _states.add(RecordState.stop);
    _stops.add(RecordStop(reason: RecordStopReason.stop, path: _output));
    return _output;
  }

  @override
  Future<void> dispose(String recorderId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
