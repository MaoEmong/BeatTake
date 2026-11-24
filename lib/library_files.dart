import 'dart:typed_data';

import 'library_files_native.dart'
    if (dart.library.js_interop) 'library_files_browser.dart'
    as platform;
import 'wav_audio.dart';

abstract interface class LibraryFiles {
  static Future<LibraryFiles> open() => platform.openLibraryFiles();

  String draftPath(String name);
  Future<void> publishRecording(String draft, String recording, String? result);
  Future<List<String>> list(String prefix, {int minLength = 0});
  Future<Uint8List> read(String key);
  Future<AudioInput> audio(String key);
  Future<void> write(String key, Uint8List bytes);
  Future<void> delete(String key);
  Future<T> update<T>(Future<T> Function() change);
}

class LibraryFileException implements Exception {
  const LibraryFileException(this.message);

  final String message;

  @override
  String toString() => message;
}
