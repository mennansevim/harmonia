import 'dart:convert';
import 'dart:typed_data';

/// Standard MIDI File (SMF) reader for choir part practice (MIDI-01).
///
/// Pure Dart, no IO. Reads format 0 and 1 files with a ticks-per-quarter
/// division: notes per track and channel, the tempo map, time signatures
/// and track names. Everything else (controllers, program changes, SysEx,
/// unknown chunks) is skipped safely. Untrusted input is bounded by
/// [SmfLimits]; any malformed or over-limit file throws
/// [MidiFormatException] instead of returning partial data.
///
/// This is a parser, not a renderer or a part detector: which track is
/// which choir part is the conductor's decision (MIDI-02).

class MidiFormatException extends FormatException {
  const MidiFormatException(super.message, [super.source, super.offset]);
}

class SmfLimits {
  const SmfLimits({
    this.maxBytes = 4 * 1024 * 1024,
    this.maxTracks = 64,
    this.maxEvents = 200000,
  });

  final int maxBytes;
  final int maxTracks;

  /// Across all tracks, every event counted (not only notes).
  final int maxEvents;
}

class MidiNote {
  const MidiNote({
    required this.channel,
    required this.key,
    required this.velocity,
    required this.startTick,
    required this.endTick,
  });

  /// 0–15.
  final int channel;

  /// MIDI note number 0–127.
  final int key;

  /// Note-on velocity 1–127.
  final int velocity;
  final int startTick;
  final int endTick;

  int get durationTicks => endTick - startTick;
}

class MidiTrack {
  MidiTrack({
    required this.index,
    required this.name,
    required List<MidiNote> notes,
    required this.endTick,
    required this.unterminatedNotes,
  }) : notes = List.unmodifiable(notes);

  final int index;

  /// Track name meta event, if present (often the part name).
  final String? name;

  /// Sorted by start tick, then key.
  final List<MidiNote> notes;
  final int endTick;

  /// Notes still sounding at end of track; closed at [endTick].
  final int unterminatedNotes;

  Set<int> get channels => {for (final n in notes) n.channel};

  /// Lowest and highest key, or null for a track without notes.
  (int, int)? get keyRange {
    if (notes.isEmpty) return null;
    var lo = 127, hi = 0;
    for (final n in notes) {
      if (n.key < lo) lo = n.key;
      if (n.key > hi) hi = n.key;
    }
    return (lo, hi);
  }
}

class TempoChange {
  const TempoChange(this.tick, this.microsPerQuarter);
  final int tick;
  final int microsPerQuarter;

  double get bpm => 60000000 / microsPerQuarter;
}

class TimeSignature {
  const TimeSignature(this.tick, this.numerator, this.denominator);
  final int tick;
  final int numerator;

  /// The actual note value (4 = quarter), not the SMF power of two.
  final int denominator;
}

class MidiFile {
  MidiFile({
    required this.format,
    required this.ticksPerQuarter,
    required List<MidiTrack> tracks,
    required List<TempoChange> tempos,
    required List<TimeSignature> timeSignatures,
  }) : tracks = List.unmodifiable(tracks),
       tempos = List.unmodifiable(tempos),
       timeSignatures = List.unmodifiable(timeSignatures);

  static const defaultMicrosPerQuarter = 500000; // 120 BPM

  final int format;
  final int ticksPerQuarter;
  final List<MidiTrack> tracks;

  /// Always starts at tick 0 (the SMF default 120 BPM when the file sets
  /// none); later changes at the same tick replace earlier ones.
  final List<TempoChange> tempos;

  /// Always starts at tick 0 (4/4 when the file sets none).
  final List<TimeSignature> timeSignatures;

  int get lengthTicks =>
      tracks.fold(0, (m, t) => t.endTick > m ? t.endTick : m);

  /// Wall-clock time of [tick] at the file's own tempo. A practice tempo
  /// factor is applied by the player, not here.
  double secondsAt(int tick) {
    var seconds = 0.0;
    for (var i = 0; i < tempos.length; i++) {
      final from = tempos[i].tick;
      if (tick <= from) break;
      final to = i + 1 < tempos.length && tempos[i + 1].tick < tick
          ? tempos[i + 1].tick
          : tick;
      seconds +=
          (to - from) * tempos[i].microsPerQuarter / 1e6 / ticksPerQuarter;
    }
    return seconds;
  }

  double get lengthSeconds => secondsAt(lengthTicks);

  /// Bound for [measureStarts] so a hostile file cannot make it unbounded.
  static const maxMeasures = 10000;

