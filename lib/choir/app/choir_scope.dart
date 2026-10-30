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

class ChoirPage extends StatelessWidget {
  const ChoirPage({
    super.key,
    required this.title,
    required this.children,
    this.bottom,
    this.trailing,
  });
  final String title;
  final List<Widget> children;
  final Widget? bottom;

  /// Sits beside the big page title (the due shape).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: TC.canvas,
    body: SafeArea(
      child: Column(
        children: [
          const TopBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 0, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(title, style: TT.h1),
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 12),
                        trailing!,
                      ],
                    ],
                  ),
                ),
                ...children,
              ],
            ),
          ),
          if (bottom != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: bottom,
            ),
        ],
      ),
    ),
  );
}

/// The app's signature: a lime, slightly tilted organic shape saying how long
/// is left.
class DueShape extends StatelessWidget {
  const DueShape({super.key, required this.now, required this.due});
  final DateTime now;
  final DateTime due;

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    final count = text.dueCount(now, due);
    final late = now.isAfter(due);
    return Semantics(
      label: text.dueLabel(now, due),
      excludeSemantics: true,
      child: Transform.rotate(
        angle: -0.1,
        child: Container(
          constraints: const BoxConstraints(minWidth: 92, minHeight: 92),
          padding: const EdgeInsets.all(10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: late ? TC.primarySoft : TC.sun,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(34),
              topRight: Radius.circular(58),
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(60),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count != null) ...[
                Text(count.$1, style: TT.h1.copyWith(fontSize: 34)),
                Text(
                  count.$2,
                  style: const TextStyle(
                    color: TC.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 76),
                  child: Text(
                    text.dueLabel(now, due),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: TC.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class Caption extends StatelessWidget {
  const Caption(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 18, 0, 8),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      color: color,
      border: color == Colors.white ? null : color,
      child: Row(
        children: [
          TrainerBadge(color: TC.koro, icon: icon, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TT.title),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TT.small),
                ],
              ],
            ),
          ),
          trailing ??
              (onTap == null
                  ? const SizedBox.shrink()
                  : const Icon(Icons.chevron_right_rounded, color: TC.faint)),
        ],
      ),
    ),
  );
}

InputDecoration choirField(String label) => InputDecoration(
  labelText: label,
  filled: true,
  fillColor: Colors.white,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: TC.line),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
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
            label: Text(text.partName(p)),
            selected: selected.contains(p),
            onSelected: (_) => onTap(p),
          ),
      ],
    );
  }
}
