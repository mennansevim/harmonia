import 'dart:async';

import 'package:flutter/material.dart';

import '../../trainer/ui/kit.dart';
import '../audio/take_engine.dart';
import '../domain/resource.dart';
import 'choir_scope.dart';
import 'choir_text.dart';

/// Scores, rehearsal recordings for those who missed it, and notes. What the
/// conductor adds goes out with the choir package; what a singer adds stays
/// on their own device.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.choirId});
  final String choirId;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  ResourceKind? _kind;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  IconData _icon(ResourceKind k) => switch (k) {
    ResourceKind.score => Ic.fileMusic,
    ResourceKind.rehearsalRecording => Ic.headphones,
    ResourceKind.note => Ic.notebookPen,
  };

  @override
  Widget build(BuildContext context) {
    final store = ChoirScope.of(context).store;
    final text = CT.of(context);
    final choir = store.choir(widget.choirId);
    final query = _search.text.trim().toLowerCase();
    final browsing = _kind == null && query.isEmpty;
    final items = [
      for (final r in store.resourcesOf(widget.choirId))
        if ((_kind == null || r.kind == _kind) &&
            (query.isEmpty ||
                r.title.toLowerCase().contains(query) ||
                r.text.toLowerCase().contains(query)))
          r,
    ];
    Widget chip(String label, ResourceKind? kind, String key) => OptionChip(
      key: Key(key),
      label: label,
      selected: _kind == kind,
      onTap: () => setState(() => _kind = kind),
    );
    return ChoirPage(
      title: text.library,
      crumb: text.crumbArchive(choir?.name ?? ''),
      bottom: BigButton(
        key: const Key('library_add'),
        label: text.addResourceCta,
        icon: Ic.plus,
        onPressed: () => showTrainerSheet<void>(
          context,
          (_) => _AddSheet(choirId: widget.choirId),
        ),
      ),
      children: [
        TextField(
          key: const Key('library_search'),
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: choirField(text.searchLibrary).copyWith(
            prefixIcon: const Icon(Ic.search, size: 18, color: TC.muted),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            chip(text.filterAll, null, 'library_all'),
            for (final k in ResourceKind.values)
              chip(text.kindName(k), k, 'library_${k.name}'),
          ],
        ),
        const SizedBox(height: 20),
        if (browsing) ...[
          HeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        text.caps(text.archiveEyebrow),
                        style: const TextStyle(
                          color: TC.sun,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const Icon(Ic.library, color: TC.sun, size: 28),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  text.archiveHeadline,
                  style: TT.display.copyWith(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  text.archiveBody,
                  style: const TextStyle(
                    color: TC.heroMuted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Caption(text.caps(text.resourceTypes)),
          for (final k in ResourceKind.values)
            ChoirRow(
              key: Key('library_type_${k.name}'),
              icon: _icon(k),
              title: text.kindName(k),
              subtitle: text.kindHint(k),
              onTap: () => setState(() => _kind = k),
            ),
          Text(text.libraryHint, style: TT.small),
        ] else if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(
              query.isEmpty ? text.libraryEmpty : text.noMatches,
              textAlign: TextAlign.center,
              style: TT.body,
            ),
          )
        else
          for (final item in items) _Item(item: item, icon: _icon(item.kind)),
      ],
    );
  }
}

class _Item extends StatefulWidget {
  const _Item({required this.item, required this.icon});
  final ChoirResource item;
  final IconData icon;
  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  ChoirPlayer? _player;
  StreamSubscription<bool>? _sub;
  var _playing = false;

  @override
  void dispose() {
    _sub?.cancel();
    _player?.close();
    super.dispose();
  }

  Future<void> _open() async {
    final scope = ChoirScope.read(context);
    final text = CT.of(context);
    final item = widget.item;
    if (item.kind == ResourceKind.note) {
      await showTrainerSheet<void>(
        context,
        (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(item.title, style: TT.h3),
            const SizedBox(height: 8),
            Text(item.text, style: TT.body),
          ],
        ),
      );
      return;
    }
    final path = await scope.store.mediaPath(item.fileId!);
    if (item.kind == ResourceKind.rehearsalRecording) {
      if (_player == null) {
        final player = _player = scope.newPlayer();
        _sub = player.playingChanges.listen((p) {
          if (mounted) setState(() => _playing = p);
        });
        try {
          await player.open(path);
        } catch (_) {
          if (mounted) toast(context, text.cannotOpen);
          return;
        }
      }
      await (_playing ? _player!.pause() : _player!.play());
      return;
    }
    final opened = await scope.files.open(path);
    if (!opened && mounted) toast(context, text.cannotOpen);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final materials = MaterialLocalizations.of(context);
    final day = item.rehearsalOn?.toLocal();
    return ChoirRow(
      key: Key('resource_${item.id}'),
      icon: _playing ? Ic.pause : widget.icon,
      title: item.title,
      subtitle: day == null ? null : materials.formatMediumDate(day),
      onTap: _open,
    );
  }
}

