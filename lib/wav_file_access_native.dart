import 'dart:io';
import 'dart:typed_data';

class WavDiskReader {
  WavDiskReader(String path) : _file = File(path).openSync();

  final RandomAccessFile _file;

  int get length => _file.lengthSync();

  Uint8List read(int offset, int count) {
    _file.setPositionSync(offset);
    return _file.readSync(count);
  }

  void close() => _file.closeSync();
}

void writeWavFile(String path, Uint8List bytes) =>
    File(path).writeAsBytesSync(bytes);
