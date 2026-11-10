import 'choir.dart';
import 'submission.dart';

/// Who may see and hear what inside one choir (CHOIR-B, 2026-11-10 user
/// decision). The server enforces the same rules in Postgres RLS
/// (`supabase/migrations`); this is the copy the app uses to decide what to
/// show, and the reference both are tested against.
///
/// - Everyone in the choir sees who has sent what (status, never audio).
/// - A take is heard by its singer, the other singers of the same part
///   (section leader included) and the conductor once it reaches them.
/// - The conductor gets a take only after the part's section leader
///   forwards it, unless the part has no other leader.
/// - Feedback is read by the singer, the part's leaders and the conductor
///   (when the take reached them); never by other singers.
/// - Nothing crosses choirs, and drafts stay with their singer.
class ChoirAccess {
  ChoirAccess(this.members);

  /// The choir's current members (any choir's rows are filtered by id).
  final List<ChoirMember> members;

  ChoirMember? _member(String choirId, String userId) {
    for (final m in members) {
      if (m.choirId == choirId && m.userId == userId) return m;
    }
    return null;
  }

  /// Someone other than the singer leads the take's part.
  bool partHasOtherLeader(Submission s) => members.any(
    (m) => m.choirId == s.choirId && m.leads(s.part) && m.userId != s.memberId,
  );

  /// The take has reached the conductor.
  bool conductorSees(Submission s) {
    if (s.status == SubmissionStatus.draft) return false;
    return s.forwardedAt != null || !partHasOtherLeader(s);
  }

  /// [viewer] is in [s]'s choir: they see its status row.
  bool canSeeStatus(ChoirMember viewer, Submission s) =>
      _member(s.choirId, viewer.userId) != null;

  bool canListen(ChoirMember viewer, Submission s) {
    final me = _member(s.choirId, viewer.userId);
    if (me == null) return false;
    if (me.userId == s.memberId) return true;
    if (s.status == SubmissionStatus.draft) return false;
    if (me.isConductor) return conductorSees(s);
    return me.isSinger && me.part == s.part;
  }

  bool canReadFeedback(ChoirMember viewer, Submission s) {
    final me = _member(s.choirId, viewer.userId);
    if (me == null) return false;
    if (me.userId == s.memberId) return true;
    if (s.status == SubmissionStatus.draft) return false;
    if (me.isConductor) return conductorSees(s);
    return me.leads(s.part);
  }

  /// The leader may forward or return it now.
  bool canLeaderAct(ChoirMember viewer, Submission s) {
    final me = _member(s.choirId, viewer.userId);
    return me != null &&
        me.userId != s.memberId &&
        me.leads(s.part) &&
        s.awaitsLeader;
  }

  /// The conductor may accept or return it now.
  bool canConductorReview(ChoirMember viewer, Submission s) {
    final me = _member(s.choirId, viewer.userId);
    return me != null &&
        me.isConductor &&
        s.awaitsConductor &&
        conductorSees(s);
  }
}
