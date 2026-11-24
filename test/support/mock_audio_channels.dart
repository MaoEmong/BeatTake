import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void mockAudioChannels(WidgetTester tester) {
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
