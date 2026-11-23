import 'dart:convert';
import 'dart:io';

import 'song.dart';

class SavedSong {
  SavedSong({
    required this.id,
    required this.name,
    required this.updatedAt,
    required List<SoundPlacement> placements,
  }) : placements = List.unmodifiable(placements);

  final String id;
  final String name;
  final DateTime updatedAt;
  final List<SoundPlacement> placements;
}

class SongStore {
  SongStore(Directory recordings)
    : _directory = Directory.fromUri(recordings.uri.resolve('songs/'));

  static final _songFile = RegExp(r'^song_(\d+)\.json$');
  static final _songId = RegExp(r'^\d+$');
  final Directory _directory;

  Future<List<SavedSong>> list() async {
    await _directory.create(recursive: true);
    final songs = <SavedSong>[];
    await for (final entry in _directory.list(followLinks: false)) {
      if (entry is! File) continue;
      final match = _songFile.firstMatch(entry.uri.pathSegments.last);
      if (match == null) continue;
      final body = jsonDecode(await entry.readAsString());
      if (body case {
        'version': 1,
        'name': final String name,
        'updatedAt': final int updatedAt,
        'placements': final List<Object?> placements,
      } when name.isNotEmpty && placements.length <= SoundPlacement.maxCount) {
        songs.add(
          SavedSong(
            id: match.group(1)!,
            name: name,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
            placements: placements.map(SoundPlacement.fromJson).toList(),
          ),
        );
      } else {
        throw const FormatException('Invalid saved song');
      }
    }
    return songs..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<SavedSong> save({
    String? id,
    required String name,
    required List<SoundPlacement> placements,
  }) async {
    final title = name.trim();
    if (title.isEmpty || placements.length > SoundPlacement.maxCount) {
      throw const FormatException('Invalid song');
    }
    final now = DateTime.now();
    final song = SavedSong(
      id: id ?? now.microsecondsSinceEpoch.toString(),
      name: title,
      updatedAt: now,
      placements: placements,
    );
    final file = _file(song.id);
    final body = jsonEncode({
      'version': 1,
      'name': song.name,
      'updatedAt': song.updatedAt.millisecondsSinceEpoch,
      'placements': song.placements
          .map((placement) => placement.toJson())
          .toList(),
    });
    await _directory.create(recursive: true);
    final draft = await _directory.createTemp('draft_');
    try {
      final temporary = File.fromUri(draft.uri.resolve('song.json'));
      await temporary.writeAsString(body, flush: true);
      await temporary.rename(file.path);
    } finally {
      await draft.delete(recursive: true);
    }
    return song;
  }

  Future<void> delete(SavedSong song) async {
    await _file(song.id).delete();
  }

  Future<bool> usesClip(String id) async {
    return (await list()).any(
      (song) => song.placements.any((placement) => placement.clipId == id),
    );
  }

  File _file(String id) {
    if (!_songId.hasMatch(id)) throw const FormatException('Invalid song ID');
    return File.fromUri(_directory.uri.resolve('song_$id.json'));
  }
}
