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
  }) {
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
    required List<String> referenceIds,
    required this.createdAt,
    this.note = '',
    this.dueAt,
    this.maxRecordingSeconds = defaultMaxRecordingSeconds,
  }) : parts = List.unmodifiable(parts.toSet().toList()..sort(_byIndex)),
       referenceIds = List.unmodifiable(referenceIds) {
    if (id.trim().isEmpty || choirId.trim().isEmpty) {
      throw ArgumentError('Assignment needs ids');
    }
    if (title.trim().isEmpty) throw ArgumentError('Assignment needs a title');
    if (this.parts.isEmpty) throw ArgumentError('Assign at least one part');
    if (this.referenceIds.toSet().length != this.referenceIds.length) {
      throw ArgumentError('Duplicate reference');
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
  final List<String> referenceIds;
  final DateTime createdAt;
  final String note;
  final DateTime? dueAt;
  final int maxRecordingSeconds;

  bool includes(ChoirPart part) => parts.contains(part);

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
    'referenceIds': referenceIds,
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
    referenceIds: idList(json, 'referenceIds'),
    createdAt: reqTime(json, 'createdAt'),
    note: req<String>(json, 'note'),
    dueAt: optTime(json, 'dueAt'),
    maxRecordingSeconds: req<int>(json, 'maxRecordingSeconds'),
  );
}