  /// Start tick of every measure up to [lengthTicks], following time
  /// signature changes. A change that lands mid-measure starts a new
  /// measure there, as notation software does. At most [maxMeasures].
  List<int> measureStarts() {
    final end = lengthTicks;
    if (end == 0) return const [0];
    final starts = <int>[];
    for (var i = 0; i < timeSignatures.length; i++) {
      final sig = timeSignatures[i];
      if (sig.tick >= end) break;
      final until = i + 1 < timeSignatures.length
          ? timeSignatures[i + 1].tick
          : end;
      final raw = ticksPerQuarter * 4 * sig.numerator ~/ sig.denominator;
      final bar = raw < 1 ? 1 : raw;
      for (var t = sig.tick; t < until && t < end; t += bar) {
        if (starts.length == maxMeasures) return starts;
        starts.add(t);
      }
    }
    return starts;
  }

  /// 1-based measure number containing [tick].
  int measureAt(int tick) {
    final starts = measureStarts();
    var n = 0;
    for (final s in starts) {
      if (s > tick) break;
      n++;
    }
    return n == 0 ? 1 : n;
  }
}

MidiFile readSmf(Uint8List bytes, {SmfLimits limits = const SmfLimits()}) =>
    _SmfReader(bytes, limits).read();

class _SmfReader {
  _SmfReader(this.bytes, this.limits);

  final Uint8List bytes;
  final SmfLimits limits;
  int _events = 0;

  Never _fail(String message, [int? offset]) =>
      throw MidiFormatException('MIDI: $message', null, offset);

  MidiFile read() {
    if (bytes.length > limits.maxBytes) _fail('file too large');
    if (bytes.length < 14 || _tag(0) != 'MThd') _fail('not a MIDI file', 0);
    final headerLength = _u32(4);
    if (headerLength < 6 || 8 + headerLength > bytes.length) {
      _fail('bad header length', 4);
    }
    final format = _u16(8);
    final declaredTracks = _u16(10);
    final division = _u16(12);
    if (format > 1) _fail('format $format is not supported', 8);
    if (division & 0x8000 != 0) _fail('SMPTE time division not supported', 12);
    if (division == 0) _fail('zero ticks per quarter', 12);
    if (declaredTracks == 0) _fail('no tracks', 10);
    if (declaredTracks > limits.maxTracks) _fail('too many tracks', 10);
    if (format == 0 && declaredTracks != 1) {
      _fail('format 0 must have exactly one track', 10);
    }

    final tracks = <MidiTrack>[];
    final tempos = <TempoChange>[];
    final signatures = <TimeSignature>[];
    var pos = 8 + headerLength;
    while (pos < bytes.length && tracks.length < declaredTracks) {
      if (pos + 8 > bytes.length) _fail('truncated chunk header', pos);
      final tag = _tag(pos);
      final length = _u32(pos + 4);
      final body = pos + 8;
      if (length > bytes.length - body) _fail('truncated $tag chunk', pos);
      if (tag == 'MTrk') {
        tracks.add(
          _track(tracks.length, body, body + length, tempos, signatures),
        );
      }
      // Unknown chunk types are skipped, as the SMF spec requires.
      pos = body + length;
    }
    if (tracks.length != declaredTracks) _fail('missing tracks');

    return MidiFile(
      format: format,
      ticksPerQuarter: division,
      tracks: tracks,
      tempos: _normalise(
        tempos,
        (t) => t.tick,
        const TempoChange(0, MidiFile.defaultMicrosPerQuarter),
      ),
      timeSignatures: _normalise(
        signatures,
        (s) => s.tick,
        const TimeSignature(0, 4, 4),
      ),
    );
  }

  /// Stable sort by tick, last change at a tick wins, a tick-0 entry exists.
  List<T> _normalise<T>(List<T> items, int Function(T) tick, T fallback) {
    final sorted = [...items];
    for (var i = 1; i < sorted.length; i++) {
      final item = sorted[i];
      var j = i - 1;
      while (j >= 0 && tick(sorted[j]) > tick(item)) {
        sorted[j + 1] = sorted[j];
        j--;
      }
      sorted[j + 1] = item;
    }
    final out = <T>[];
    for (final item in sorted) {
      if (out.isNotEmpty && tick(out.last) == tick(item)) {
        out[out.length - 1] = item;
      } else {
        out.add(item);
      }
    }
    if (out.isEmpty || tick(out.first) != 0) out.insert(0, fallback);
    return out;
  }

