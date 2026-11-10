/// Invite codes: 8 characters from an alphabet without 0/O/1/I, as the server
/// makes them (`create_invite`). A QR carries [inviteLink]; people may also
/// type the code with a dash or in lower case.
const inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

final _code = RegExp('^[$inviteAlphabet]{8}\$');

/// What the QR holds. A custom scheme so a future deep link can open it.
String inviteLink(String code) => 'vocalart://join/$code';

/// "ABCD-2345" for reading aloud.
String formatInviteCode(String code) =>
    code.length == 8 ? '${code.substring(0, 4)}-${code.substring(4)}' : code;

/// A normalised code from typed text, a scanned link or null.
String? parseInviteCode(String raw) {
  var text = raw.trim();
  final link = RegExp(
    r'^(?:vocalart://join/|https?://[^/\s]+/j/)([A-Za-z0-9-]+)/?$',
  ).firstMatch(text);
  if (link != null) {
    text = link.group(1)!;
  } else if (text.contains('://')) {
    return null;
  }
  text = text.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  return _code.hasMatch(text) ? text : null;
}
