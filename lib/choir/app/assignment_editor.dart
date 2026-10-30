import 'dart:io';

import 'package:flutter/material.dart';

import '../../trainer/ui/kit.dart';
import '../domain/assignment.dart';
import '../domain/choir.dart';
import '../midi/midi_section.dart';
import '../midi/smf_reader.dart';
import 'choir_scope.dart';
import 'choir_text.dart';

/// Conductor: what to sing, by whom, by when.
class AssignmentEditor extends StatefulWidget {
  const AssignmentEditor({super.key, required this.choir});
  final Choir choir;
  @override
  State<AssignmentEditor> createState() => _AssignmentEditorState();
}

class _AssignmentEditorState extends State<AssignmentEditor> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  final _parts = <ChoirPart>{...ChoirPart.values};
  final _pieces = <AssignmentPiece>[];
  DateTime? _due;
  var _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final store = ChoirScope.read(context).store;
    final nav = context;
    final first = store.now;
    final day = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
      initialDate: _due ?? first.add(const Duration(days: 7)),
    );
    if (day == null || !nav.mounted) return;
    final time = await showTimePicker(
      context: nav,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
    );
    if (time == null) return;
    setState(() {
      _due = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    });
  }

  Future<void> _addPiece() async {
    final piece = await Navigator.of(context).push<AssignmentPiece>(
      MaterialPageRoute(builder: (_) => PieceEditor(choir: widget.choir)),
    );
    if (piece != null) setState(() => _pieces.add(piece));
  }

  Future<void> _publish(BuildContext button) async {
    final scope = ChoirScope.read(context);
    final store = scope.store;
    final text = CT.of(context);
    if (_title.text.trim().isEmpty || _parts.isEmpty || _pieces.isEmpty) {
      toast(context, text.needTitlePartPiece);
      return;
    }
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    final origin = shareOrigin(button);
    final assignment = Assignment(
      id: store.newHex(),
      choirId: widget.choir.id,
      title: _title.text.trim(),
      parts: _parts.toList(),
      pieces: _pieces,
      createdAt: store.now.toUtc(),
      note: _note.text.trim(),
      dueAt: _due?.toUtc(),
      maxRecordingSeconds: Assignment.maxAllowedRecordingSeconds,
    );
    await store.publish(assignment);
    final path = await scope.bundles.exportChoir(widget.choir);
    await scope.files.share(path, origin: origin);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    final materials = MaterialLocalizations.of(context);
    final due = _due;
    return ChoirPage(
      title: text.newAssignment,
      crumb: text.crumbConductorOf(widget.choir.name),
      bottom: Builder(
        builder: (button) => BigButton(
          key: const Key('assignment_publish'),
          label: text.createWork,
          icon: Icons.check_rounded,
          busy: _busy,
          onPressed: () => _publish(button),
        ),
      ),
      children: [
        Text(text.caps(text.assignmentTitle), style: TT.caps),
        const SizedBox(height: 8),
        TextField(
          key: const Key('assignment_title'),
          controller: _title,
          decoration: choirField(text.assignmentTitle),
        ),
        Caption(text.caps(text.parts)),
        PartChips(
          selected: _parts,
          onTap: (p) => setState(() {
            if (!_parts.remove(p)) _parts.add(p);
          }),
        ),
        Caption(text.caps(text.dueDate)),
        ChoirRow(
          key: const Key('assignment_due'),
          icon: Icons.event_outlined,
          title: due == null
              ? text.chooseDue
              : '${materials.formatMediumDate(due)} · '
                    '${materials.formatTimeOfDay(TimeOfDay.fromDateTime(due))}',
          onTap: _pickDue,
        ),
        Caption(text.caps(text.pieces)),
        Text(text.piecesHint, style: TT.small),
        const SizedBox(height: 8),
        for (final (i, p) in _pieces.indexed)
          ChoirRow(
            icon: Icons.music_note_outlined,
            title: p.title,
            subtitle:
                '${text.modeName(p.mode)} · ${text.sectionText(p)} · '
                '${p.withAccompaniment ? text.accompanied : text.unaccompanied}',
            trailing: IconButton(
              tooltip: text.delete,
              icon: const Icon(Icons.close_rounded, color: TC.muted),
              onPressed: () => setState(() => _pieces.removeAt(i)),
            ),
          ),
        OutlinedButton.icon(
          key: const Key('assignment_add_piece'),
          onPressed: _addPiece,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text(text.addPiece),
        ),
        Caption(text.caps(text.workNote)),
        TextField(
          key: const Key('assignment_note'),
          controller: _note,
          maxLines: 4,
          decoration: choirField(text.workNoteHint),
        ),
      ],
    );
  }
}

