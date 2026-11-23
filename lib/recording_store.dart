import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SavedRecording {
  const SavedRecording({
    required this.file,
    required this.recordedAt,
    this.name,
  });

  final File file;
  final DateTime recordedAt;
  final String? name;

  String get id => file.uri.pathSegments.last;
}

class RecordingStore {
  RecordingStore(this.directory);

  static final _recordingName = RegExp(r'^recording_(\d+)\.wav$');
  static final _draftName = RegExp(r'^draft_(\d+)\.wav$');
  static final _clipName = RegExp(r'^clip_(\d+)(?:_([A-Za-z0-9_-]+))?\.wav$');

  final Directory directory;

  static Future<RecordingStore> open() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory.fromUri(documents.uri.resolve('recordings/'));
    await directory.create(recursive: true);
    return RecordingStore(directory);
  }

  File newDraft() {
    final id = DateTime.now().microsecondsSinceEpoch;
    return File.fromUri(directory.uri.resolve('draft_$id.wav'));
  }

  Future<SavedRecording> save(File draft) async {
    final match = _draftName.firstMatch(draft.uri.pathSegments.last);
    if (draft.parent.uri != directory.uri || match == null) {
      throw ArgumentError.value(draft.path, 'draft', 'Unknown recording draft');
    }
    if (await draft.length() <= 44) {
      throw const FileSystemException('Recording contains no audio');
    }

    // Publish the recording only after the recorder has closed the WAV file.
    final id = int.parse(match.group(1)!);
    final destination = File.fromUri(
      directory.uri.resolve('recording_$id.wav'),
    );
    final file = await draft.rename(destination.path);
    return SavedRecording(
      file: file,
      recordedAt: DateTime.fromMicrosecondsSinceEpoch(id),
    );
  }

  Future<List<SavedRecording>> list() async {
    return _list(directory, _recordingName);
  }

  Future<List<SavedRecording>> listClips() async {
    return _list(await _clipDirectory(), _clipName);
  }

  Future<void> delete(SavedRecording sound, {required bool edited}) async {
    final folder = edited ? await _clipDirectory() : directory;
    final pattern = edited ? _clipName : _recordingName;
    if (sound.file.parent.uri != folder.uri || !pattern.hasMatch(sound.id)) {
      throw ArgumentError.value(sound.id, 'sound', 'Unknown sound');
    }
    await sound.file.delete();
  }

  Future<void> saveClip(File preview, String name) async {
    final clips = await _clipDirectory();
    final id = DateTime.now().microsecondsSinceEpoch;
    final label = name.trim();
    final encoded = base64Url.encode(utf8.encode(label)).replaceAll('=', '');
    final suffix = label.isEmpty ? '' : '_$encoded';
    final draft = File.fromUri(clips.uri.resolve('draft_$id.wav'));
    final destination = File.fromUri(clips.uri.resolve('clip_$id$suffix.wav'));
    try {
      await preview.copy(draft.path);
      await draft.rename(destination.path);
    } finally {
      if (await draft.exists()) await draft.delete();
    }
  }

  Future<Directory> _clipDirectory() {
    return Directory.fromUri(directory.uri.resolve('clips/')).create();
  }

  Future<List<SavedRecording>> _list(Directory folder, RegExp pattern) async {
    final recordings = <SavedRecording>[];
    await for (final entry in folder.list(followLinks: false)) {
      if (entry is! File) {
        continue;
      }
      final match = pattern.firstMatch(entry.uri.pathSegments.last);
      if (match == null || await entry.length() <= 44) {
        continue;
      }
      final encodedName = match.groupCount == 2 ? match.group(2) : null;
      String? name;
      if (encodedName != null) {
        try {
          name = utf8.decode(
            base64Url.decode(base64Url.normalize(encodedName)),
          );
        } on FormatException {
          continue;
        }
      }
      recordings.add(
        SavedRecording(
          file: entry,
          recordedAt: DateTime.fromMicrosecondsSinceEpoch(
            int.parse(match.group(1)!),
          ),
          name: name,
        ),
      );
    }
    recordings.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return recordings;
  }
}
