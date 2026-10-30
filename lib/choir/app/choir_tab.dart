import 'package:flutter/material.dart';

import '../../trainer/stats/stats_tab.dart';
import '../../trainer/ui/kit.dart';
import '../data/choir_bundle.dart';
import '../domain/choir.dart';
import 'choir_scope.dart';
import 'choir_screen.dart';
import 'choir_text.dart';

/// Picks a `.harmonia` file and routes it: join, update, take or feedback.
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

/// The Koro tab: the person's choirs, or how to start one.
class ChoirTab extends StatelessWidget {
  const ChoirTab({super.key, this.asTab = true});
  final bool asTab;

  @override
  Widget build(BuildContext context) {
    final store = ChoirScope.of(context).store;
    final text = CT.of(context);
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        if (store.loadError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              border: TC.coral,
              child: Text(text.loadErrorBody, style: TT.body),
            ),
          ),
        if (store.choirs.isEmpty)
          HeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text.introTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  text.introBody,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 14,
                    height: 1.42,
                  ),
                ),
              ],
            ),
          ),
        for (final choir in store.choirs)
          ChoirRow(
            key: Key('choir_${choir.id}'),
            icon: Icons.groups_rounded,
            title: choir.name,
            subtitle: _subtitle(context, choir),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChoirScreen(choirId: choir.id),
              ),
            ),
          ),
        const SizedBox(height: 14),
        BigButton(
          key: const Key('choir_open_package'),
          label: store.choirs.isEmpty ? text.openPackage : text.openFile,
          icon: Icons.file_open_outlined,
          onPressed: () => openBundleFlow(context),
        ),
        TextLink(
          text.createChoir,
          onTap: () =>
              showTrainerSheet<void>(context, (_) => const _CreateSheet()),
        ),
        const SizedBox(height: 6),
        Text(text.howSharing, textAlign: TextAlign.center, style: TT.small),
      ],
    );
    if (!asTab) return ChoirPage(title: text.tabLabel, children: [list]);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          tabHeader(text.tabLabel, text.hubSubtitle),
          Expanded(child: list),
        ],
      ),
    );
  }

  String _subtitle(BuildContext context, Choir choir) {
    final scope = ChoirScope.of(context);
    final text = CT.of(context);
    final store = scope.store;
    if (store.isConductor(choir)) {
      return '${text.conductorRole} · '
          '${text.queueCount(store.reviewQueue(choir.id).length)}';
    }
    final part = store.meIn(choir.id)?.part;
    return part == null ? text.tabLabel : text.partName(part);
  }
}
