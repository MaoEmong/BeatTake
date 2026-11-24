import 'dart:convert';
import 'dart:io';

import 'package:everyday_beats/ai_arranger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OpenAI suggestions resolve to selected local clips only', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final keys = <String?>[];
    final bodies = <String>[];
    server.listen((request) async {
      keys.add(request.headers.value(HttpHeaders.authorizationHeader));
      bodies.add(await utf8.decoder.bind(request).join());
      final alias = bodies.length == 1 ? 'sound1' : 'unknown';
      request.response.write(
        jsonEncode({
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
                      {'clipId': alias, 'track': 0, 'startMs': 0},
                    ],
                  }),
                },
              ],
            },
          ],
        }),
      );
      await request.response.close();
    });
    final arranger = AiArranger(
      endpoint: Uri.parse('http://127.0.0.1:${server.port}/arrange'),
    );
    const sounds = [
      (clipId: 'clip_1_private_filename.wav', name: '책상', durationMs: 500),
    ];
    final placements = await arranger.arrange(
      key: 'test-key',
      sounds: sounds,
      request: '경쾌하게',
    );
    expect(placements.single.clipId, sounds.single.clipId);
    expect(placements.single.startMs, 0);
    expect(keys.single, 'Bearer test-key');
    expect(bodies.single, contains('책상'));
    expect(bodies.single, isNot(contains(sounds.single.clipId)));
    await expectLater(
      arranger.arrange(key: 'test-key', sounds: sounds, request: ''),
      throwsA(isA<ArrangementException>()),
    );
  });
}
