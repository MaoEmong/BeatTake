import 'dart:convert';
import 'dart:typed_data';

import 'library_files.dart';
import 'song_store.dart';

typedef RecordingDraft = ({String key, String path});

class ClipInUse implements Exception {
  const ClipInUse();
}

class SavedRecording {
  const SavedRecording({
    required this.key,
    required this.recordedAt,
    this.name,
  });

  final String key;
  final DateTime recordedAt;
  final String? name;

  String get id => key.split('/').last;
}

class RecordingStore {
  RecordingStore(this.files);

  static final _recordingName = RegExp(r'^recording_(\d+)\.wav$');
  static final _draftName = RegExp(r'^draft_(\d+)\.wav$');
  static final _clipName = RegExp(r'^clip_(\d+)(?:_([A-Za-z0-9_-]+))?\.wav$');

  final LibraryFiles files;

  static Future<RecordingStore> open() async =>
      RecordingStore(await LibraryFiles.open());

  RecordingDraft newDraft() {
    final id = DateTime.now().microsecondsSinceEpoch;
    final key = 'draft_$id.wav';
    return (key: key, path: files.draftPath(key));
  }

  Future<SavedRecording> save(RecordingDraft draft, {String? result}) async {
    final match = _draftName.firstMatch(draft.key);
    if (draft.path != files.draftPath(draft.key) || match == null) {
      throw ArgumentError.value(draft.key, 'draft', 'Unknown recording draft');
    }

    // Publish the recording only after the recorder has closed the WAV file.
    final id = int.parse(match.group(1)!);
    final key = 'recording_$id.wav';
    await files.publishRecording(draft.key, key, result);
    return SavedRecording(
      key: key,
      recordedAt: DateTime.fromMicrosecondsSinceEpoch(id),
    );
  }

  Future<List<SavedRecording>> list() async {
    return _list('', _recordingName);
  }

  Future<List<SavedRecording>> listClips() async {
    return _list('clips/', _clipName);
  }

  Future<void> delete(SavedRecording sound, {required bool edited}) async {
    final folder = edited ? 'clips/' : '';
    final pattern = edited ? _clipName : _recordingName;
    if (sound.key != '$folder${sound.id}' || !pattern.hasMatch(sound.id)) {
      throw ArgumentError.value(sound.id, 'sound', 'Unknown sound');
    }
    await files.update(() async {
      if (edited && await SongStore(files).usesClip(sound.id)) {
        throw const ClipInUse();
      }
      await files.delete(sound.key);
    });
  }

  Future<void> saveClip(Uint8List preview, String name) async {
    final id = DateTime.now().microsecondsSinceEpoch;
    final label = name.trim();
    final encoded = base64Url.encode(utf8.encode(label)).replaceAll('=', '');
    final suffix = label.isEmpty ? '' : '_$encoded';
    await files.write('clips/clip_$id$suffix.wav', preview);
  }

  Future<List<SavedRecording>> _list(String prefix, RegExp pattern) async {
    final recordings = <SavedRecording>[];
    for (final key in await files.list(prefix, minLength: 45)) {
      final match = pattern.firstMatch(key.substring(prefix.length));
      if (match == null) continue;
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
          key: key,
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
