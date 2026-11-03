/// Trainer wording language: Turkish on Turkish devices, English everywhere
/// else, like the choir module's `CT`. The app sets it from the resolved
/// locale; lesson data reads it too, so domain wording needs no BuildContext.
abstract final class Lang {
  static bool en = false;
}

/// Picks the wording for the current [Lang].
String tr(String turkish, String english) => Lang.en ? english : turkish;

/// A 0–1 ratio as a whole percentage: Turkish writes the sign first.
String percent(double ratio) {
  final n = (ratio * 100).round();
  return tr('%$n', '$n%');
}