  MidiTrack _track(
    int index,
    int start,
    int end,
    List<TempoChange> tempos,
    List<TimeSignature> signatures,
  ) {
    var pos = start;
    var tick = 0;
    var running = -1;
    String? name;
    var ended = false;
    final notes = <MidiNote>[];
    // FIFO of open notes per channel*128+key: (startTick, velocity).
    final open = <int, List<(int, int)>>{};

    void close(int channel, int key, int at) {
      final queue = open[channel * 128 + key];
      if (queue == null || queue.isEmpty) return; // stray note-off
      final (startTick, velocity) = queue.removeAt(0);
      notes.add(
        MidiNote(
          channel: channel,
          key: key,
          velocity: velocity,
          startTick: startTick,
          endTick: at,
        ),
      );
    }

    int vlq() {
      var value = 0;
      for (var i = 0; i < 4; i++) {
        if (pos >= end) _fail('truncated variable-length value', pos);
        final b = bytes[pos++];
        value = (value << 7) | (b & 0x7F);
        if (b & 0x80 == 0) return value;
      }
      _fail('variable-length value longer than 4 bytes', pos);
    }

    int dataByte() {
      if (pos >= end) _fail('truncated event', pos);
      final b = bytes[pos++];
      if (b & 0x80 != 0) _fail('data byte expected', pos - 1);
      return b;
    }

    while (pos < end && !ended) {
      if (++_events > limits.maxEvents) _fail('too many events');
      tick += vlq();
      if (pos >= end) _fail('truncated event', pos);
      var status = bytes[pos];
      if (status & 0x80 != 0) {
        pos++;
      } else {
        if (running < 0) _fail('running status without a status byte', pos);
        status = running;
      }

      if (status == 0xFF) {
        running = -1;
        if (pos >= end) _fail('truncated meta event', pos);
        final type = bytes[pos++];
        final length = vlq();
        if (length > end - pos) _fail('truncated meta event', pos);
        final data = Uint8List.sublistView(bytes, pos, pos + length);
        pos += length;
        switch (type) {
          case 0x2F:
            ended = true;
          case 0x03:
            name = utf8.decode(data, allowMalformed: true).trim();
            if (name.isEmpty) name = null;
          case 0x51:
            if (length != 3) _fail('bad tempo event', pos);
            final micros = data[0] << 16 | data[1] << 8 | data[2];
            if (micros == 0) _fail('zero tempo', pos);
            tempos.add(TempoChange(tick, micros));
          case 0x58:
            if (length < 2) _fail('bad time signature', pos);
            if (data[0] == 0 || data[1] > 6) _fail('bad time signature', pos);
            signatures.add(TimeSignature(tick, data[0], 1 << data[1]));
        }
      } else if (status == 0xF0 || status == 0xF7) {
        running = -1;
        final length = vlq();
        if (length > end - pos) _fail('truncated SysEx', pos);
        pos += length;
      } else if (status >= 0xF1) {
        _fail('unexpected system message in file', pos - 1);
      } else {
        running = status;
        final channel = status & 0x0F;
        switch (status & 0xF0) {
          case 0x90:
            final key = dataByte();
            final velocity = dataByte();
            if (velocity == 0) {
              close(channel, key, tick);
            } else {
              (open[channel * 128 + key] ??= []).add((tick, velocity));
            }
          case 0x80:
            final key = dataByte();
            dataByte();
            close(channel, key, tick);
          case 0xC0 || 0xD0:
            dataByte();
          default: // 0xA0, 0xB0, 0xE0
            dataByte();
            dataByte();
        }
      }
    }
    if (!ended) _fail('track $index has no end-of-track event');

    var unterminated = 0;
    for (final entry in open.entries) {
      for (final (startTick, velocity) in entry.value) {
        unterminated++;
        notes.add(
          MidiNote(
            channel: entry.key ~/ 128,
            key: entry.key % 128,
            velocity: velocity,
            startTick: startTick,
            endTick: tick,
          ),
        );
      }
    }
    notes.sort(
      (a, b) => a.startTick != b.startTick
          ? a.startTick - b.startTick
          : a.key - b.key,
    );
    return MidiTrack(
      index: index,
      name: name,
      notes: notes,
      endTick: tick,
      unterminatedNotes: unterminated,
    );
  }

  String _tag(int at) => String.fromCharCodes(bytes, at, at + 4);
  int _u16(int at) => bytes[at] << 8 | bytes[at + 1];
  int _u32(int at) =>
      bytes[at] << 24 |
      bytes[at + 1] << 16 |
      bytes[at + 2] << 8 |
      bytes[at + 3];
}
