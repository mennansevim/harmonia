import 'choir_json.dart';

/// What a choir keeps together outside assignments.
enum ResourceKind {
  /// Sheet music: a PDF or a photo of the page.
  score,

  /// What was recorded in rehearsal, kept for those who could not come.
  rehearsalRecording,

  /// A written note from rehearsal.
  note,
}

/// One item of the choir's library. Text-only notes have no [fileId].
class ChoirResource {
  ChoirResource({
    required this.id,
    required this.choirId,
    required this.kind,
    required this.title,
    required this.authorId,
    required this.createdAt,
    this.text = '',
    this.fileId,
    this.fileName,
    this.rehearsalOn,
  }) {
    if (id.trim().isEmpty ||
        choirId.trim().isEmpty ||
        authorId.trim().isEmpty) {
      throw ArgumentError('Resource needs ids');
    }
    if (title.trim().isEmpty) throw ArgumentError('Resource needs a title');
    if ((fileId == null) != (fileName == null)) {
      throw ArgumentError('A file needs its name');
    }
    if (kind == ResourceKind.note ? text.trim().isEmpty : fileId == null) {
      throw ArgumentError('Resource has no content');
    }
  }

  final String id;
  final String choirId;
  final ResourceKind kind;
  final String title;
  final String authorId;
  final DateTime createdAt;
  final String text;
  final String? fileId;
  final String? fileName;

  /// The rehearsal this belongs to, when it came from one.
  final DateTime? rehearsalOn;

  Map<String, Object?> toJson() => {
    'id': id,
    'choirId': choirId,
    'kind': kind.name,
    'title': title,
    'authorId': authorId,
    'createdAt': writeTime(createdAt),
    'text': text,
    'fileId': fileId,
    'fileName': fileName,
    'rehearsalOn': rehearsalOn == null ? null : writeTime(rehearsalOn!),
  };

  factory ChoirResource.fromJson(Map<String, Object?> json) => ChoirResource(
    id: reqId(json, 'id'),
    choirId: reqId(json, 'choirId'),
    kind: reqEnum(json, 'kind', ResourceKind.values),
    title: req<String>(json, 'title'),
    authorId: reqId(json, 'authorId'),
    createdAt: reqTime(json, 'createdAt'),
    text: req<String>(json, 'text'),
    fileId: opt<String>(json, 'fileId'),
    fileName: opt<String>(json, 'fileName'),
    rehearsalOn: optTime(json, 'rehearsalOn'),
  );
}
