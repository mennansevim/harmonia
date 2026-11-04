import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// [textContrastGuideline], minus text a scroll viewport cuts off.
///
/// The stock guideline samples a text's whole paint box even when a
/// viewport clips part of it, so a line half hidden under the tab bar is
/// measured against the bar and the canvas instead of its own glyphs.
/// Semantics trims a cut node's rect to the clip, so a text whose paint box
/// reaches past its node (on any side, e.g. a horizontal row running off
/// screen) was cut; only those failures are dropped. Fully
/// visible text is held to the same 4.5:1 / 3:1 rule.
class VisibleTextContrastGuideline extends AccessibilityGuideline {
  const VisibleTextContrastGuideline();

  @override
  String get description => 'Text contrast for fully visible text';

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) async {
    final result = await textContrastGuideline.evaluate(tester);
    if (result.passed) return result;
    final nodes = <int, SemanticsNode>{};
    void visit(SemanticsNode node) {
      nodes[node.id] = node;
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    for (final view in tester.binding.renderViews) {
      final root = view.owner?.semanticsOwner?.rootSemanticsNode;
      if (root != null) visit(root);
    }
    final kept = result.reason!.split(RegExp(r'(?=SemanticsNode#\d+)')).where((
      chunk,
    ) {
      final id = RegExp(r'^SemanticsNode#(\d+)').firstMatch(chunk);
      if (id == null) return false;
      final node = nodes[int.parse(id.group(1)!)];
      return node == null || !_cut(node);
    }).toList();
    return kept.isEmpty
        ? const Evaluation.pass()
        : Evaluation.fail(kept.join());
  }

  /// Whether the node's text paints beyond the node, i.e. a clip cut it.
  static bool _cut(SemanticsNode node) {
    var bounds = node.rect;
    for (SemanticsNode? n = node; n != null; n = n.parent) {
      final t = n.transform;
      if (t != null) bounds = MatrixUtils.transformRect(t, bounds);
    }
    final data = node.getSemanticsData();
    final text = data.label.isEmpty ? data.value : data.label;
    final view = _viewOf(node);
    for (final element in find.text(text).hitTestable().evaluate()) {
      final box = element.renderObject;
      if (box is! RenderBox) continue;
      final root = Matrix4.identity();
      view.applyPaintTransform(view.child!, root);
      root.multiply(box.getTransformTo(null));
      final paint = MatrixUtils.transformRect(root, box.paintBounds);
      if (!paint.overlaps(bounds)) continue;
      if (paint.top < bounds.top - 1 ||
          paint.bottom > bounds.bottom + 1 ||
          paint.left < bounds.left - 1 ||
          paint.right > bounds.right + 1) {
        return true;
      }
    }
    return false;
  }

  static RenderView _viewOf(SemanticsNode node) =>
      RendererBinding.instance.renderViews.firstWhere(
        (v) => v.owner?.semanticsOwner?.rootSemanticsNode == _root(node),
      );

  static SemanticsNode _root(SemanticsNode node) {
    var n = node;
    while (n.parent != null) {
      n = n.parent!;
    }
    return n;
  }
}
