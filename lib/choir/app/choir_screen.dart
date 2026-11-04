import 'package:flutter/material.dart';

import '../../trainer/ui/kit.dart';
import '../domain/assignment.dart';
import '../domain/choir.dart';
import '../domain/submission.dart';
import 'assignment_editor.dart';
import 'assignment_screen.dart';
import 'choir_scope.dart';
import 'choir_tab.dart';
import 'choir_text.dart';
import 'library_screen.dart';
import 'review_screen.dart';

Future<void> shareChoirPackage(BuildContext context, Choir choir) async {
  final scope = ChoirScope.read(context);
  final origin = shareOrigin(context);
  final path = await scope.bundles.exportChoir(choir);
  await scope.files.share(path, origin: origin);
}

/// One choir. The same place for both roles; a conductor sees the queue and
/// the tools, a singer sees their work.
class ChoirScreen extends StatelessWidget {
  const ChoirScreen({super.key, required this.choirId});
  final String choirId;

  @override
  Widget build(BuildContext context) {
    final store = ChoirScope.of(context).store;
    final text = CT.of(context);
    final choir = store.choir(choirId);
    if (choir == null) return const ChoirPage(title: '', children: []);
    final conductor = store.isConductor(choir);
    final me = store.meIn(choirId);
    final work = store.assignmentsOf(choirId);
    final mine = conductor
        ? work
        : [
            for (final a in work)
              if (me?.part != null && a.includes(me!.part!)) a,
          ];
    final queue = store.reviewQueue(choirId);
    final singers = store.singersOf(choirId);
    void push(Widget screen) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));

    final latest = mine.firstOrNull;
    final others = mine.skip(1);
    return ChoirPage(
      title: choir.name,
      crumb: conductor ? text.crumbConductor : text.crumbMember,
      bottom: conductor
          ? BigButton(
              key: const Key('choir_new_assignment'),
              label: text.newAssignment,
              icon: Ic.plus,
              onPressed: () => push(AssignmentEditor(choir: choir)),
            )
          : OutlinedButton.icon(
              key: const Key('choir_open_file'),
              onPressed: () => openBundleFlow(context),
              icon: const Icon(Ic.fileInput, size: 18),
              label: Text(text.openWorkFile),
            ),
      children: [
        if (conductor)
          ChoirRow(
            key: const Key('choir_queue'),
            color: TC.sun,
            icon: Ic.headphones,
            title: text.listeningQueue,
            subtitle: text.queueCount(queue.length),
            onTap: queue.isEmpty
                ? null
                : () => push(ReviewScreen(submissionId: queue.first.id)),
          ),
        if (!conductor)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(text.caps(text.workspace), style: TT.caps)),
              TiltTag(text.memberTag, color: TC.primarySoft),
            ],
          ),
        if (conductor)
          Caption(text.caps(text.latestWork))
        else
          const SizedBox(height: 20),
        if (latest == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              conductor ? text.noAssignments : text.noAssignmentsSinger,
              style: TT.small,
            ),
          )
        else
          _LatestWork(
            assignment: latest,
            conductor: conductor,
            onTap: () => push(AssignmentScreen(assignmentId: latest.id)),
          ),
        const SizedBox(height: 20),
        for (final a in others)
          ChoirRow(
            key: Key('assignment_${a.id}'),
            icon: Ic.calendarDays,
            title: a.title,
            subtitle: a.dueAt == null
                ? text.noDue
                : text.dueLabel(store.now, a.dueAt!),
            onTap: () => push(AssignmentScreen(assignmentId: a.id)),
          ),
        ChoirRow(
          key: const Key('choir_library'),
          icon: Ic.library,
          title: text.library,
          subtitle: text.librarySub,
          onTap: () => push(LibraryScreen(choirId: choirId)),
        ),
        if (!conductor && latest != null) ...[
          const SizedBox(height: 11),
          for (final p in latest.pieces) _PieceCard(piece: p, text: text),
          Text(text.deviceOnly, style: TT.small),
        ],
        if (conductor) ...[
          Builder(
            builder: (context) => ChoirRow(
              key: const Key('choir_share'),
              icon: Ic.share2,
              title: text.shareChoir,
              subtitle: text.shareChoirSub,
              onTap: () => shareChoirPackage(context, choir),
            ),
          ),
          Caption(text.caps(text.singers)),
          if (singers.isEmpty) Text(text.singersEmpty, style: TT.small),
          for (final s in singers)
            ChoirRow(
              icon: Ic.userRound,
              title: s.displayName,
              subtitle: s.part == null ? null : text.partName(s.part!),
            ),
        ],
        const SizedBox(height: 6),
        TextLink(
          text.leaveChoir,
          onTap: () async {
            final store = ChoirScope.read(context).store;
            final nav = Navigator.of(context);
            final ok = await confirmDialog(
              context,
              title: text.leaveTitle,
              message: text.leaveBody,
              cancel: text.cancel,
              confirm: text.delete,
            );
            if (!ok) return;
            nav.pop();
            await store.forgetChoir(choir);
          },
        ),
      ],
    );
  }
}

class _PieceCard extends StatelessWidget {
  const _PieceCard({required this.piece, required this.text});
  final AssignmentPiece piece;
  final CT text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      padding: const EdgeInsets.all(20),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text.caps(text.thisPiece), style: TT.caps),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  piece.title,
                  style: TT.display.copyWith(fontSize: 28),
                ),
              ),
              const Icon(Ic.music2, color: TC.primary, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${piece.voicing} · ${text.modeName(piece.mode)} · '
            '${text.sectionText(piece)}',
            style: TT.body.copyWith(color: TC.muted),
          ),
        ],
      ),
    ),
  );
}

class _LatestWork extends StatelessWidget {
  const _LatestWork({
    required this.assignment,
    required this.conductor,
    required this.onTap,
  });
  final Assignment assignment;
  final bool conductor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = ChoirScope.of(context).store;
    final text = CT.of(context);
    final materials = MaterialLocalizations.of(context);
    final a = assignment;
    final due = a.dueAt;
    final sent = a.pieces.where((p) {
      final s = store.mySubmission(a.id, p.id);
      return s != null &&
          s.status != SubmissionStatus.draft &&
          s.status != SubmissionStatus.revisionRequested;
    }).length;
    final detail = conductor
        ? due == null
              ? text.noDue
              : text.endsOn(materials.formatShortMonthDay(due.toLocal()))
        : text.piecesDone(sent, a.pieces.length);
    return HeroCard(
      key: Key('assignment_${a.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text.caps(conductor ? text.workSummary : text.latestWork),
            style: TextStyle(
              color: conductor ? TC.heroMuted : TC.sun,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            a.title,
            style: TT.display.copyWith(
              color: Colors.white,
              fontSize: 30,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  detail,
                  style: const TextStyle(
                    color: TC.heroMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
              Flexible(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TiltTag(
                    conductor
                        ? text.conductorWork
                        : due == null
                        ? text.noDue
                        : text.dueLabel(store.now, due),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BigButton(
            key: const Key('choir_open_work'),
            label: conductor ? text.seeSubmissions : text.openWork,
            icon: Ic.arrowUpRight,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}
