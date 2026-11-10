import 'package:flutter/material.dart';

import '../../trainer/ui/kit.dart';
import '../data/choir_bundle.dart';
import '../domain/choir.dart';
import '../online/online_choir_controller.dart';
import '../online/online_section.dart';
import 'assignment_screen.dart';
import 'choir_scope.dart';
import 'choir_screen.dart';
import 'choir_text.dart';

/// Picks a `.resonia` file and routes it: join, update, take or feedback.
Future<void> openBundleFlow(BuildContext context) async {
  final scope = ChoirScope.read(context);
  final text = CT.of(context);
  final picked = await scope.files.pick();
  if (picked == null || !context.mounted) return;
  try {
    final result = await scope.bundles.open(picked.path);
    if (!context.mounted) return;
    if (result.outcome == BundleOutcome.needsJoin) {
      await showTrainerSheet<void>(
        context,
        (sheet) => _JoinSheet(preview: result.preview!),
      );
    } else {
      toast(context, text.bundleOutcome(result.outcome));
    }
  } on BundleRejected catch (e) {
    if (context.mounted) toast(context, text.bundleProblem(e.problem));
  }
}

class _JoinSheet extends StatefulWidget {
  const _JoinSheet({required this.preview});
  final JoinPreview preview;
  @override
  State<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends State<_JoinSheet> {
  final _name = TextEditingController();
  ChoirPart? _part;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _name.text = ChoirScope.read(context).store.myName ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final scope = ChoirScope.read(context);
    final text = CT.of(context);
    setState(() => _busy = true);
    try {
      await scope.bundles.join(
        widget.preview,
        displayName: _name.text,
        part: _part!,
      );
      if (mounted) Navigator.pop(context);
    } on BundleRejected catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      toast(context, text.bundleProblem(e.problem));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    final ready = _name.text.trim().isNotEmpty && _part != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text.joinTitle, style: TT.h3),
          const SizedBox(height: 4),
          Text(widget.preview.choir.name, style: TT.body),
          const SizedBox(height: 14),
          TextField(
            key: const Key('join_name'),
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: choirField(text.yourName),
          ),
          const SizedBox(height: 14),
          Text(text.whichPart, style: TT.title),
          const SizedBox(height: 8),
          PartChips(
            selected: {?_part},
            onTap: (p) => setState(() => _part = p),
          ),
          const SizedBox(height: 16),
          BigButton(
            key: const Key('join_confirm'),
            label: text.join,
            busy: _busy,
            onPressed: ready ? _join : null,
          ),
        ],
      ),
    );
  }
}

class _CreateSheet extends StatefulWidget {
  const _CreateSheet();
  @override
  State<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends State<_CreateSheet> {
  final _choir = TextEditingController();
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name.text = ChoirScope.read(context).store.myName ?? '';
  }

