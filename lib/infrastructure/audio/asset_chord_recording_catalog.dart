import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/audio/chord_recording_catalog.dart';

class AssetChordRecordingCatalog implements ChordRecordingCatalogRepository {
  AssetChordRecordingCatalog({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;
  final AssetBundle _bundle;
  static const assetPath = 'assets/audio/piano/chords/catalog.json';

  @override
  Future<ChordRecordingCatalog> load() async {
    final raw = await _bundle.loadString(assetPath);
    if (raw.length > 16384) throw const FormatException('Catalog too large');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Catalog must be an object');
    }
    return ChordRecordingCatalog.fromJson(decoded);
  }
}
