import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'wav_decoder.dart'; // Adjust import path if needed

class Mp3Decoder {
  static Future<DecodedAudio> decode(Uint8List mp3Bytes) async {
    // 1. Create AudioContext forcing a 16kHz sample rate
    final options = web.AudioContextOptions(sampleRate: 16000);
    final context = web.AudioContext(options);

    // 2. Decode the audio data
    final promise = context.decodeAudioData(mp3Bytes.buffer.toJS);
    final web.AudioBuffer audioBuffer = await promise.toDart as web.AudioBuffer;

    // 3. Extract Float32List (which implements List<double>) normalized to [-1.0, 1.0]
    final Float32List channelData = audioBuffer.getChannelData(0).toDart;

    // 4. Return DecodedAudio using positional parameters
    return DecodedAudio(channelData, 16000);
  }
}
