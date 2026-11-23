import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

class WavFile {
  WavFile._(this.path, this.sampleRate, this.frames, this._dataOffset);

  final String path;
  final int sampleRate;
  final int frames;
  final int _dataOffset;

  int get durationMs => (frames * 1000 / sampleRate).ceil();

  // Editing and mixing create an in-memory preview. Keep it small enough for
  // phones with limited memory, even when the original recording is longer.
  static const maxPreviewSeconds = 300;

  static WavFile open(String path) {
    final file = File(path).openSync();
    try {
      final header = file.readSync(12);
      if (header.length != 12 ||
          String.fromCharCodes(header.take(4)) != 'RIFF' ||
          String.fromCharCodes(header.skip(8)) != 'WAVE') {
        throw const FormatException('Invalid WAV file');
      }

      final fileLength = file.lengthSync();
      int? sampleRate;
      int? dataOffset;
      int? dataSize;
      while (file.positionSync() + 8 <= fileLength) {
        final chunk = file.readSync(8);
        final name = String.fromCharCodes(chunk.take(4));
        final size = ByteData.sublistView(chunk).getUint32(4, Endian.little);
        final offset = file.positionSync();
        if (offset + size > fileLength) {
          throw const FormatException('Incomplete WAV chunk');
        }

        if (name == 'fmt ' && size >= 16) {
          final format = ByteData.sublistView(file.readSync(16));
          if (format.getUint16(0, Endian.little) != 1 ||
              format.getUint16(2, Endian.little) != 1 ||
              format.getUint16(12, Endian.little) != 2 ||
              format.getUint16(14, Endian.little) != 16) {
            throw const FormatException('Expected 16-bit mono PCM audio');
          }
          sampleRate = format.getUint32(4, Endian.little);
        } else if (name == 'data') {
          dataOffset = offset;
          dataSize = size;
        }
        if (sampleRate != null && dataOffset != null) break;
        file.setPositionSync(offset + size + (size.isOdd ? 1 : 0));
      }

      if (sampleRate == null ||
          sampleRate < 8000 ||
          sampleRate > 48000 ||
          dataOffset == null ||
          dataSize == null ||
          dataSize < 2 ||
          dataSize.isOdd) {
        throw const FormatException('Missing or unsupported WAV audio');
      }
      return WavFile._(path, sampleRate, dataSize ~/ 2, dataOffset);
    } finally {
      file.closeSync();
    }
  }

  Int16List readFrames(int start, int end) {
    RangeError.checkValidRange(start, end, frames);
    if (end <= start || end - start > sampleRate * maxPreviewSeconds) {
      throw const FormatException('Invalid preview length');
    }
    final file = File(path).openSync();
    try {
      file.setPositionSync(_dataOffset + start * 2);
      final bytes = file.readSync((end - start) * 2);
      if (bytes.length != (end - start) * 2) {
        throw const FormatException('Incomplete WAV audio');
      }
      final samples = Int16List(end - start);
      final data = ByteData.sublistView(bytes);
      for (var index = 0; index < samples.length; index++) {
        samples[index] = data.getInt16(index * 2, Endian.little);
      }
      return samples;
    } finally {
      file.closeSync();
    }
  }

  Int16List edit(int start, int end, int semitones) {
    RangeError.checkValueInInterval(semitones, -12, 12, 'semitones');
    final rate = math.pow(2, semitones / 12).toDouble();
    if ((end - start) / rate > sampleRate * maxPreviewSeconds) {
      throw const FormatException('Adjusted audio exceeds the preview limit');
    }
    final input = readFrames(start, end);
    return changeRate(input, rate);
  }

  List<double> peaks({int bars = 60}) {
    final file = File(path).openSync();
    try {
      return List.generate(bars, (index) {
        final start = frames * index ~/ bars;
        final end = math.max(start + 1, frames * (index + 1) ~/ bars);
        // Read from the middle of each bar's range to keep long previews inexpensive.
        final length = math.min(end - start, 512);
        file.setPositionSync(
          _dataOffset + (start + (end - start - length) ~/ 2) * 2,
        );
        final bytes = ByteData.sublistView(file.readSync(length * 2));
        var peak = 0;
        for (var offset = 0; offset + 2 <= bytes.lengthInBytes; offset += 2) {
          peak = math.max(peak, bytes.getInt16(offset, Endian.little).abs());
        }
        return peak / 32768;
      });
    } finally {
      file.closeSync();
    }
  }

  static Int16List changeRate(Int16List input, double rate) {
    if (rate == 1) return input;
    final length = math.max(1, (input.length / rate).round());
    final output = Int16List(length);
    for (var index = 0; index < length; index++) {
      final position = math.min(index * rate, input.length - 1.0);
      final left = position.floor();
      final right = math.min(left + 1, input.length - 1);
      final fraction = position - left;
      output[index] = (input[left] + (input[right] - input[left]) * fraction)
          .round();
    }
    return output;
  }

  static void write(String path, int sampleRate, Int16List samples) {
    final sampleBytes = samples.length * 2;
    final header = ByteData(44)
      ..setUint32(0, 0x52494646) // RIFF
      ..setUint32(4, 36 + sampleBytes, Endian.little)
      ..setUint32(8, 0x57415645) // WAVE
      ..setUint32(12, 0x666d7420) // fmt
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, 1, Endian.little)
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, sampleRate * 2, Endian.little)
      ..setUint16(32, 2, Endian.little)
      ..setUint16(34, 16, Endian.little)
      ..setUint32(36, 0x64617461) // data
      ..setUint32(40, sampleBytes, Endian.little);
    final file = File(path).openSync(mode: FileMode.write);
    try {
      file.writeFromSync(header.buffer.asUint8List());
      if (Endian.host == Endian.little) {
        file.writeFromSync(
          samples.buffer.asUint8List(samples.offsetInBytes, sampleBytes),
        );
      } else {
        final data = ByteData(sampleBytes);
        for (var index = 0; index < samples.length; index++) {
          data.setInt16(index * 2, samples[index], Endian.little);
        }
        file.writeFromSync(data.buffer.asUint8List());
      }
    } finally {
      file.closeSync();
    }
  }
}
