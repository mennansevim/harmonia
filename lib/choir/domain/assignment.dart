import 'choir.dart';
import 'choir_json.dart';

enum ReferenceKind { audio, midi }

/// What the uploader declares about the right to share a file with the
/// choir. A declaration is not a licence check; [unknown] files are stored
/// but cannot be handed out in an assignment.
enum RightsDeclaration { ownRecording, licensed, publicDomain, unknown }

/// A reference file the conductor uploaded: one part's guide track, or the
/// full ensemble when [part] is null.
class ReferenceAsset {
  ReferenceAsset({
    required this.id,
    required this.choirId,
    required this.kind,
    required this.fileName,
    required this.rights,
    required this.uploadedAt,
    this.part,
    this.durationMs,
    Map<int, ChoirPart> trackParts = const {},
  }) : trackParts = Map.unmodifiable(trackParts) {
    if (id.trim().isEmpty || choirId.trim().isEmpty) {
      throw ArgumentError('Reference needs ids');
    }
    if (fileName.trim().isEmpty) throw ArgumentError('Reference needs a name');
    if (durationMs != null && durationMs! <= 0) {
      throw ArgumentError('durationMs must be positive when known');
    }
  }

  final String id;
  final String choirId;
  final ReferenceKind kind;
  final String fileName;
  final RightsDeclaration rights;
  final DateTime uploadedAt;
  final ChoirPart? part;

  /// Unknown (null) until a decoder has read the file.
  final int? durationMs;

  /// MIDI only: which track is which part, as the conductor confirmed it.
  /// An unmapped track is accompaniment (piano, orchestra).
  final Map<int, ChoirPart> trackParts;

  bool get shareable => rights != RightsDeclaration.unknown;

  Map<String, Object?> toJson() => {
    'id': id,
    'choirId': choirId,
    'kind': kind.name,
    'fileName': fileName,
    'rights': rights.name,
    'uploadedAt': writeTime(uploadedAt),
    'part': part?.name,
    'durationMs': durationMs,
    'trackParts': {
      for (final e in trackParts.entries) '${e.key}': e.value.name,
    },
  };

  factory ReferenceAsset.fromJson(Map<String, Object?> json) => ReferenceAsset(
    id: reqId(json, 'id'),
    choirId: reqId(json, 'choirId'),
    kind: reqEnum(json, 'kind', ReferenceKind.values),
    fileName: req<String>(json, 'fileName'),
    rights: reqEnum(json, 'rights', RightsDeclaration.values),
    uploadedAt: reqTime(json, 'uploadedAt'),
    part: optEnum(json, 'part', ChoirPart.values),
    durationMs: opt<int>(json, 'durationMs'),
    trackParts: _readTrackParts(json),
  );

  static Map<int, ChoirPart> _readTrackParts(Map<String, Object?> json) {
    final raw = req<Map<String, Object?>>(json, 'trackParts');
    return {
      for (final e in raw.entries)
        int.tryParse(e.key) ??
            (throw const FormatException('choir: bad track number')): reqEnum(
          {'part': e.value},
          'part',
          ChoirPart.values,
        ),
    };
  }
}

/// How the conductor wants a passage sung: note names first, lyrics once
/// the notes are secure.
enum PieceMode { solfege, lyrics }

/// One work (or passage of a work) inside an assignment. A conductor may
/// ask for several; each one is recorded and reviewed on its own.
class AssignmentPiece {
  AssignmentPiece({
    required this.id,
    required this.title,
    required this.mode,
    this.fromMeasure,
    this.toMeasure,
    this.sectionNote = '',
    this.withAccompaniment = false,
    this.midiReferenceId,
    this.voicing = 'SATB',
  }) {
    if (id.trim().isEmpty) throw ArgumentError('Piece needs an id');
    if (title.trim().isEmpty) throw ArgumentError('Piece needs a title');
    if ((fromMeasure == null) != (toMeasure == null)) {
      throw ArgumentError('A measure range needs both ends');
    }
    if (fromMeasure != null &&
        (fromMeasure! < 1 || toMeasure! < fromMeasure!)) {
      throw ArgumentError('Measure range out of order');
    }
    if (withAccompaniment && midiReferenceId == null) {
      throw ArgumentError('Accompanied recording needs a MIDI file');
    }
  }

  final String id;
  final String title;
  final PieceMode mode;
  final int? fromMeasure;
  final int? toMeasure;

  /// Free wording for scores without bar numbers ("from letter B to the
  /// fermata").
  final String sectionNote;

  /// The conductor asked for the take to be sung with the MIDI playing.
  final bool withAccompaniment;
  final String? midiReferenceId;

