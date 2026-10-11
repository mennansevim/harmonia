import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/infrastructure/audio/orphan_audio_cleaner.dart';

void main() {
  late Directory root;
  setUp(() async => root = await Directory.systemTemp.createTemp('tmproot-'));
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Directory dir(String name, List<String> files) {
    final d = Directory('${root.path}/$name')..createSync();
    for (final f in files) {
      File('${d.path}/$f').writeAsStringSync('x');
    }
    return d;
  }

  test('removes only own orphan dirs with known files', () async {
    final lab = dir('harmonia-audio-lab-abc', [
      'recording.wav',
      'reference.wav',
    ]);
    final clip = dir('harmonia-clip-xyz', ['clip.wav']);
    final empty = dir('harmonia-clip-empty', []);
    final other = dir('someone-else', ['recording.wav']);
    final stray = File('${root.path}/harmonia-audio-lab-file')
      ..writeAsStringSync('not a dir');
    final report = await OrphanAudioCleaner(() async => root).run();
    expect(report.removedDirectories, 3);
    expect(report.clean, isTrue);
    expect(lab.existsSync(), isFalse);
    expect(clip.existsSync(), isFalse);
    expect(empty.existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
    expect(File('${other.path}/recording.wav').existsSync(), isTrue);
    expect(stray.existsSync(), isTrue);
  });

  test('unexpected content keeps the directory and is reported', () async {
    final d = dir('harmonia-audio-lab-odd', ['recording.wav', 'notes.txt']);
    Directory('${d.path}/nested').createSync();
    final report = await OrphanAudioCleaner(() async => root).run();
    expect(report.keptDirectories, 1);
    expect(report.clean, isFalse);
    expect(File('${d.path}/recording.wav').existsSync(), isFalse);
    expect(File('${d.path}/notes.txt').existsSync(), isTrue);
    expect(Directory('${d.path}/nested').existsSync(), isTrue);
  });

  test('symlinked directory is not followed', () async {
    final outside = await Directory.systemTemp.createTemp('outside-');
    addTearDown(() => outside.delete(recursive: true));
    File('${outside.path}/recording.wav').writeAsStringSync('keep');
    Link('${root.path}/harmonia-clip-link').createSync(outside.path);
    final report = await OrphanAudioCleaner(() async => root).run();
    expect(File('${outside.path}/recording.wav').existsSync(), isTrue);
    expect(report.removedDirectories, 0);
  });

  test('unavailable temp root is a reported failure', () async {
    final report = await OrphanAudioCleaner(
      () async => throw const FileSystemException('denied'),
    ).run();
    expect(report.failures, 1);
    expect(report.clean, isFalse);
  });
}
