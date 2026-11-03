import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/music.dart';
import '../domain/trainers.dart';
import '../learn/session_end.dart';
import '../quiz/quiz.dart';
import '../quiz/quiz_view.dart';
import '../ui/kit.dart';
import '../../domain/lang.dart';

/// Free practice configuration for one trainer, remembered per trainer.
class PracticeSetupScreen extends StatefulWidget {
  const PracticeSetupScreen({super.key, required this.trainer});
  final TrainerKind trainer;
  @override
  State<PracticeSetupScreen> createState() => _PracticeSetupScreenState();
}

class _PracticeSetupScreenState extends State<PracticeSetupScreen> {
  late Set<String> _items;
  Register _register = Register.medium;
  int? _limit = 15;
  IntervalDirection _direction = IntervalDirection.ascending;
  bool _inversions = false;
  bool _reference = false;
  String _preset = 'custom';
  bool _loaded = false;

  TrainerKind get kind => widget.trainer;
  Color get color => trainerColor(kind);
  String get _prefKey => 'practice_${kind.id}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final saved = TrainerScope.of(context).store.answers[_prefKey];
    _items = switch (kind) {
      TrainerKind.pitch => {'0', '7'},
      TrainerKind.interval => {'P4', 'P5', 'P8'},
      TrainerKind.chord => {'maj', 'min'},
      TrainerKind.scale => {'major', 'natural_minor'},
      TrainerKind.progression => {'I-IV-V-I', 'I-V-vi-IV'},
    };
    if (saved is Map<String, Object?>) {
      final items = saved['items'];
      if (items is List) {
        final valid = items
            .whereType<String>()
            .where(kind.allItems.contains)
            .toSet();
        if (valid.length >= 2) _items = valid;
      }
      _register = Register.values.asNameMap()[saved['register']] ?? _register;
      final limit = saved['limit'];
      _limit = limit is int ? limit : (saved.containsKey('limit') ? null : 15);
      _direction =
          IntervalDirection.values.asNameMap()[saved['direction']] ??
          _direction;
      _inversions = saved['inversions'] == true;
      _reference = saved['reference'] == true;
    }
  }

  void _save() {
    final store = TrainerScope.of(context).store;
    store.answers[_prefKey] = {
      'items': _items.toList(),
      'register': _register.name,
      'limit': _limit,
      'direction': _direction.name,
      'inversions': _inversions,
      'reference': _reference,
    };
    store.save();
  }

  void _toggle(String id) => setState(() {
    _preset = 'custom';
    if (!_items.remove(id)) _items.add(id);
  });

  void _applyPreset(String preset) => setState(() {
    _preset = preset;
    _items = switch (preset) {
      'major' => {for (final p in PitchClass.whiteKeys) '$p'},
      'minor' => {for (final p in Scales.byId('natural_minor').steps) '$p'},
      'chromatic' => {for (var p = 0; p < 12; p++) '$p'},
      _ => _items,
    };
  });

  Future<void> _start() async {
    _save();
    final config = QuizConfig(
      trainer: kind,
      pool: kind.allItems.where(_items.contains).toList(),
      registers: [_register],
      direction: _direction,
      reference: _reference,
      inversions: _inversions,
      timeLimitSeconds: _limit,
      length: kind == TrainerKind.pitch ? 8 : 20,
    );
    final questions = QuizGenerator(config).session();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => QuizView(
          title: kind.title,
          questions: questions,
          timeLimitSeconds: _limit,
          onFinished: (summary) {
            TrainerScope.of(routeContext).store.recordSession();
            Navigator.of(routeContext).pushReplacement(
              MaterialPageRoute<void>(
                builder: (endContext) => SessionEnd(
                  summary: summary,
                  title: kind.title,
                  retryConfig: config,
                  onDone: () => Navigator.of(endContext).pop(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    String label(String id) => itemLabel(
      kind,
      id,
      notation: store.notation,
      transposition: store.transposition,
    );
    final columns = switch (kind) {
      TrainerKind.pitch || TrainerKind.interval => 4,
      TrainerKind.scale => 2,
      _ => 3,
    };
    return Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        child: Column(
          children: [
            CrumbBar(
              crumb: trCaps(
                tr('${kind.title} / Serbest', '${kind.title} / Free'),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                children: [
                  PageTitle(tr('Serbest çalışma', 'Free practice')),
                  const SizedBox(height: 10),
                  if (kind == TrainerKind.pitch) ...[
                    _Section(tr('DİZİ', 'SCALE')),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (id, name) in [
                            ('custom', tr('Özel', 'Custom')),
                            ('major', tr('Majör', 'Major')),
                            ('minor', tr('Doğal minör', 'Natural minor')),
                            ('chromatic', tr('Kromatik', 'Chromatic')),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _Chip(
                                label: name,
                                selected: _preset == id,
                                color: color,
                                onTap: () => _applyPreset(id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  _Section(switch (kind) {
                    TrainerKind.pitch => tr('NOTALAR (ÖZEL)', 'NOTES (CUSTOM)'),
                    TrainerKind.interval => tr('ARALIKLAR', 'INTERVALS'),
                    TrainerKind.chord => tr('AKORLAR', 'CHORDS'),
                    TrainerKind.scale => tr('DİZİLER', 'SCALES'),
                    TrainerKind.progression => tr('YÜRÜYÜŞLER', 'PROGRESSIONS'),
                  }),
                  LayoutBuilder(
                    builder: (context, c) {
                      final w = (c.maxWidth - 8 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final id in kind.allItems)
                            SizedBox(
                              width: w,
                              child: _Chip(
                                label: label(id),
                                selected: _items.contains(id),
                                color: color,
                                big: true,
                                onTap: () => _toggle(id),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (kind == TrainerKind.interval) ...[
                    _Section(tr('YÖN', 'DIRECTION')),
                    Segmented<IntervalDirection>(
                      joined: true,
                      color: color,
                      values: IntervalDirection.values,
                      selected: _direction,
                      label: (d) => switch (d) {
                        IntervalDirection.ascending => tr('Çıkan', 'Rising'),
                        IntervalDirection.descending => tr('İnen', 'Falling'),
                        IntervalDirection.mixed => tr('Karışık', 'Mixed'),
                      },
                      onChanged: (d) => setState(() => _direction = d),
                    ),
                    const SizedBox(height: 6),
                    Text(switch (_direction) {
                      IntervalDirection.ascending => tr(
                        'Önce pes nota, sonra tiz nota çalar.',
                        'Plays the low note, then the high note.',
                      ),
                      IntervalDirection.descending => tr(
                        'Önce tiz nota, sonra pes nota çalar.',
                        'Plays the high note, then the low note.',
                      ),
                      IntervalDirection.mixed => tr(
                        'Yön her soruda rastgele seçilir.',
                        'The direction is picked at random each question.',
                      ),
                    }, style: TT.small),
                  ],
                  if (kind == TrainerKind.progression) ...[
                    _Section(tr('AKOR DİZİLİŞİ', 'CHORD VOICING')),
                    Segmented<bool>(
                      joined: true,
                      color: color,
                      values: const [false, true],
                      selected: _inversions,
                      label: (v) => v
                          ? tr('Çevrimler', 'Inversions')
                          : tr('Kök konumu', 'Root position'),
                      onChanged: (v) => setState(() => _inversions = v),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _inversions
                          ? tr(
                              'Üst sesler birbirine yakın kalır; yolu basla takip et.',
                              'The upper notes stay close; follow the path with the bass.',
                            )
                          : tr(
                              'Her akor kökünü en altta tutar, bas yürüyüşü izler.',
                              'Each chord keeps its root at the bottom; follow the bass line.',
                            ),
                      style: TT.small,
                    ),
                  ],
                  _Section(tr('BÖLGE', 'REGISTER')),
                  Segmented<Register>(
                    color: color,
                    values: Register.values,
                    selected: _register,
                    label: (r) => r.label,
                    onChanged: (r) => setState(() => _register = r),
                  ),
                  _Section(tr('SORU BAŞINA SÜRE', 'TIME PER QUESTION')),
                  Segmented<int?>(
                    joined: true,
                    color: color,
                    values: const [null, 5, 15, 30],
                    selected: _limit,
                    label: (v) =>
                        v == null ? tr('Yok', 'Off') : tr('${v}sn', '${v}s'),
                    onChanged: (v) => setState(() => _limit = v),
                  ),
                  if (kind == TrainerKind.pitch) ...[
                    const SizedBox(height: 18),
                    AppCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              tr('REFERANS NOTA', 'REFERENCE NOTE'),
                              style: TT.caps,
                            ),
                          ),
                          _Chip(
                            label: _reference
                                ? tr(
                                    '${PitchClass.name(0, TrainerScope.of(context).store.notation)} (her soruda)',
                                    '${PitchClass.name(0, TrainerScope.of(context).store.notation)} (every question)',
                                  )
                                : tr('Yok', 'Off'),
                            selected: false,
                            color: color,
                            onTap: () =>
                                setState(() => _reference = !_reference),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: BigButton(
                key: const Key('practice_now'),
                label: tr('Başlat', 'Start'),
                icon: Ic.play,
                color: color,
                onPressed: _items.length >= 2 ? _start : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: Text(text, style: TT.caps),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.big = false,
  });
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final bool big;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: () {
        tapHaptic();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: big ? 44 : 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: selected ? color : Colors.white,
          shape: const StadiumBorder(),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: selected ? Colors.white : TC.body,
            ),
          ),
        ),
      ),
    ),
  );
}