class _AddSheet extends StatefulWidget {
  const _AddSheet({required this.choirId});
  final String choirId;
  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  var _kind = ResourceKind.rehearsalRecording;
  PickedFile? _file;
  DateTime? _day;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await ChoirScope.read(context).files.pick();
    if (picked == null) return;
    setState(() {
      _file = picked;
      if (_title.text.trim().isEmpty) {
        _title.text = picked.name.replaceAll(RegExp(r'\.[^.]*$'), '');
      }
    });
  }

  Future<void> _pickDay() async {
    final now = ChoirScope.read(context).store.now;
    final day = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 730)),
      lastDate: now,
      initialDate: now,
    );
    if (day != null) setState(() => _day = day);
  }

  bool get _ready =>
      _title.text.trim().isNotEmpty &&
      (_kind == ResourceKind.note
          ? _note.text.trim().isNotEmpty
          : _file != null);

  Future<void> _save() async {
    final scope = ChoirScope.read(context);
    final store = scope.store;
    final text = CT.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final choir = store.choir(widget.choirId)!;
    final file = _kind == ResourceKind.note ? null : _file;
    await store.addResource(
      ChoirResource(
        id: store.newHex(),
        choirId: choir.id,
        kind: _kind,
        title: _title.text.trim(),
        authorId: store.myId,
        createdAt: store.now.toUtc(),
        text: _kind == ResourceKind.note ? _note.text.trim() : '',
        fileId: file == null
            ? null
            : await store.addMedia(file.path, file.name),
        fileName: file?.name,
        rehearsalOn: _day?.toUtc(),
      ),
    );
    nav.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          store.isConductor(choir) ? text.shareLibraryHint : text.personalOnly,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    final materials = MaterialLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text.addResourceCta, style: TT.h3),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final k in ResourceKind.values)
                OptionChip(
                  key: Key('kind_${k.name}'),
                  label: text.kindName(k),
                  selected: _kind == k,
                  onTap: () => setState(() => _kind = k),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_kind != ResourceKind.note) ...[
            OutlinedButton.icon(
              key: const Key('resource_pick'),
              onPressed: _pick,
              icon: const Icon(Ic.paperclip, size: 18),
              label: Text(_file?.name ?? text.chooseFile),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            key: const Key('resource_title'),
            controller: _title,
            onChanged: (_) => setState(() {}),
            decoration: choirField(text.resourceTitle),
          ),
          if (_kind == ResourceKind.note) ...[
            const SizedBox(height: 10),
            TextField(
              key: const Key('resource_note'),
              controller: _note,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: choirField(text.resourceText),
            ),
          ],
          if (_kind == ResourceKind.rehearsalRecording)
            TextLink(
              _day == null
                  ? text.rehearsalDay
                  : materials.formatMediumDate(_day!),
              onTap: _pickDay,
            ),
          const SizedBox(height: 12),
          BigButton(
            key: const Key('resource_save'),
            label: text.save,
            onPressed: _ready ? _save : null,
          ),
        ],
      ),
    );
  }
}
