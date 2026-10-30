import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../trainer/ui/kit.dart';
import '../audio/plugin_take_engine.dart';
import '../audio/take_engine.dart';
import '../data/choir_bundle.dart';
import '../data/choir_store.dart';
import '../domain/choir.dart';
import 'choir_text.dart';

class PickedFile {
  const PickedFile(this.path, this.name);
  final String path;
  final String name;
}

/// The OS file dialogs, behind a seam so screens stay testable.
abstract interface class ChoirFiles {
  Future<PickedFile?> pick();

  /// Opens the share sheet. False when the person dismissed it.
  Future<bool> share(String path, {Rect? origin});
  Future<bool> open(String path);
}

class PluginChoirFiles implements ChoirFiles {
  @override
  Future<PickedFile?> pick() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return null;
    final file = files.first;
    final path = file.path;
    return path == null ? null : PickedFile(path, file.name);
  }

  @override
  Future<bool> share(String path, {Rect? origin}) async {
    final result = await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], sharePositionOrigin: origin),
    );
    return result.status != ShareResultStatus.dismissed;
  }

  @override
  Future<bool> open(String path) async =>
      (await OpenFilex.open(path)).type == ResultType.done;
}

/// Choir services above the navigator. Absent in tests of unrelated screens;
/// use [maybeOf] from outside the module.
class ChoirScope extends InheritedNotifier<ChoirStore> {
  const ChoirScope({
    super.key,
    required ChoirStore store,
    required this.bundles,
    required this.files,
    required this.newPlayer,
    required this.newCapture,
    required this.workDirectory,
    required super.child,
  }) : super(notifier: store);

  final ChoirBundles bundles;
  final ChoirFiles files;
  final ChoirPlayer Function() newPlayer;
  final TakeCapture Function() newCapture;
  final Future<Directory> Function() workDirectory;

  ChoirStore get store => notifier!;

  factory ChoirScope.live({
    Key? key,
    required ChoirStore store,
    required Widget child,
  }) => ChoirScope(
    key: key,
    store: store,
    bundles: ChoirBundles(store, getTemporaryDirectory),
    files: PluginChoirFiles(),
    newPlayer: PluginChoirPlayer.new,
    newCapture: PluginTakeCapture.new,
    workDirectory: getTemporaryDirectory,
    child: child,
  );

  static ChoirScope of(BuildContext context) => maybeOf(context)!;

  static ChoirScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChoirScope>();

  static ChoirScope read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ChoirScope>()!;
}

// Small pieces shared by the choir screens.

/// A pushed choir screen: a back arrow with where you are, a large title,
/// the content, and one action held at the bottom.
class ChoirPage extends StatelessWidget {
  const ChoirPage({
    super.key,
    required this.title,
    required this.children,
    this.crumb = '',
    this.bottom,
    this.trailing,
    this.subtitle,
  });
  final String title;
  final String crumb;
  final List<Widget> children;
  final Widget? bottom;

