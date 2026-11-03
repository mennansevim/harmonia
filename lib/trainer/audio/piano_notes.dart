import 'dart:convert';

import 'package:flutter/services.dart';

/// Pre-recorded single piano notes for play-and-listen work (range test).
///
/// `assets/audio/piano/notes/catalog.json` lists one WAV per natural note
/// (`"C4": "assets/audio/piano/notes/C4.wav"`). The whole catalog is ignored
/// until `rightsReference` names who recorded the notes and on what terms:
/// files of unclear origin are never played (AGENTS). A missing or unlisted
/// note falls back to the additive piano synth; [isRecorded] tells which.
class PianoNoteBank {
  PianoNoteBank({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const catalogPath = 'assets/audio/piano/notes/catalog.json';
  static const _letters = {
    0: 'C',
    2: 'D',
    4: 'E',
    5: 'F',
    7: 'G',
    9: 'A',
    11: 'B',
  };

  final AssetBundle _bundle;
  Future<Map<String, String>>? _catalog;
  final _cache = <int, Uint8List?>{};

  /// `C4`-style name of a natural note; null for a sharp.
  static String? noteName(int midi) {
    final letter = _letters[midi % 12];
    return letter == null ? null : '$letter${midi ~/ 12 - 1}';
  }

  Future<Map<String, String>> _load() => _catalog ??= _read();

  Future<Map<String, String>> _read() async {
    try {
      final doc = jsonDecode(await _bundle.loadString(catalogPath));
      if (doc is! Map || doc['kind'] != 'prerecorded_piano_notes') return {};
      final rights = doc['rightsReference'];
      if (rights is! String || rights.trim().isEmpty) return {};
      final notes = doc['notes'];
      if (notes is! Map) return {};
      return {
        for (final e in notes.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      };
    } catch (_) {
      return {};
    }
  }

  /// True when a cleared recording exists for [midi].
  Future<bool> isRecorded(int midi) async => await wav(midi) != null;

  /// The recorded WAV bytes, or null to use the synth.
  Future<Uint8List?> wav(int midi) async {
    if (_cache.containsKey(midi)) return _cache[midi];
    final name = noteName(midi);
    final path = name == null ? null : (await _load())[name];
    Uint8List? bytes;
    if (path != null) {
      try {
        bytes = (await _bundle.load(path)).buffer.asUint8List();
      } catch (_) {
        bytes = null;
      }
    }
    return _cache[midi] = bytes;
  }
}
