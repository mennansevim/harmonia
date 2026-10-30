import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/infrastructure/audio/pcm16_wav.dart';
import 'package:resonia/infrastructure/audio/read_lab_wav.dart';

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('resonia-lab-read-test-');
    file = File('${directory.path}/recording.wav');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  test('actual WAV header rate and samples survive owned file read', () async {
    await file.writeAsBytes(
      Pcm16Wav.tone(frequencyHz: 440, sampleRateHz: 8000).encode(),
    );
    final wav = await readLabWav(file);
    expect(wav.sampleRateHz, 8000);
    expect(wav.samples, isNotEmpty);
  });
  test('missing file, short and malformed data fail closed', () async {
    await expectLater(readLabWav(file), throwsFormatException);
    await file.writeAsBytes([0, 1]);
    await expectLater(readLabWav(file), throwsFormatException);
    await file.writeAsBytes(List.filled(44, 0));
    await expectLater(readLabWav(file), throwsFormatException);
  });
  test('oversize is rejected before decoding', () async {
    final handle = await file.open(mode: FileMode.write);
    await handle.truncate(4224045);
    await handle.close();
    await expectLater(readLabWav(file), throwsFormatException);
  });
  test('symbolic link is rejected', () async {
    final target = File('${directory.path}/target.wav');
    await target.writeAsBytes(Pcm16Wav.tone(frequencyHz: 440).encode());
    await Link(file.path).create(target.path);
    await expectLater(readLabWav(file), throwsFormatException);
  });
}
