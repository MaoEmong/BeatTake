import 'dart:typed_data';

class WavDiskReader {
  WavDiskReader(String path) {
    throw UnsupportedError('The browser cannot open a device file');
  }

  int get length => throw UnsupportedError('No device file');

  Uint8List read(int offset, int count) =>
      throw UnsupportedError('No device file');

  void close() {}
}

void writeWavFile(String path, Uint8List bytes) =>
    throw UnsupportedError('The browser cannot write a device file');
