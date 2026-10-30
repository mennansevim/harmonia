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
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, required this.choirId});
  final String choirId;

  @override
  Widget build(BuildContext context) {
    final store = ChoirScope.of(context).store;
    final text = CT.of(context);
    final items = store.resourcesOf(choirId);
    return ChoirPage(
      title: text.library,
      bottom: BigButton(
        key: const Key('library_add'),
        label: text.addResource,
        icon: Icons.add_rounded,
        onPressed: () =>
            showTrainerSheet<void>(context, (_) => _AddSheet(choirId: choirId)),
      ),
      children: [
        Text(text.libraryHint, style: TT.small),
        if (items.isEmpty) ...[
          const SizedBox(height: 24),
          Text(text.libraryEmpty, textAlign: TextAlign.center, style: TT.body),
        ],
        for (final kind in ResourceKind.values)
          if (items.any((r) => r.kind == kind)) ...[
            Caption(text.kindName(kind).toUpperCase()),
            for (final item in items.where((r) => r.kind == kind))
              _Item(item: item),
          ],
      ],
    );
  }
}

class _Item extends StatefulWidget {
  const _Item({required this.item});
  final ChoirResource item;
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
      icon: switch (item.kind) {
        ResourceKind.score => Icons.description_outlined,
        ResourceKind.rehearsalRecording =>
          _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        ResourceKind.note => Icons.sticky_note_2_outlined,
      },
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
          Text(text.addResource, style: TT.h3),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final k in ResourceKind.values)
                ChoiceChip(
                  key: Key('kind_${k.name}'),
                  label: Text(text.kindName(k)),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_kind != ResourceKind.note) ...[
            OutlinedButton.icon(
              key: const Key('resource_pick'),
              onPressed: _pick,
              icon: const Icon(Icons.attach_file_rounded),
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
