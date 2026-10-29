import 'assignment.dart';
import 'choir.dart';
import 'choir_json.dart';

/// Lifecycle of one singer's answer to one assignment:
///
/// ```
/// draft ──submit──▶ submitted ──listen──▶ listened
///   ▲                   │                    │
///   │                   └──────review────────┤
///   │                                        ▼
///   └──retake── revisionRequested ◀── accepted | revisionRequested
/// ```
///
/// No state carries a score: in choir phase C1 the conductor listens and
/// writes feedback; the app measures nothing.
enum SubmissionStatus {
  draft,
  submitted,
  listened,
  accepted,
  revisionRequested,
}

/// Conductor's quick labels. [personalArea] links a label to the Personal
/// practice area a singer can open next (BRIDGE-01). It is the conductor's
/// judgement passed on, not something the app detected.
enum FeedbackTag {
  pitch('Perde', 'pitch'),
  rhythm('Ritim', 'rhythm'),
  entry('Giriş', 'rhythm'),
  breath('Nefes', 'breath'),
  diction('Söz', null),
  dynamics('Nüans', null),
  wellDone('İyi iş', null);

  const FeedbackTag(this.title, this.personalArea);
  final String title;
  final String? personalArea;
}

class Feedback {
  Feedback({
    required this.authorId,
    required this.createdAt,
    required this.attempt,
    this.text = '',
    List<FeedbackTag> tags = const [],
  }) : tags = List.unmodifiable(tags.toSet().toList()) {
    if (authorId.trim().isEmpty) throw ArgumentError('Feedback needs author');
    if (attempt < 1) throw ArgumentError('attempt starts at 1');
    if (text.trim().isEmpty && this.tags.isEmpty) {
      throw ArgumentError('Feedback needs text or at least one tag');
    }
  }

  final String authorId;
  final DateTime createdAt;

  /// Which take this feedback is about.
  final int attempt;
  final String text;
  final List<FeedbackTag> tags;

  Map<String, Object?> toJson() => {
    'authorId': authorId,
    'createdAt': writeTime(createdAt),
    'attempt': attempt,
    'text': text,
    'tags': [for (final t in tags) t.name],
  };

  factory Feedback.fromJson(Map<String, Object?> json) => Feedback(
    authorId: reqId(json, 'authorId'),
    createdAt: reqTime(json, 'createdAt'),
    attempt: req<int>(json, 'attempt'),
    text: req<String>(json, 'text'),
    tags: enumList(json, 'tags', FeedbackTag.values),
  );
}

enum ReviewOutcome { accepted, revisionRequested }

class Submission {
  Submission._({
    required this.id,
    required this.choirId,
    required this.assignmentId,
    required this.memberId,
    required this.part,
    required this.status,
    required this.attempt,
    required List<Feedback> feedback,
    this.recordingId,
    this.durationMs,
    this.submittedAt,
    this.listenedAt,
  }) : feedback = List.unmodifiable(feedback) {
    if (id.trim().isEmpty ||
        choirId.trim().isEmpty ||
        assignmentId.trim().isEmpty ||
        memberId.trim().isEmpty) {
      throw ArgumentError('Submission needs ids');
    }
    if (attempt < 1) throw ArgumentError('attempt starts at 1');
    if ((recordingId == null) != (durationMs == null)) {
      throw ArgumentError('Recording id and duration go together');
    }
    if (durationMs != null && durationMs! <= 0) {
      throw ArgumentError('durationMs must be positive');
    }
    if (status != SubmissionStatus.draft &&
        (recordingId == null || submittedAt == null)) {
      throw ArgumentError('Only a draft may lack a sent recording');
    }
    if (listenedAt != null && status == SubmissionStatus.draft) {
      throw ArgumentError('A draft cannot be listened to');
    }
  }