  @override
  void dispose() {
    _choir.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    final ready = _choir.text.trim().isNotEmpty && _name.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text.createChoir, style: TT.h3),
          const SizedBox(height: 14),
          TextField(
            key: const Key('create_choir_name'),
            controller: _choir,
            onChanged: (_) => setState(() {}),
            decoration: choirField(text.choirName),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('create_my_name'),
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: choirField(text.yourName),
          ),
          const SizedBox(height: 16),
          BigButton(
            key: const Key('create_confirm'),
            label: text.create,
            onPressed: ready
                ? () async {
                    final store = ChoirScope.read(context).store;
                    final nav = Navigator.of(context);
                    await store.createChoir(_choir.text, _name.text);
                    nav.pop();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

/// The Koro tab: the person's choirs, or how to begin.
class ChoirTab extends StatelessWidget {
  const ChoirTab({super.key, this.asTab = true, this.trailing});
  final bool asTab;

  /// Top-right slot on the tab (the trainer's profile button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final store = ChoirScope.of(context).store;
    final text = CT.of(context);
    void create() =>
        showTrainerSheet<void>(context, (_) => const _CreateSheet());
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text.caps(text.eyebrowChoir), style: TT.crumb),
                  const SizedBox(height: 10),
                  Text(text.tabLabel, style: TT.h1),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        if (store.loadError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AppCard(
              border: TC.peach,
              child: Text(text.loadErrorBody, style: TT.body),
            ),
          ),
        if (OnlineChoirScope.maybeOf(context) != null) ...[
          // Server build (ADR-041): the online choir leads; choirs kept on
          // this device from packages stay reachable below it.
          const OnlineChoirSection(),
          // Mirrored online choirs open from the section above.
          if (store.choirs.any((c) => !store.isOnline(c.id))) ...[
            Caption(text.caps(text.deviceChoirs)),
            for (final choir in store.choirs)
              if (!store.isOnline(choir.id)) _ChoirCard(choir: choir),
          ],
          TextLink(text.openPackage, onTap: () => openBundleFlow(context)),
        ] else if (store.choirs.isEmpty)
          ..._empty(context, text, create)
        else ...[
          Caption(text.caps(text.myChoirs)),
          for (final choir in store.choirs) _ChoirCard(choir: choir),
          Caption(text.caps(text.joinAnother)),
          OutlinedButton.icon(
            key: const Key('choir_open_package'),
            onPressed: () => openBundleFlow(context),
            icon: const Icon(Ic.fileInput, size: 18),
            label: Text(text.openInvite),
          ),
          const SizedBox(height: 12),
          Text(text.inviteHint, style: TT.small),
          TextLink(text.createChoir, onTap: create),
        ],
      ],
    );
    if (asTab) return SafeArea(bottom: false, child: body);
    return Scaffold(
      backgroundColor: TC.canvas,
      appBar: AppBar(backgroundColor: TC.canvas),
      body: body,
    );
  }

  List<Widget> _empty(BuildContext context, CT text, VoidCallback create) => [
    const SizedBox(height: 56),
    const _Bars(),
    const SizedBox(height: 26),
    Text(
      text.emptyHeadline,
      textAlign: TextAlign.center,
      style: TT.display.copyWith(height: 1.2),
    ),
    const SizedBox(height: 26),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        text.emptyBody,
        style: TT.body.copyWith(color: TC.muted, fontSize: 14),
      ),
    ),
    const SizedBox(height: 58),
    BigButton(
      key: const Key('choir_open_package'),
      label: text.openPackage,
      icon: Ic.fileInput,
      onPressed: () => openBundleFlow(context),
    ),
    Caption(text.caps(text.howItWorks)),
    Text(text.howBody, style: TT.body.copyWith(color: TC.muted)),
    TextLink(text.createChoir, onTap: create),
  ];
}

/// Five voices of different heights, one lime: the empty state's picture.
class _Bars extends StatelessWidget {
  const _Bars();

  @override
  Widget build(BuildContext context) {
    Widget bar(double height, Color color, [Widget? child]) => Container(
      width: 29,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          bar(74, TC.primarySoft),
          bar(124, TC.primary),
          bar(94, TC.sun, const Icon(Ic.music2, size: 21)),
          bar(142, TC.primary),
          bar(74, TC.primarySoft),
        ],
      ),
    );
  }
}

class _ChoirCard extends StatelessWidget {
  const _ChoirCard({required this.choir});
  final Choir choir;

  @override
  Widget build(BuildContext context) {
    final store = ChoirScope.of(context).store;
    final text = CT.of(context);
    final conductor = store.isConductor(choir);
    final work = store.assignmentsOf(choir.id).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: TC.sun,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Ic.users, color: TC.onSun),
                    ),
                  ),
                  TiltTag(conductor ? text.conductorTag : text.memberTag),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                choir.name,
                style: TT.display.copyWith(color: Colors.white, fontSize: 26),
              ),
              const SizedBox(height: 12),
              Text(
                conductor
                    ? text.queueCount(store.reviewQueue(choir.id).length)
                    : text.partName(
                        store.meIn(choir.id)?.part ?? ChoirPart.soprano,
                      ),
                style: const TextStyle(
                  color: TC.heroMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              BigButton(
                key: Key('choir_${choir.id}'),
                label: text.goToChoir,
                icon: Ic.arrowUpRight,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChoirScreen(choirId: choir.id),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (work != null)
          ChoirRow(
            icon: Ic.calendarDays,
            title: work.title,
            subtitle: work.note.isEmpty ? null : work.note,
            trailing: work.dueAt == null
                ? null
                : TiltTag(
                    text.dueLabel(store.now, work.dueAt!),
                    color: TC.primarySoft,
                  ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AssignmentScreen(assignmentId: work.id),
              ),
            ),
          ),
      ],
    );
  }
}
