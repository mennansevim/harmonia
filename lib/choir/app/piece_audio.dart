import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../audio/wav_io.dart';
import '../data/choir_store.dart';
import '../domain/assignment.dart';
import '../domain/choir.dart';
import '../midi/midi_section.dart';
import '../midi/part_renderer.dart';
import '../midi/smf_reader.dart';

/// Renders the passage a piece asks for, off the UI thread.
Future<RenderedPart> renderPiece({
  required ChoirStore store,
  required AssignmentPiece piece,
  required PartMix mix,
}) async {
  final asset = store.reference(piece.midiReferenceId!)!;
  final bytes = await File(await store.mediaPath(asset.id)).readAsBytes();
  return _renderOff(
    bytes,
    asset.trackParts,
    piece.fromMeasure,
    piece.toMeasure,
    mix,
  );
}

// Top level on purpose: a closure inside [renderPiece] would capture the
// store and fail at the isolate boundary.
Future<RenderedPart> _renderOff(
  Uint8List bytes,
  Map<int, ChoirPart> map,
  int? from,
  int? to,
  PartMix mix,
) => Isolate.run(() {
  final file = readSmf(bytes);
  return renderPart(
    file: file,
    section: MidiSection.of(file, from: from, to: to),
    trackParts: map,
    mix: mix,
  );
});

Future<Uint8List> encodeRendered(RenderedPart part) =>
    Isolate.run(() => encodeWav(part.samples, part.sampleRateHz));