  /// A new, empty draft for [member]. Throws [ArgumentError] unless the
  /// member is a singer of this choir whose part the assignment includes.
  factory Submission.start({
    required String id,
    required Assignment assignment,
    required ChoirMember member,
  }) {
    if (!member.isSinger) throw ArgumentError('Only singers submit');
    if (member.choirId != assignment.choirId) {
      throw ArgumentError('Member is not in this choir');
    }
    final part = member.part;
    if (part == null) throw ArgumentError('Member has no part yet');
    if (!assignment.includes(part)) {
      throw ArgumentError('${part.title} is not in this assignment');
    }
    return Submission._(
      id: id,
      choirId: assignment.choirId,
      assignmentId: assignment.id,
      memberId: member.userId,
      part: part,
      status: SubmissionStatus.draft,
      attempt: 1,
      feedback: const [],
    );
  }

  final String id;
  final String choirId;
  final String assignmentId;
  final String memberId;

  /// The part the singer had when they started; kept even if reassigned.
  final ChoirPart part;
  final SubmissionStatus status;
  final int attempt;
  final String? recordingId;
  final int? durationMs;
  final DateTime? submittedAt;
  final DateTime? listenedAt;

  /// All feedback across takes, oldest first.
  final List<Feedback> feedback;

  bool get awaitsConductor =>
      status == SubmissionStatus.submitted ||
      status == SubmissionStatus.listened;

  Feedback? get latestFeedback => feedback.isEmpty ? null : feedback.last;

  /// Replaces the draft's take. The cap comes from the assignment.
  Submission attachRecording({
    required Assignment assignment,
    required String recordingId,
    required int durationMs,
  }) {
    _require(SubmissionStatus.draft, 'attach a recording');
    _sameAssignment(assignment);
    if (durationMs <= 0) throw ArgumentError('Empty recording');
    if (durationMs > assignment.maxRecordingSeconds * 1000) {
      throw ArgumentError('Recording is longer than the assignment allows');
    }
    return _copy(recordingId: recordingId, durationMs: durationMs);
  }

  /// Drops the draft's take (the singer deletes it before sending).
  Submission clearRecording() {
    _require(SubmissionStatus.draft, 'clear the recording');
    return _copy(clearRecording: true);
  }

  Submission submit(DateTime now) {
    _require(SubmissionStatus.draft, 'submit');
    if (recordingId == null) throw StateError('Nothing recorded yet');
    return _copy(status: SubmissionStatus.submitted, submittedAt: now);
  }

  /// The conductor played the take. Idempotent on an already listened one.
  Submission markListened(ChoirMember conductor, DateTime now) {
    _conductorOf(conductor);
    if (status == SubmissionStatus.listened) return this;
    _require(SubmissionStatus.submitted, 'mark as listened');
    return _copy(status: SubmissionStatus.listened, listenedAt: now);
  }

  /// Closes the current take with written feedback. Reviewing implies
  /// listening, so a submitted take may be reviewed directly.
  Submission review({
    required ChoirMember conductor,
    required ReviewOutcome outcome,
    required DateTime now,
    String text = '',
    List<FeedbackTag> tags = const [],
  }) {
    _conductorOf(conductor);
    if (!awaitsConductor) {
      throw StateError('Cannot review a ${status.name} submission');
    }
    final note = Feedback(
      authorId: conductor.userId,
      createdAt: now,
      attempt: attempt,
      text: text,
      tags: tags,
    );
    return _copy(
      status: outcome == ReviewOutcome.accepted
          ? SubmissionStatus.accepted
          : SubmissionStatus.revisionRequested,
      listenedAt: listenedAt ?? now,
      feedback: [...feedback, note],
    );
  }

  /// The singer starts a new take after a revision request. Earlier
  /// feedback stays attached; the old recording reference is dropped.
  Submission retake() {
    _require(SubmissionStatus.revisionRequested, 'retake');
    return Submission._(
      id: id,
      choirId: choirId,
      assignmentId: assignmentId,
      memberId: memberId,
      part: part,
      status: SubmissionStatus.draft,
      attempt: attempt + 1,
      feedback: feedback,
    );
  }

  void _require(SubmissionStatus expected, String action) {
    if (status != expected) {
      throw StateError('Cannot $action a ${status.name} submission');
    }
  }

  void _sameAssignment(Assignment assignment) {
    if (assignment.id != assignmentId) {
      throw ArgumentError('Different assignment');
    }
  }

