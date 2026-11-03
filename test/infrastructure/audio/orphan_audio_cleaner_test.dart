import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/choir/data/choir_bundle.dart';
import 'package:resonia/infrastructure/audio/orphan_audio_cleaner.dart';

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
    final lab = dir('resonia-audio-lab-abc', [
      'recording.wav',
      'reference.wav',
    ]);
    final clip = dir('resonia-clip-xyz', ['clip.wav']);
    final empty = dir('resonia-clip-empty', []);
    final other = dir('someone-else', ['recording.wav']);
    final stray = File('${root.path}/resonia-audio-lab-file')
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

  test('removes choir takes, mixes, voice notes and shared bundles', () async {
    final take = dir('choir-take-a', [
      'vocal.wav',
      'accompaniment.wav',
      'take.wav',
    ]);
    final practice = dir('choir-practice-b', ['mix-3.wav', 'mix-4.wav']);
    final voice = dir('choir-voice-c', ['voice.wav']);
    final bundle = dir('choir-bundle-d', ['Ödev-1.$bundleExtension']);
    final report = await OrphanAudioCleaner(() async => root).run();
    expect(report.removedDirectories, 4);
    expect(report.clean, isTrue);
    for (final d in [take, practice, voice, bundle]) {
      expect(d.existsSync(), isFalse);
    }
  });

  test('bundle suffix stays in step with the choir layer', () {
    expect(OrphanAudioCleaner.bundleSuffix, '.$bundleExtension');
  });

  test('a choir directory with unknown content is kept by run', () async {
    final d = dir('choir-take-odd', ['take.wav', 'notes.txt']);
    final report = await OrphanAudioCleaner(() async => root).run();
    expect(report.keptDirectories, 1);
    expect(File('${d.path}/notes.txt').existsSync(), isTrue);
  });

  test('purge removes user data whatever it holds, keeps the clip', () async {
    final take = dir('choir-take-a', ['take.wav', 'notes.txt']);
    Directory('${take.path}/nested').createSync();
    final lab = dir('resonia-audio-lab-b', ['partial.bin']);
    final clip = dir('resonia-clip-live', ['clip.wav']);
    final other = dir('someone-else', ['take.wav']);
    final report = await OrphanAudioCleaner(() async => root).purge();
    expect(report.removedDirectories, 2);
    expect(report.clean, isTrue);
    expect(take.existsSync(), isFalse);
    expect(lab.existsSync(), isFalse);
    expect(File('${clip.path}/clip.wav').existsSync(), isTrue);
    expect(File('${other.path}/take.wav').existsSync(), isTrue);
  });

  test('purge does not follow a link out of the temp root', () async {
    final outside = await Directory.systemTemp.createTemp('outside-');
    addTearDown(() => outside.delete(recursive: true));
    File('${outside.path}/take.wav').writeAsStringSync('keep');
    Link('${root.path}/choir-take-link').createSync(outside.path);
    await OrphanAudioCleaner(() async => root).purge();
    expect(File('${outside.path}/take.wav').existsSync(), isTrue);
  });

  test('purge reports an unavailable temp root', () async {
    final report = await OrphanAudioCleaner(
      () async => throw const FileSystemException('denied'),
    ).purge();
    expect(report.clean, isFalse);
  });

  test('unexpected content keeps the directory and is reported', () async {
    final d = dir('resonia-audio-lab-odd', ['recording.wav', 'notes.txt']);
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
    Link('${root.path}/resonia-clip-link').createSync(outside.path);
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
