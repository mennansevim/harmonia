import 'dart:io';

import '../domain/assignment.dart';
import '../domain/choir.dart';
import '../domain/resource.dart';
import '../domain/submission.dart';

/// Kinds of file the choir server keeps in the choir's Drive.
enum RemoteMediaKind { repertoire, take, voiceNote }

/// Everything of one online choir the signed-in person may read.
class OnlineSnapshot {
  const OnlineSnapshot({
    required this.choir,
    required this.members,
    required this.references,
    required this.resources,
    required this.assignments,
    required this.submissions,
  });
  final Choir choir;
  final List<ChoirMember> members;
  final List<ReferenceAsset> references;
  final List<ChoirResource> resources;
  final List<Assignment> assignments;
  final List<Submission> submissions;
}

/// The server behind an online choir (ADR-041), as [ChoirStore] uses it.
/// Media ids are in the store's own form (`<32 hex>.<ext>`), so a file
/// fetched once sits in the same media folder as any local one.
abstract interface class ChoirRemote {
  String? get userId;

  Future<OnlineSnapshot> pull(String choirId);

  /// Uploads [file] to the choir's Drive; returns its media id. [work]
  /// files it under that work (`Eserler/<work>`), [shelf] under the library
  /// (`score`, `rehearsal`), [part] puts a voice note beside the take it
  /// answers; [label] becomes part of the Drive file name.
  Future<String> upload(
    String choirId,
    RemoteMediaKind kind,
    File file, {
    String label = '',
    String? work,
    String? shelf,
    String? part,
  });

  /// Fetches a file the person may read into [to].
  Future<void> download(String mediaId, File to);

  Future<void> putReference(ReferenceAsset asset);
  Future<void> putResource(ChoirResource resource);
  Future<void> deleteResource(ChoirResource resource);
  Future<void> putAssignment(Assignment assignment);

  /// Sends [take] (a submitted copy of the draft; its recording uploaded).
  Future<void> submitTake(Submission take);
  Future<void> markListened(Submission s);

  /// Section leader: forward to the conductor or ask for a retake.
  Future<void> leaderDecide(
    Submission s, {
    required bool forward,
    Feedback? note,
  });

  Future<void> conductorReview(
    Submission s, {
    required bool accept,
    required Feedback note,
  });
}

/// `<uuid>` ↔ media id. The server's media rows are uuids; the store keeps
/// `<32 hex>.<ext>` names.
String mediaIdOf(String uuid, String ext) => '${uuid.replaceAll('-', '')}.$ext';

String uuidOfMedia(String mediaId) {
  final hex = mediaId.split('.').first;
  if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(hex)) {
    throw ArgumentError('Not a server media id: $mediaId');
  }
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
