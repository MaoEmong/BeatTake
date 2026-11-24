import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:everyday_beats/ai_arranger.dart';
import 'package:everyday_beats/ai_provider.dart';
import 'package:everyday_beats/main.dart';
import 'package:everyday_beats/recording_store.dart';
import 'package:everyday_beats/track_editor_page.dart';
import 'package:everyday_beats/wav_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'settings route each key and request to the chosen service and open its arrangement',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(420, 960);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      FlutterSecureStorage.setMockInitialValues({});
      _mockAudioChannels(tester);

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

      final requests =
          <
            ({String path, List<String?> keys, String? version, Object? body})
          >[];
      final server = (await tester.runAsync(() async {
        final local = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        local.listen((request) async {
          requests.add((
            path: request.uri.path,
            keys: [
              request.headers.value('x-goog-api-key'),
              request.headers.value('x-api-key'),
              request.headers.value(HttpHeaders.authorizationHeader),
            ],
            version: request.headers.value('anthropic-version'),
            body: jsonDecode(await utf8.decoder.bind(request).join()),
          ));
          final provider = AiProvider.values.byName(
            request.uri.pathSegments.last,
          );
          request.response.write(jsonEncode(_response(provider)));
          await request.response.close();
        });
        return local;
      }))!;
      addTearDown(() => server.close(force: true));

      await HttpOverrides.runWithHttpOverrides(() async {
        await tester.pumpWidget(
          BeatTakeApp(
            openRecordings: () async => RecordingStore(directory),
            arrangerFor: (provider) => AiArranger.forEndpoint(
              provider,
              Uri.http('127.0.0.1:${server.port}', '/${provider.name}'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final provider in AiProvider.values) {
          await tester.tap(find.text('Settings').first);
          await tester.pumpAndSettle();
          final picker = find.byType(DropdownButtonFormField<AiProvider>);
          await tester.ensureVisible(picker);
          await tester.tap(picker);
          await tester.pumpAndSettle();
          await tester.tap(find.text(provider.label).last);
          await tester.pumpAndSettle();

          await tester.tap(find.text('AI Studio').first);
          await _waitFor(
            tester,
            find.text('Add your ${provider.label} API key in Settings first.'),
          );
          expect(requests, hasLength(provider.index));

          await tester.tap(find.text('Settings').first);
          await tester.pumpAndSettle();
          final input = find.widgetWithText(
            TextField,
            '${provider.label} API key',
          );
          await tester.ensureVisible(input);
          await tester.enterText(input, '${provider.name}-only');
          final saveKey = find.text('Save key');
          await tester.ensureVisible(saveKey);
          await tester.tap(saveKey);
          await tester.pumpAndSettle();
          expect(
            find.text('Your ${provider.label} key is saved on this device.'),
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
          expect(placement.track, provider.index);
          expect(placement.startMs, provider.index * 100);
          expect(requests, hasLength(provider.index + 1));
          final request = requests.last;
          expect(request.path, '/${provider.name}');
          expect(request.keys, switch (provider) {
            AiProvider.gemini => ['gemini-only', null, null],
            AiProvider.claude => [null, 'claude-only', null],
            AiProvider.openai => [null, null, 'Bearer openai-only'],
          });
          expect(
            request.version,
            provider == AiProvider.claude ? '2023-06-01' : null,
          );
          final payload = request.body! as Map<String, dynamic>;
          expect(jsonEncode(payload), contains('Clip 1'));
          expect(jsonEncode(payload), isNot(contains(clipId)));
          switch (provider) {
            case AiProvider.gemini:
              expect(
                payload['generationConfig']['responseJsonSchema']['type'],
                'object',
              );
            case AiProvider.claude:
              expect(payload['model'], 'claude-haiku-5-5');
              expect(payload['output_config']['format']['type'], 'json_schema');
            case AiProvider.openai:
              expect(payload['model'], 'gpt-6-luna');
              expect(payload['store'], false);
              expect(payload['text']['format']['strict'], true);
          }
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
        }
      }, _LocalHttp());
    },
  );
}

Map<String, Object> _response(AiProvider provider) {
  final text = jsonEncode({
    'placements': [
      {
        'clipId': 'sound1',
        'track': provider.index,
        'startMs': provider.index * 100,
      },
    ],
  });
  return switch (provider) {
    AiProvider.gemini => {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text},
            ],
          },
        },
      ],
    },
    AiProvider.claude => {
      'stop_reason': 'end_turn',
      'content': [
        {'type': 'thinking', 'thinking': 'test thought'},
        {'type': 'text', 'text': text},
      ],
    },
    AiProvider.openai => {
      'status': 'completed',
      'output': [
        {'type': 'reasoning'},
        {
          'type': 'message',
          'content': [
            {'type': 'output_text', 'text': text},
          ],
        },
      ],
    },
  };
}

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

void _mockAudioChannels(WidgetTester tester) {
  final messenger = tester.binding.defaultBinaryMessenger;
  for (final name in [
    'xyz.luan/audioplayers.global',
    'xyz.luan/audioplayers.global/events',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
  }
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (call) async {
      if (call.method == 'create') {
        final player = call.arguments['playerId'];
        messenger.setMockMethodCallHandler(
          MethodChannel('xyz.luan/audioplayers/events/$player'),
          (_) async => null,
        );
      }
      return null;
    },
  );
}

class _LocalHttp extends HttpOverrides {}
