import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:everyday_beats/library_files_native.dart';
import 'package:everyday_beats/ai_arranger.dart';
import 'package:everyday_beats/main.dart';
import 'package:everyday_beats/recording_store.dart';
import 'package:everyday_beats/track_editor_page.dart';
import 'package:everyday_beats/wav_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/mock_audio_channels.dart';

void main() {
  testWidgets('AI Studio uses an OpenAI key and opens the arrangement', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 960);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    FlutterSecureStorage.setMockInitialValues({
      'studio_preferences': '{"language":"en","aiProvider":"claude"}',
      'gemini_api_key': 'legacy-gemini-key',
      'claude_api_key': 'legacy-claude-key',
    });
    mockAudioChannels(tester);

    final directory = Directory.systemTemp.createTempSync('beats_ai_test_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final clips = Directory.fromUri(directory.uri.resolve('clips/'))
      ..createSync();
    const clipId = 'clip_123.wav';
    WavFile.write(
      File.fromUri(clips.uri.resolve(clipId)).path,
      44100,
      Int16List(44100),
    );

    final requests = <({String? authorization, Object? body})>[];
    final server = (await tester.runAsync(() async {
      final local = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      local.listen((request) async {
        requests.add((
          authorization: request.headers.value(HttpHeaders.authorizationHeader),
          body: jsonDecode(await utf8.decoder.bind(request).join()),
        ));
        request.response.write(jsonEncode(_openAiResponse()));
        await request.response.close();
      });
      return local;
    }))!;
    addTearDown(() => server.close(force: true));

    await HttpOverrides.runWithHttpOverrides(() async {
      await tester.pumpWidget(
        BeatTakeApp(
          openRecordings: () async =>
              RecordingStore(LocalLibraryFiles(directory)),
          createArranger: () => AiArranger(
            endpoint: Uri.http('127.0.0.1:${server.port}', '/v1/responses'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('AI Studio').first);
      await _waitFor(
        tester,
        find.text('Add your OpenAI API key in Settings first.'),
      );
      expect(requests, isEmpty);

      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();
      expect(find.text('AI service'), findsNothing);
      final input = find.widgetWithText(TextField, 'OpenAI API key');
      await tester.ensureVisible(input);
      await tester.enterText(input, 'openai-only');
      final saveKey = find.text('Save key');
      await tester.ensureVisible(saveKey);
      await tester.tap(saveKey);
      await tester.pumpAndSettle();
      expect(
        find.text('Your OpenAI key is saved on this device.'),
        findsOneWidget,
      );

      await tester.tap(find.text('AI Studio').first);
      final clip = find.text('Clip 1');
      await _waitFor(tester, clip);
      await tester.tap(clip);
      await tester.pump();
      await tester.tap(find.text('Make arrangement'));

      final editor = find.byType(TrackEditorPage);
      await _waitFor(tester, editor);
      final placement = tester
          .widget<TrackEditorPage>(editor)
          .arrangement
          .single;
      expect(placement.clipId, clipId);
      expect(placement.track, 2);
      expect(placement.startMs, 200);
      final request = requests.single;
      expect(request.authorization, 'Bearer openai-only');
      final payload = request.body! as Map<String, dynamic>;
      expect(jsonEncode(payload), contains('Clip 1'));
      expect(jsonEncode(payload), isNot(contains(clipId)));
      expect(payload['model'], 'gpt-6-luna');
      expect(payload['store'], false);
      expect(payload['text']['format']['strict'], true);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }, _LocalHttp());
  });
}

Map<String, Object> _openAiResponse() => {
  'status': 'completed',
  'output': [
    {'type': 'reasoning'},
    {
      'type': 'message',
      'content': [
        {
          'type': 'output_text',
          'text': jsonEncode({
            'placements': [
              {'clipId': 'sound1', 'track': 2, 'startMs': 200},
            ],
          }),
        },
      ],
    },
  ],
};

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100 && finder.evaluate().isEmpty; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(finder, findsOneWidget);
  await tester.pump(const Duration(milliseconds: 350));
}

class _LocalHttp extends HttpOverrides {}
