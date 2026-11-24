import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'library_files.dart';
import 'wav_audio.dart';

Future<LibraryFiles> openLibraryFiles() async {
  // Keep development and other projects on the same Pages origin separate.
  final basePath = Uri.parse(web.document.baseURI).path;
  final request = web.window.indexedDB.open('BeatTake:$basePath', 1);
  request.onupgradeneeded = ((web.Event _) {
    (request.result as web.IDBDatabase).createObjectStore('library');
  }).toJS;
  final database = await _result(request) as web.IDBDatabase;
  database.onversionchange = ((web.Event _) => database.close()).toJS;
  return _BrowserLibraryFiles(database);
}

Future<JSAny?> _result(web.IDBRequest request) {
  final completion = Completer<JSAny?>();
  request.onsuccess = ((web.Event _) {
    completion.complete(request.result);
  }).toJS;
  request.onerror = ((web.Event _) {
    completion.completeError(
      LibraryFileException(request.error?.message ?? 'Browser storage failed'),
    );
  }).toJS;
  return completion.future;
}

class _BrowserLibraryFiles implements LibraryFiles {
  _BrowserLibraryFiles(this._database);

  final web.IDBDatabase _database;

  @override
  String draftPath(String name) => name;

  @override
  Future<void> publishRecording(
    String draft,
    String recording,
    String? result,
  ) async {
    if (result == null || !result.startsWith('blob:')) {
      throw const LibraryFileException('Recording contains no audio');
    }
    try {
      final response = await web.window.fetch(result.toJS).toDart;
      final buffer = await response.arrayBuffer().toDart;
      if (!response.ok || buffer.toDart.lengthInBytes <= 44) {
        throw const LibraryFileException('Recording contains no audio');
      }
      await write(recording, buffer.toDart.asUint8List());
    } finally {
      web.URL.revokeObjectURL(result);
    }
  }

  @override
  Future<List<String>> list(String prefix, {int minLength = 0}) async {
    final store = _database.transaction('library'.toJS).objectStore('library');
    final keys =
        await _result(
              store.getAllKeys(
                web.IDBKeyRange.bound(prefix.toJS, '$prefix\uffff'.toJS),
              ),
            )
            as JSArray<JSString>;
    return [
      for (final key in keys.toDart.map((key) => key.toDart))
        if (!key.substring(prefix.length).contains('/')) key,
    ];
  }

  @override
  Future<Uint8List> read(String key) async {
    final store = _database.transaction('library'.toJS).objectStore('library');
    final result = await _result(store.get(key.toJS));
    if (result == null) throw const LibraryFileException('File was removed');
    return (result as JSUint8Array).toDart;
  }

  @override
  Future<AudioInput> audio(String key) async =>
      AudioInput.memory(await read(key));

  @override
  Future<void> write(String key, Uint8List bytes) =>
      _change((store) => store.put(bytes.toJS, key.toJS));

  @override
  Future<void> delete(String key) => _change((store) => store.delete(key.toJS));

  @override
  Future<T> update<T>(Future<T> Function() change) async {
    late Future<T> pending;
    await web.window.navigator.locks
        .request(
          _database.name,
          (() {
            pending = Future.sync(change);
            // Keep the lock until the Dart operation settles. Return its original
            // result or exception to the caller.
            return pending
                .then<JSAny?>((_) => null, onError: (Object _) => null)
                .toJS;
          }).toJS,
        )
        .toDart;
    return pending;
  }

  Future<void> _change(void Function(web.IDBObjectStore) change) {
    final transaction = _database.transaction('library'.toJS, 'readwrite');
    final completion = Completer<void>();
    transaction.oncomplete = ((web.Event _) => completion.complete()).toJS;
    transaction.onabort = ((web.Event _) {
      completion.completeError(
        LibraryFileException(
          transaction.error?.message ?? 'Browser storage failed',
        ),
      );
    }).toJS;
    change(transaction.objectStore('library'));
    return completion.future;
  }
}
