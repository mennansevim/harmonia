import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/music.dart';
import '../domain/trainers.dart';
import '../learn/path_screen.dart';
import '../learn/session_end.dart';
import '../quiz/quiz.dart';
import '../quiz/quiz_view.dart';
import '../ui/kit.dart';

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
            TopBar(
              title: kind.title,
              titleIcon: TrainerBadge(
                color: color,
                icon: trainerIcon(kind),
                size: 32,
              ),
              shadow: true,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (kind == TrainerKind.pitch) ...[
                    const _Section('DİZİ'),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (id, name) in const [
                            ('custom', 'Özel'),
                            ('major', 'Majör'),
                            ('minor', 'Doğal minör'),
                            ('chromatic', 'Kromatik'),
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
                    TrainerKind.pitch => 'NOTALAR (ÖZEL)',
                    TrainerKind.interval => 'ARALIKLAR',
                    TrainerKind.chord => 'AKORLAR',
                    TrainerKind.scale => 'DİZİLER',
                    TrainerKind.progression => 'YÜRÜYÜŞLER',
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
                    const _Section('YÖN'),
                    Segmented<IntervalDirection>(
                      joined: true,
                      color: color,
                      values: IntervalDirection.values,
                      selected: _direction,
                      label: (d) => switch (d) {
                        IntervalDirection.ascending => 'Çıkan',
                        IntervalDirection.descending => 'İnen',
                        IntervalDirection.mixed => 'Karışık',
                      },
                      onChanged: (d) => setState(() => _direction = d),
                    ),
                    const SizedBox(height: 6),
                    Text(switch (_direction) {
                      IntervalDirection.ascending =>
                        'Önce pes nota, sonra tiz nota çalar.',
                      IntervalDirection.descending =>
                        'Önce tiz nota, sonra pes nota çalar.',
                      IntervalDirection.mixed =>
                        'Yön her soruda rastgele seçilir.',
                    }, style: TT.small),
                  ],
                  if (kind == TrainerKind.progression) ...[
                    const _Section('AKOR DİZİLİŞİ'),
                    Segmented<bool>(
                      joined: true,
                      color: color,
                      values: const [false, true],
                      selected: _inversions,
                      label: (v) => v ? 'Çevrimler' : 'Kök konumu',
                      onChanged: (v) => setState(() => _inversions = v),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _inversions
                          ? 'Üst sesler birbirine yakın kalır; yolu basla takip et.'
                          : 'Her akor kökünü en altta tutar, bas yürüyüşü izler.',
                      style: TT.small,
                    ),
                  ],
                  const SizedBox(height: 18),
                  AppCard(
                    color: soft(color),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PathScreen(trainer: kind),
                      ),
                    ),
                    child: Row(
                      children: [
                        TrainerBadge(
                          color: color,
                          icon: Icons.menu_book_rounded,
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hatırlatma lazım mı?', style: TT.title),
                              Text(
                                'Önce her birinin nasıl duyulduğunu öğren',
                                style: TT.small,
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: color),
                      ],
                    ),
                  ),
                  const _Section('OKTAV (KÖK)'),
                  Segmented<Register>(
                    color: color,
                    values: Register.values,
                    selected: _register,
                    label: (r) => r.label,
                    onChanged: (r) => setState(() => _register = r),
                  ),
                  const _Section('SÜRE SINIRI'),
                  Segmented<int?>(
                    joined: true,
                    color: color,
                    values: const [null, 5, 15, 30],
                    selected: _limit,
                    label: (v) => v == null ? 'Yok' : '${v}sn',
                    onChanged: (v) => setState(() => _limit = v),
                  ),
                  if (kind == TrainerKind.pitch) ...[
                    const SizedBox(height: 18),
                    AppCard(
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text('REFERANS NOTA', style: TT.caps),
                          ),
                          _Chip(
                            label: _reference ? 'Do (her soruda)' : 'Yok',
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
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: BigButton(
                key: const Key('practice_now'),
                label: 'Pratiğe başla',
                icon: Icons.play_arrow_rounded,
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
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : TC.line, width: 1.5),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: selected ? Colors.white : TC.ink,
            ),
          ),
        ),
      ),
    ),
  );
}
