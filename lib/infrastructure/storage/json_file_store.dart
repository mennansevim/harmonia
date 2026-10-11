import 'dart:convert';
import 'dart:io';

/// Single JSON document in an app-private directory. Writes go to a sibling
/// temp file and are renamed into place, so a crash leaves either the old or
/// the new document. Reads are size-bounded; invalid JSON is a
/// FormatException for the caller to surface, never silently discarded.
class JsonFileStore {
  JsonFileStore(this._directory, this.name, {this.maxBytes = 1 << 20}) {
    if (!RegExp(r'^[a-z0-9_-]{1,40}$').hasMatch(name)) {
      throw ArgumentError('Invalid store name');
    }
  }

  final Future<Directory> Function() _directory;
  final String name;
  final int maxBytes;

  Future<File> _file(String suffix) async =>
      File('${(await _directory()).path}/$name$suffix');

  Future<Map<String, Object?>?> read() async {
    final file = await _file('.json');
    if (!await file.exists()) return null;
    if (await file.length() > maxBytes) {
      throw const FormatException('Stored document exceeds budget');
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Stored document is not an object');
    }
    return decoded;
  }

  Future<void> write(Map<String, Object?> document) async {
    final bytes = utf8.encode(jsonEncode(document));
    if (bytes.length > maxBytes) {
      throw const FormatException('Document exceeds budget');
    }
    final temp = await _file('.json.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename((await _file('.json')).path);
  }

  Future<void> delete() async {
    for (final suffix in ['.json', '.json.tmp']) {
      final file = await _file(suffix);
      if (await file.exists()) await file.delete();
    }
  }
}