/// One piece of an assignment, with its MIDI when there is one.
class PieceEditor extends StatefulWidget {
  const PieceEditor({super.key, required this.choir});
  final Choir choir;
  @override
  State<PieceEditor> createState() => _PieceEditorState();
}

class _PieceEditorState extends State<PieceEditor> {
  final _title = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _section = TextEditingController();
  var _mode = PieceMode.solfege;
  var _voicing = 'SATB';
  var _accompanied = true;
  PickedFile? _picked;
  MidiFile? _midi;
  Map<int, ChoirPart> _map = {};
  RightsDeclaration? _rights;
  var _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _from.dispose();
    _to.dispose();
    _section.dispose();
    super.dispose();
  }

  Future<void> _pickMidi() async {
    final scope = ChoirScope.read(context);
    final text = CT.of(context);
    final picked = await scope.files.pick();
    if (picked == null || !mounted) return;
    try {
      final midi = readSmf(await File(picked.path).readAsBytes());
      if (!mounted) return;
      setState(() {
        _picked = picked;
        _midi = midi;
        _map = suggestTrackParts(midi);
        if (_title.text.trim().isEmpty) {
          _title.text = picked.name.replaceAll(RegExp(r'\.[^.]*$'), '');
        }
      });
    } on FormatException {
      if (mounted) toast(context, text.midiBad);
    }
  }

  Future<void> _save() async {
    final scope = ChoirScope.read(context);
    final store = scope.store;
    final text = CT.of(context);
    final from = int.tryParse(_from.text.trim());
    final to = int.tryParse(_to.text.trim());
    final midi = _midi;
    final hasRange = from != null && to != null;
    if (midi != null && hasRange) {
      try {
        MidiSection.of(midi, from: from, to: to);
      } on RangeError {
        toast(context, text.rangeBad);
        return;
      }
    }
    if (hasRange && to < from) {
      toast(context, text.rangeBad);
      return;
    }
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    final picked = _picked;
    final ref = picked == null
        ? null
        : await store.addMidi(
            choir: widget.choir,
            sourcePath: picked.path,
            fileName: picked.name,
            rights: _rights!,
            trackParts: _map,
          );
    nav.pop(
      AssignmentPiece(
        id: store.newHex(),
        title: _title.text.trim(),
        mode: _mode,
        fromMeasure: hasRange ? from : null,
        toMeasure: hasRange ? to : null,
        sectionNote: _section.text.trim(),
        withAccompaniment: _accompanied && ref != null,
        midiReferenceId: ref?.id,
        voicing: _voicing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    final midi = _midi;
    final rightsOk =
        midi == null ||
        (_rights != null && _rights != RightsDeclaration.unknown);
    return ChoirPage(
      title: text.addPiece,
      crumb: text.crumbNewPiece,
      bottom: BigButton(
        key: const Key('piece_save'),
        label: text.savePiece,
        icon: Icons.add_rounded,
        busy: _busy,
        onPressed: _title.text.trim().isNotEmpty && rightsOk ? _save : null,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: TC.primarySoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.queue_music_rounded,
                    color: TC.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(text.startFromMidi, style: TT.title),
                        Text(
                          midi == null
                              ? text.midiHint
                              : text.midiSummary(
                                  midi.measureStarts().length,
                                  midi.tracks
                                      .where((t) => t.notes.isNotEmpty)
                                      .length,
                                ),
                          style: const TextStyle(
                            color: TC.body,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('piece_pick_midi'),
                onPressed: _pickMidi,
                icon: const Icon(Icons.upload_outlined, size: 20),
                label: Text(
                  _picked?.name ?? text.chooseMidi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Caption(text.caps(text.pieceTitle)),
        TextField(
          key: const Key('piece_title'),
          controller: _title,
          onChanged: (_) => setState(() {}),
          decoration: choirField(text.pieceTitle),
        ),
        Caption(text.caps(text.voicingTitle)),
        Wrap(
          spacing: 8,
          children: [
            for (final v in const ['SATB', 'SSAA', 'TTBB'])
              ChoiceChip(
                key: Key('voicing_$v'),
                label: Text(
                  v,
                  style: TextStyle(
                    color: _voicing == v ? Colors.white : TC.body,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                selected: _voicing == v,
                checkmarkColor: Colors.white,
                onSelected: (_) => setState(() => _voicing = v),
              ),
          ],
        ),
        Caption(text.caps(text.howSung)),
        Wrap(
          spacing: 8,
          children: [
            for (final m in PieceMode.values)
              ChoiceChip(
                key: Key('piece_mode_${m.name}'),
                label: Text(
                  text.modeName(m),
                  style: TextStyle(
                    color: _mode == m ? Colors.white : TC.body,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                selected: _mode == m,
                checkmarkColor: Colors.white,
                onSelected: (_) => setState(() => _mode = m),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(text.modeHint(_mode), style: TT.small),
        Caption(text.caps(text.rangeHeading)),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('piece_from'),
                controller: _from,
                keyboardType: TextInputType.number,
                decoration: choirField(text.rangeStart),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const Key('piece_to'),
                controller: _to,
                keyboardType: TextInputType.number,
                decoration: choirField(text.rangeEnd),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(text.wholeWork, style: TT.small),
        const SizedBox(height: 10),
        TextField(
          controller: _section,
          decoration: choirField(text.sectionNote),
        ),
        if (midi != null) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('piece_accompanied'),
            contentPadding: EdgeInsets.zero,
            value: _accompanied,
            onChanged: (v) => setState(() => _accompanied = v),
            title: Text(text.withAccompaniment, style: TT.title),
            subtitle: Text(text.accompanimentHint, style: TT.small),
          ),
          Caption(text.caps(text.partMap)),
          for (final track in midi.tracks)
            if (track.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        track.name ?? '${track.index + 1}',
                        style: TT.body,
                      ),
                    ),
                    DropdownButton<ChoirPart?>(
                      key: Key('track_${track.index}'),
                      value: _map[track.index],
                      underline: const SizedBox.shrink(),
                      items: [
                        DropdownMenuItem(child: Text(text.accompanimentTrack)),
                        for (final p in ChoirPart.values)
                          DropdownMenuItem(
                            value: p,
                            child: Text(text.partName(p)),
                          ),
                      ],
                      onChanged: (p) => setState(() {
                        if (p == null) {
                          _map.remove(track.index);
                        } else {
                          _map[track.index] = p;
                        }
                      }),
                    ),
                  ],
                ),
              ),
          Caption(text.caps(text.rightsTitle)),
          for (final r in RightsDeclaration.values)
            ChoiceTile(
              key: Key('rights_${r.name}'),
              label: text.rightsName(r),
              selected: _rights == r,
              multi: false,
              onTap: () => setState(() => _rights = r),
            ),
          if (_rights == RightsDeclaration.unknown)
            Text(text.rightsBlocked, style: TT.small),
        ],
      ],
    );
  }
}
