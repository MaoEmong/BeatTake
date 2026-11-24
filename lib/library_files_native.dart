import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'library_files.dart';
import 'wav_audio.dart';

Future<LibraryFiles> openLibraryFiles() async {
  final documents = await getApplicationDocumentsDirectory();
  final folder = Directory.fromUri(documents.uri.resolve('recordings/'));
  await folder.create(recursive: true);
  return LocalLibraryFiles(folder);
}

class LocalLibraryFiles implements LibraryFiles {
  LocalLibraryFiles(this.directory);

  final Directory directory;

  File _file(String key) => File.fromUri(directory.uri.resolve(key));

  @override
  String draftPath(String name) => _file(name).path;

  @override
  Future<void> publishRecording(
    String draft,
    String recording,
    String? result,
  ) async {
    final file = _file(draft);
    if (await file.length() <= 44) {
      throw const FileSystemException('Recording contains no audio');
    }
    await file.rename(_file(recording).path);
  }

  @override
  Future<List<String>> list(String prefix, {int minLength = 0}) async {
    final folder = Directory.fromUri(directory.uri.resolve(prefix));
    await folder.create(recursive: true);
    final keys = <String>[];
    await for (final entry in folder.list(followLinks: false)) {
      if (entry is File && await entry.length() >= minLength) {
        keys.add('$prefix${entry.uri.pathSegments.last}');
      }
    }
    return keys;
  }

  @override
  Future<Uint8List> read(String key) => _file(key).readAsBytes();

  @override
  Future<AudioInput> audio(String key) async =>
      AudioInput.file(_file(key).path);

  @override
  Future<void> write(String key, Uint8List bytes) async {
    final file = _file(key);
    await file.parent.create(recursive: true);
    final draft = await file.parent.createTemp('draft_');
    try {
      final temporary = File.fromUri(draft.uri.resolve('payload'));
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(file.path);
    } finally {
      await draft.delete(recursive: true);
    }
  }

  @override
  Future<void> delete(String key) async => _file(key).delete();

  @override
  Future<T> update<T>(Future<T> Function() change) => change();
}
