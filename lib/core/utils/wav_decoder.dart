import 'dart:typed_data';

/// Minimal WAV (PCM) decoder — enough to feed the same 16kHz mono
/// double-sample pipeline that [VoiceAnalysisSocket.sendAudioChunk]
/// already expects from the live VAD stream.
///
/// Deliberately scoped to uncompressed 16-bit PCM WAV. If you need to
/// accept mp3/m4a/aac uploads too, transcode to WAV first (e.g. with
/// `ffmpeg_kit_flutter_new`) before calling [WavDecoder.decode] — that's
/// a format-conversion problem, not something to bolt onto this parser.
class DecodedAudio {
  /// Mono samples normalized to [-1.0, 1.0], resampled to [targetSampleRate].
  final List<double> samples;
  final int sampleRate;
  DecodedAudio(this.samples, this.sampleRate);
}

class WavDecodeException implements Exception {
  final String message;
  WavDecodeException(this.message);
  @override
  String toString() => 'WavDecodeException: $message';
}

class WavDecoder {
  static const int targetSampleRate = 16000;

  static DecodedAudio decode(Uint8List bytes) {
    if (bytes.length < 44) {
      throw WavDecodeException('File is too small to be a valid WAV file.');
    }
    final bd = ByteData.sublistView(bytes);

    if (_tag(bytes, 0) != 'RIFF' || _tag(bytes, 8) != 'WAVE') {
      throw WavDecodeException(
          "That doesn't look like a WAV file. Convert it to 16-bit PCM "
          'WAV before uploading.');
    }

    int offset = 12;
    int? sampleRate;
    int? bitsPerSample;
    int? numChannels;
    int? audioFormat;
    Uint8List? dataBytes;

    while (offset + 8 <= bytes.length) {
      final chunkId = _tag(bytes, offset);
      final chunkSize = bd.getUint32(offset + 4, Endian.little);
      final chunkStart = offset + 8;

      if (chunkId == 'fmt ') {
        audioFormat = bd.getUint16(chunkStart, Endian.little);
        numChannels = bd.getUint16(chunkStart + 2, Endian.little);
        sampleRate = bd.getUint32(chunkStart + 4, Endian.little);
        bitsPerSample = bd.getUint16(chunkStart + 14, Endian.little);
      } else if (chunkId == 'data') {
        final end = (chunkStart + chunkSize).clamp(0, bytes.length);
        dataBytes = bytes.sublist(chunkStart, end);
      }

      offset = chunkStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (sampleRate == null || bitsPerSample == null || dataBytes == null) {
      throw WavDecodeException(
          'Could not find fmt/data chunks in this WAV file.');
    }
    // 1 = PCM, 0xFFFE = WAVE_FORMAT_EXTENSIBLE (still PCM underneath, common
    // for files exported from DAWs / iOS voice memos converted to WAV).
    if (audioFormat != 1 && audioFormat != 0xFFFE) {
      throw WavDecodeException(
          'Only uncompressed PCM WAV files are supported (this one is compressed).');
    }
    if (bitsPerSample != 16) {
      throw WavDecodeException(
          'Only 16-bit PCM WAV files are supported (found $bitsPerSample-bit).');
    }

    final channels = numChannels ?? 1;
    final pcm = ByteData.sublistView(dataBytes);
    final sampleCount = dataBytes.length ~/ (2 * channels);

    // Downmix to mono, normalize Int16 -> [-1.0, 1.0]
    final mono = List<double>.filled(sampleCount, 0.0);
    for (int i = 0; i < sampleCount; i++) {
      int sum = 0;
      for (int c = 0; c < channels; c++) {
        final byteOffset = (i * channels + c) * 2;
        sum += pcm.getInt16(byteOffset, Endian.little);
      }
      mono[i] = (sum / channels) / 32768.0;
    }

    final resampled = sampleRate == targetSampleRate
        ? mono
        : _linearResample(mono, sampleRate, targetSampleRate);

    return DecodedAudio(resampled, targetSampleRate);
  }

  static String _tag(Uint8List bytes, int offset) =>
      String.fromCharCodes(bytes.sublist(offset, offset + 4));

  /// Naive linear-interpolation resampler — enough to align an uploaded
  /// file's native sample rate with the backend's expected 16kHz. Not a
  /// substitute for a real resampling library if upload audio quality
  /// turns out to matter for detection accuracy in practice.
  static List<double> _linearResample(
      List<double> input, int fromRate, int toRate) {
    if (input.isEmpty || fromRate == toRate) return input;
    final ratio = fromRate / toRate;
    final outLength = (input.length / ratio).floor();
    final output = List<double>.filled(outLength, 0.0);
    for (int i = 0; i < outLength; i++) {
      final srcPos = i * ratio;
      final srcIndex = srcPos.floor();
      final frac = srcPos - srcIndex;
      final a = input[srcIndex];
      final b = srcIndex + 1 < input.length ? input[srcIndex + 1] : a;
      output[i] = a + (b - a) * frac;
    }
    return output;
  }
}
