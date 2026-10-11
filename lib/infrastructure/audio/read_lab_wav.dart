import 'dart:io';
import 'pcm16_wav.dart';

/// Caller supplies its fixed owned file, never a recorder-returned path.
/// Same handle is bounded before and after reading; no arbitrary-size read.
Future<Pcm16Wav> readLabWav(File file) async {
  const maxBytes = 4224044;
  if (await FileSystemEntity.type(file.path, followLinks: false) !=
      FileSystemEntityType.file) {
    throw const FormatException('Recording must be a regular file');
  }
  final handle = await file.open();
  try {
    final length = await handle.length();
    if (length < 44 || length > maxBytes) {
      throw const FormatException('Recording exceeds file budget');
    }
    final bytes = await handle.read(length);
    if (bytes.length != length || await handle.length() != length) {
      throw const FormatException('Recording changed during read');
    }
    return Pcm16Wav.decode(bytes);
  } finally {
    await handle.close();
  }
}
