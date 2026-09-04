import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'wav_decoder.dart'; // Adjust import path if needed

class Mp3Decoder {
  /// Asynchronously converts MP3 bytes to raw PCM samples
  static Future<DecodedAudio> decode(Uint8List mp3Bytes) async {
    final tempDir = await getTemporaryDirectory();
    final mp3File = File('${tempDir.path}/temp_input.mp3');
    final wavFile = File('${tempDir.path}/temp_output.wav');

    // Clean up any old files to prevent conflicts
    if (await wavFile.exists()) await wavFile.delete();

    await mp3File.writeAsBytes(mp3Bytes);

    // Command: Convert to WAV, 16kHz sample rate, 1 channel (mono), 16-bit PCM
    // This standardizes the audio for voice analysis backends.
    final command =
        '-y -i "${mp3File.path}" -acodec pcm_s16le -ar 16000 -ac 1 "${wavFile.path}"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      final wavBytes = await wavFile.readAsBytes();

      // Clean up temp files
      await mp3File.delete();
      await wavFile.delete();

      // Now that it's a valid WAV, run it through your standard decoder
      return WavDecoder.decode(wavBytes);
    } else {
      final logs = await session.getLogsAsString();
      throw Exception('Failed to decode MP3: $logs');
    }
  }
}