  void _conductorOf(ChoirMember member) {
    if (member.role != ChoirRole.conductor || member.choirId != choirId) {
      throw ArgumentError('Only this choir\'s conductor reviews');
    }
  }

  Submission _copy({
    SubmissionStatus? status,
    String? recordingId,
    int? durationMs,
    bool clearRecording = false,
    DateTime? submittedAt,
    DateTime? listenedAt,
    List<Feedback>? feedback,
  }) => Submission._(
    id: id,
    choirId: choirId,
    assignmentId: assignmentId,
    memberId: memberId,
    part: part,
    status: status ?? this.status,
    attempt: attempt,
    recordingId: clearRecording ? null : recordingId ?? this.recordingId,
    durationMs: clearRecording ? null : durationMs ?? this.durationMs,
    submittedAt: submittedAt ?? this.submittedAt,
    listenedAt: listenedAt ?? this.listenedAt,
    feedback: feedback ?? this.feedback,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'choirId': choirId,
    'assignmentId': assignmentId,
    'memberId': memberId,
    'part': part.name,
    'status': status.name,
    'attempt': attempt,
    'recordingId': recordingId,
    'durationMs': durationMs,
    'submittedAt': submittedAt == null ? null : writeTime(submittedAt!),
    'listenedAt': listenedAt == null ? null : writeTime(listenedAt!),
    'feedback': [for (final f in feedback) f.toJson()],
  };

  factory Submission.fromJson(Map<String, Object?> json) => Submission._(
    id: reqId(json, 'id'),
    choirId: reqId(json, 'choirId'),
    assignmentId: reqId(json, 'assignmentId'),
    memberId: reqId(json, 'memberId'),
    part: reqEnum(json, 'part', ChoirPart.values),
    status: reqEnum(json, 'status', SubmissionStatus.values),
    attempt: req<int>(json, 'attempt'),
    recordingId: opt<String>(json, 'recordingId'),
    durationMs: opt<int>(json, 'durationMs'),
    submittedAt: optTime(json, 'submittedAt'),
    listenedAt: optTime(json, 'listenedAt'),
    feedback: [
      for (final f in req<List<Object?>>(json, 'feedback'))
        if (f is Map<String, Object?>)
          Feedback.fromJson(f)
        else
          throw const FormatException('choir: feedback entry is not a map'),
    ],
  );
}

/// Per-part counts for the conductor's tracking table. "Not sent" is a
/// neutral state, never a failure; drafts stay private to the singer and
/// count as not sent.
class PartProgress {
  const PartProgress({
    required this.part,
    required this.singers,
    required this.notSent,
    required this.toReview,
    required this.accepted,
    required this.revisionRequested,
  });

  final ChoirPart part;
  final int singers;
  final int notSent;

  /// Submitted or listened, waiting for written feedback.
  final int toReview;
  final int accepted;
  final int revisionRequested;
}

/// Tracking rows for [assignment], one per assigned part, from the choir's
/// current singers. A take sung for another part (the singer was moved
/// since) does not count toward the new part: they owe a new one.
List<PartProgress> assignmentProgress({
  required Assignment assignment,
  required List<ChoirMember> members,
  required List<Submission> submissions,
}) {
  final byMember = <String, Submission>{
    for (final s in submissions)
      if (s.assignmentId == assignment.id) s.memberId: s,
  };
  return [
    for (final part in assignment.parts)
      () {
        final singers = [
          for (final m in members)
            if (m.isSinger && m.part == part && m.choirId == assignment.choirId)
              m,
        ];
        var notSent = 0, toReview = 0, accepted = 0, revision = 0;
        for (final m in singers) {
          final s = byMember[m.userId];
          if (s == null || s.part != part) {
            notSent++;
            continue;
          }
          switch (s.status) {
            case SubmissionStatus.draft:
              notSent++;
            case SubmissionStatus.submitted || SubmissionStatus.listened:
              toReview++;
            case SubmissionStatus.accepted:
              accepted++;
            case SubmissionStatus.revisionRequested:
              revision++;
          }
        }
        return PartProgress(
          part: part,
          singers: singers.length,
          notSent: notSent,
          toReview: toReview,
          accepted: accepted,
          revisionRequested: revision,
        );
      }(),
  ];
}
