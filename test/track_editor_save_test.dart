import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:everyday_beats/recording_store.dart';
import 'package:everyday_beats/song.dart';
import 'package:everyday_beats/song_store.dart';
import 'package:everyday_beats/track_editor_page.dart';
import 'package:everyday_beats/wav_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/mock_audio_channels.dart';

void main() {
  testWidgets('two quick Save taps write once and return to the library', (
    tester,
  ) async {
    mockAudioChannels(tester);
    final directory = Directory.systemTemp.createTempSync('beats_save_test_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File.fromUri(directory.uri.resolve('clip_123.wav'));
    WavFile.write(file.path, 44100, Int16List(44100));
    final store = _SlowSongStore(directory);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => TrackEditorPage(
                    clips: [
                      SavedRecording(file: file, recordedAt: DateTime.now()),
                    ],
                    store: store,
                    arrangement: [
                      SoundPlacement(
                        clipId: 'clip_123.wav',
                        track: 0,
                        startMs: 0,
                      ),
                    ],
                  ),
                ),
              ),
              child: const Text('Open song editor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open song editor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField), 'Two quick taps');
    await tester.pump();

    final save = find.text('Save');
    await tester.tap(save);
    await tester.tap(save);
    store.finishSave.complete();
    await tester.pumpAndSettle();

    expect(store.saveCalls, 1);
    expect(find.text('Open song editor'), findsOneWidget);
  });
}

class _SlowSongStore extends SongStore {
  _SlowSongStore(super.recordings);

  final finishSave = Completer<void>();
  int saveCalls = 0;

  @override
  Future<SavedSong> save({
    String? id,
    required String name,
    required List<SoundPlacement> placements,
  }) async {
    saveCalls++;
    await finishSave.future;
    return SavedSong(
      id: id ?? '1',
      name: name,
      updatedAt: DateTime.now(),
      placements: placements,
    );
  }
}
