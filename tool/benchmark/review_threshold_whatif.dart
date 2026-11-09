// What-if: same HLR-lite rules, only the "spaced" growth threshold changes.
// Standalone (no package imports): `dart tool/benchmark/review_threshold_whatif.dart`.
import 'dart:io';
import 'dart:math' as math;

class M {
  M(this.h, this.last);
  double h;
  DateTime last;
  double days(DateTime now) =>
      math.max(0, now.difference(last).inMinutes) / 1440;
  double recall(DateTime now) => math.pow(2, -days(now) / h).toDouble();
  bool due(DateTime now) => recall(now) < 0.85;
  void answer(bool ok, DateTime now, double growAfter) {
    if (!ok) {
      h = math.max(0.5, h / 2);
    } else if (days(now) >= h * growAfter) {
      h = math.min(60, h * 2);
    }
    last = now;
  }
}

void main() {
  final t0 = DateTime(2026, 11, 1, 8);
  final due = math.log(1 / 0.85) / math.ln2;
  stdout.writeln(
    'growth threshold (fraction of half-life) | check-in | reviews/90d | final h | review days',
  );
  for (final g in [0.5, due, 0.15]) {
    for (final every in [1, 2, 3, 7]) {
      final m = M(1, t0);
      var n = 0;
      final days = <int>[];
      for (var d = every; d <= 90; d += every) {
        final now = t0.add(Duration(days: d));
        if (m.due(now)) {
          m.answer(true, now, g);
          n++;
          days.add(d);
        }
      }
      stdout.writeln(
        '${g.toStringAsFixed(3)}${g == 0.5 ? " (shipped)" : ""} | every ${every}d | $n | ${m.h.toStringAsFixed(0)} | ${days.take(12).join(",")}${days.length > 12 ? "…" : ""}',
      );
    }
  }
}