  /// How the work is scored, as the conductor labels it (SATB, SSAA…).
  final String voicing;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'mode': mode.name,
    'fromMeasure': fromMeasure,
    'toMeasure': toMeasure,
    'sectionNote': sectionNote,
    'withAccompaniment': withAccompaniment,
    'midiReferenceId': midiReferenceId,
    'voicing': voicing,
  };

  factory AssignmentPiece.fromJson(Map<String, Object?> json) =>
      AssignmentPiece(
        id: reqId(json, 'id'),
        title: req<String>(json, 'title'),
        mode: reqEnum(json, 'mode', PieceMode.values),
        fromMeasure: opt<int>(json, 'fromMeasure'),
        toMeasure: opt<int>(json, 'toMeasure'),
        sectionNote: req<String>(json, 'sectionNote'),
        withAccompaniment: req<bool>(json, 'withAccompaniment'),
        midiReferenceId: opt<String>(json, 'midiReferenceId'),
        voicing: opt<String>(json, 'voicing') ?? 'SATB',
      );
}

/// Homework for one or more parts. Recordings are listened to by the
/// conductor, never scored by the app (choir phase C1).
class Assignment {
  Assignment({
    required this.id,
    required this.choirId,
    required this.title,
    required List<ChoirPart> parts,
    required List<AssignmentPiece> pieces,
    required this.createdAt,
    this.note = '',
    this.dueAt,
    this.maxRecordingSeconds = defaultMaxRecordingSeconds,
  }) : parts = List.unmodifiable(parts.toSet().toList()..sort(_byIndex)),
       pieces = List.unmodifiable(pieces) {
    if (id.trim().isEmpty || choirId.trim().isEmpty) {
      throw ArgumentError('Assignment needs ids');
    }
    if (title.trim().isEmpty) throw ArgumentError('Assignment needs a title');
    if (this.parts.isEmpty) throw ArgumentError('Assign at least one part');
    if (this.pieces.isEmpty) throw ArgumentError('Add at least one piece');
    if (this.pieces.map((p) => p.id).toSet().length != this.pieces.length) {
      throw ArgumentError('Duplicate piece');
    }
    if (dueAt != null && !dueAt!.isAfter(createdAt)) {
      throw ArgumentError('Due time must be after creation');
    }
    if (maxRecordingSeconds < minRecordingSeconds ||
        maxRecordingSeconds > maxAllowedRecordingSeconds) {
      throw ArgumentError('maxRecordingSeconds out of range');
    }
  }

  /// A cap keeps the conductor's listening load bounded (≈45 min for 30
  /// singers at the default). Pilot hypothesis, not a measured limit.
  static const defaultMaxRecordingSeconds = 120;
  static const minRecordingSeconds = 10;
  static const maxAllowedRecordingSeconds = 600;

  static int _byIndex(ChoirPart a, ChoirPart b) => a.index - b.index;

  final String id;
  final String choirId;
  final String title;
  final List<ChoirPart> parts;
  final List<AssignmentPiece> pieces;
  final DateTime createdAt;
  final String note;
  final DateTime? dueAt;
  final int maxRecordingSeconds;

  bool includes(ChoirPart part) => parts.contains(part);

  /// Every MIDI file the pieces use; two passes of one work may share one.
  List<String> get referenceIds => [
    ...{
      for (final p in pieces)
        if (p.midiReferenceId != null) p.midiReferenceId!,
    },
  ];

  AssignmentPiece? piece(String id) {
    for (final p in pieces) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Ready to publish only when every reference exists in this choir and is
  /// shareable. Returns the reasons it is not, empty when it is.
  List<String> publishProblems(Map<String, ReferenceAsset> references) {
    final problems = <String>[];
    for (final ref in referenceIds) {
      final asset = references[ref];
      if (asset == null) {
        problems.add('$ref: dosya bulunamadı');
      } else if (asset.choirId != choirId) {
        problems.add('$ref: başka koronun dosyası');
      } else if (!asset.shareable) {
        problems.add('$ref: paylaşım hakkı belirtilmedi');
      }
    }
    return problems;
  }

  bool isLate(DateTime at) => dueAt != null && at.isAfter(dueAt!);

  Map<String, Object?> toJson() => {
    'id': id,
    'choirId': choirId,
    'title': title,
    'parts': [for (final p in parts) p.name],
    'pieces': [for (final p in pieces) p.toJson()],
    'createdAt': writeTime(createdAt),
    'note': note,
    'dueAt': dueAt == null ? null : writeTime(dueAt!),
    'maxRecordingSeconds': maxRecordingSeconds,
  };

  factory Assignment.fromJson(Map<String, Object?> json) => Assignment(
    id: reqId(json, 'id'),
    choirId: reqId(json, 'choirId'),
    title: req<String>(json, 'title'),
    parts: enumList(json, 'parts', ChoirPart.values),
    pieces: [
      for (final p in req<List<Object?>>(json, 'pieces'))
        if (p is Map<String, Object?>)
          AssignmentPiece.fromJson(p)
        else
          throw const FormatException('choir: piece is not a map'),
    ],
    createdAt: reqTime(json, 'createdAt'),
    note: req<String>(json, 'note'),
    dueAt: optTime(json, 'dueAt'),
    maxRecordingSeconds: req<int>(json, 'maxRecordingSeconds'),
  );
}
