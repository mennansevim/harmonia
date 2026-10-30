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
    if (choir == null) return ChoirPage(title: '', children: const []);
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

    return ChoirPage(
      title: choir.name,
      children: [
        if (conductor)
          ChoirRow(
            key: const Key('choir_queue'),
            icon: Icons.headphones_rounded,
            title: text.listeningQueue,
            subtitle: text.queueCount(queue.length),
            onTap: queue.isEmpty
                ? null
                : () => push(ReviewScreen(submissionId: queue.first.id)),
          ),
        Caption(text.assignments.toUpperCase()),
        if (mine.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              conductor ? text.noAssignments : text.noAssignmentsSinger,
              style: TT.small,
            ),
          ),
        for (final a in mine)
          _AssignmentCard(
            assignment: a,
            conductor: conductor,
            onTap: () => push(AssignmentScreen(assignmentId: a.id)),
          ),
        if (conductor)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: BigButton(
              key: const Key('choir_new_assignment'),
              label: text.newAssignment,
              icon: Icons.add_rounded,
              onPressed: () => push(AssignmentEditor(choir: choir)),
            ),
          ),
        Caption(text.library.toUpperCase()),
        ChoirRow(
          key: const Key('choir_library'),
          icon: Icons.library_music_outlined,
          title: text.library,
          subtitle: text.librarySub,
          onTap: () => push(LibraryScreen(choirId: choirId)),
        ),
        if (conductor) ...[
          Builder(
            builder: (context) => ChoirRow(
              key: const Key('choir_share'),
              icon: Icons.ios_share_rounded,
              title: text.shareChoir,
              subtitle: text.shareChoirSub,
              onTap: () => shareChoirPackage(context, choir),
            ),
          ),
          Caption(text.singers.toUpperCase()),
          if (singers.isEmpty) Text(text.singersEmpty, style: TT.small),
          for (final s in singers)
            ChoirRow(
              icon: Icons.person_outline_rounded,
              title: s.displayName,
              subtitle: s.part == null ? null : text.partName(s.part!),
            ),
        ] else
          ChoirRow(
            icon: Icons.file_open_outlined,
            title: text.openFile,
            onTap: () => openBundleFlow(context),
          ),
        const SizedBox(height: 10),
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

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
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
    final a = assignment;
    final due = a.dueAt;
    final sent = a.pieces.where((p) {
      final s = store.mySubmission(a.id, p.id);
      return s != null &&
          s.status != SubmissionStatus.draft &&
          s.status != SubmissionStatus.revisionRequested;
    }).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        key: Key('assignment_${a.id}'),
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.title, style: TT.title),
            const SizedBox(height: 6),
            Tag(
              due == null ? text.noDue : text.dueLabel(store.now, due),
              color: due != null && a.isLate(store.now) ? TC.muted : TC.primary,
            ),
            const SizedBox(height: 6),
            Text(
              conductor
                  ? a.parts.map(text.partName).join(' · ')
                  : text.piecesDone(sent, a.pieces.length),
              style: TT.small,
            ),
          ],
        ),
      ),
    );
  }
}
