import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'library_files.dart';
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
  SongStore(this.files);

  static final _songFile = RegExp(r'^song_(\d+)\.json$');
  static final _songId = RegExp(r'^\d+$');
  static const _maxDateMilliseconds = 8640000000000000;
  final LibraryFiles files;

  Future<List<SavedSong>> list({void Function()? onUnreadable}) async {
    final songs = <SavedSong>[];
    for (final key in await files.list('songs/')) {
      final match = _songFile.firstMatch(key.substring('songs/'.length));
      if (match == null) continue;
      try {
        songs.add(await _read(key, match.group(1)!));
      } catch (error) {
        if (onUnreadable == null ||
            (error is! FormatException &&
                error is! FileSystemException &&
                error is! LibraryFileException)) {
          rethrow;
        }
        onUnreadable();
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
    await files.update(() async {
      if (kIsWeb && placements.isNotEmpty) {
        final clips = (await files.list('clips/', minLength: 45)).toSet();
        if (placements.any(
          (placement) => !clips.contains('clips/${placement.clipId}'),
        )) {
          throw const FormatException('A sound was removed from the library');
        }
      }
      await files.write(file, Uint8List.fromList(utf8.encode(body)));
    });
    return song;
  }

  Future<void> delete(SavedSong song) async {
    await files.delete(_file(song.id));
  }

  Future<bool> usesClip(String id) async {
    // A clip may still be referenced by an unreadable song.
    return (await list()).any(
      (song) => song.placements.any((placement) => placement.clipId == id),
    );
  }

  Future<SavedSong> _read(String key, String id) async {
    final body = jsonDecode(utf8.decode(await files.read(key)));
    if (body
        case {
          'version': 1,
          'name': final String name,
          'updatedAt': final int updatedAt,
          'placements': final List<Object?> placements,
        }
        when name.isNotEmpty &&
            updatedAt >= -_maxDateMilliseconds &&
            updatedAt <= _maxDateMilliseconds &&
            placements.length <= SoundPlacement.maxCount) {
      return SavedSong(
        id: id,
        name: name,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
        placements: placements.map(SoundPlacement.fromJson).toList(),
      );
    }
    throw const FormatException('Invalid saved song');
  }

  String _file(String id) {
    if (!_songId.hasMatch(id)) throw const FormatException('Invalid song ID');
    return 'songs/song_$id.json';
  }
}