  /// Sits beside the page's subtitle (a status tag).
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    return Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: TC.ink),
                  ),
                  Expanded(
                    child: Text(
                      text.caps(crumb),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TT.crumb,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                children: [
                  Semantics(header: true, child: Text(title, style: TT.h1)),
                  if (subtitle != null || trailing != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Expanded(child: Text(subtitle ?? '', style: TT.body)),
                          if (trailing != null) Flexible(child: trailing!),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  ...children,
                ],
              ),
            ),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

/// How long is left, in a lime tile.
class DueShape extends StatelessWidget {
  const DueShape({super.key, required this.now, required this.due});
  final DateTime now;
  final DateTime due;

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    final count = text.dueCount(now, due);
    return Semantics(
      label: text.dueLabel(now, due),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 66, minHeight: 66),
        padding: const EdgeInsets.all(8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: now.isAfter(due) ? TC.primarySoft : TC.sun,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count != null) ...[
              Text(
                count.$1,
                style: TT.h2.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                count.$2,
                style: const TextStyle(
                  color: TC.ink,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 62),
                child: Text(
                  text.dueLabel(now, due),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: TC.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bars drawn from real audio: a take's or a render's loudness, or the live
/// microphone level. Height means loudness only, never quality.
class ChoirWave extends StatelessWidget {
  const ChoirWave({
    super.key,
    required this.peaks,
    this.progress = 0,
    this.played = TC.sun,
    this.rest = const Color(0xFF594366),
    this.height = 84,
    this.onSeek,
  });

  /// Bars across a phone-width card in the design.
  static const barCount = 46;

  final List<double> peaks;
  final double progress;
  final Color played;
  final Color rest;
  final double height;
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    final seek = onSeek;
    final bars = ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (final (i, p) in peaks.indexed)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Center(
                    child: Container(
                      height: 10 + p * (height - 16),
                      decoration: BoxDecoration(
                        color: (i + 0.5) / peaks.length <= progress
                            ? played
                            : rest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (seek == null) return bars;
    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        key: const Key('choir_wave'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => seek(d.localPosition.dx / box.maxWidth),
        onHorizontalDragUpdate: (d) => seek(d.localPosition.dx / box.maxWidth),
        child: bars,
      ),
    );
  }
}

/// Lime round play control on the dark player.
class LimePlay extends StatelessWidget {
  const LimePlay({
    super.key,
    required this.playing,
    required this.label,
    required this.onTap,
    this.busy = false,
  });
  final bool playing;
  final bool busy;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: TC.sun,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                    color: TC.ink,
                    strokeWidth: 2.4,
                  ),
                )
              : Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_outlined,
                  color: TC.ink,
                ),
        ),
      ),
    ),
  );
}

class Caption extends StatelessWidget {
  const Caption(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
    child: Semantics(header: true, child: Text(text, style: TT.caps)),
  );
}

class ChoirRow extends StatelessWidget {
  const ChoirRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.color = Colors.white,
  });
  final Color color;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final plain = color == Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        onTap: onTap,
        color: color,
        radius: plain ? 12 : 20,
        child: Row(
          children: [
            if (plain)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: TC.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: TC.primary, size: 18),
              )
            else
              Icon(icon, color: TC.ink, size: 26),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TT.title),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TT.small.copyWith(
                        color: plain ? TC.muted : TC.ink,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                (onTap == null
                    ? const SizedBox.shrink()
                    : Icon(
                        plain
                            ? Icons.chevron_right_rounded
                            : Icons.north_east_rounded,
                        color: plain ? TC.muted : TC.ink,
                        size: plain ? 24 : 20,
                      )),
          ],
        ),
      ),
    );
  }
}

InputDecoration choirField(String label) => InputDecoration(
  hintText: label.isEmpty ? null : label,
  filled: true,
  fillColor: Colors.white,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: TC.line),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: TC.line),
  ),
);

void toast(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

String clockText(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Where a share sheet anchors on iPad.
Rect? shareOrigin(BuildContext context) {
  final box = context.findRenderObject();
  return box is RenderBox ? box.localToGlobal(Offset.zero) & box.size : null;
}

/// Part choice used by joining; an extra [none] label adds an empty choice.
class PartChips extends StatelessWidget {
  const PartChips({
    super.key,
    required this.selected,
    required this.onTap,
    this.parts = ChoirPart.values,
  });
  final Set<ChoirPart> selected;
  final ValueChanged<ChoirPart> onTap;
  final List<ChoirPart> parts;

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in parts)
          ChoiceChip(
            key: Key('part_chip_${p.name}'),
            label: Text(
              text.partName(p),
              style: TextStyle(
                color: selected.contains(p) ? Colors.white : TC.body,
                fontWeight: FontWeight.w700,
              ),
            ),
            selected: selected.contains(p),
            selectedColor: TC.primary,
            checkmarkColor: Colors.white,
            onSelected: (_) => onTap(p),
          ),
      ],
    );
  }
}
