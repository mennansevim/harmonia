import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/lang.dart';
import 'package:resonia/trainer/domain/curriculum.dart';
import 'package:resonia/trainer/domain/music.dart';
import 'package:resonia/trainer/domain/trainers.dart';
import 'package:resonia/trainer/koro/range_test.dart';
import 'package:resonia/trainer/koro/voice_count.dart';
import 'package:resonia/trainer/learn/lesson_flow.dart';
import 'package:resonia/trainer/learn/skill_screen.dart';
import 'package:resonia/trainer/practice/practice_setup.dart';
import 'package:resonia/trainer/prepare/breath_screen.dart';
import 'package:resonia/trainer/settings/membership_screen.dart';
import 'package:resonia/trainer/stats/stats_tab.dart';
import 'package:resonia/trainer/ui/kit.dart';

import 'trainer_app_test.dart' show app, memoryStore, settle, tapKey;

/// Letters only Turkish uses, and Turkish words written without them.
final _turkishLetters = RegExp('[çğıöşüÇĞİÖŞÜ]');
final _turkishWords = RegExp(
  r'\b(ve|ile|bir|için|Devam|Tamam|Bitti|Geri|Sil|ders|dakika|soru|Dinle|'
  r'Ses|Koro|Ayarlar|Pratik|Nefes|Ezgi|Ritim|Akor|Dizi|Tekrar|Yok|Pes|Orta|'
  r'Tiz|Bas|Harf|Solfej|Seri|Seviye|Yakında|Hazır)\b',
);

/// Every string a sighted or screen-reader user meets on the current screen.
List<String> visibleWording(WidgetTester tester) => [
  for (final t in tester.widgetList<RichText>(find.byType(RichText)))
    t.text.toPlainText(),
  for (final t in tester.widgetList<Tooltip>(find.byType(Tooltip))) ?t.message,
  for (final s in tester.widgetList<Semantics>(find.byType(Semantics)))
    ?s.properties.label,
];

/// Scrolls each list on screen to its end so lazily built rows are checked.
Future<List<String>> wordingWithScroll(WidgetTester tester) async {
  final seen = <String>{...visibleWording(tester)};
  final lists = find.byType(Scrollable);
  for (var i = 0; i < lists.evaluate().length; i++) {
    for (var step = 0; step < 12; step++) {
      final list = lists.at(i);
      if (list.evaluate().isEmpty) break;
      final state = tester.state<ScrollableState>(list);
      final position = state.position;
      if (position.axis != Axis.vertical ||
          position.pixels >= position.maxScrollExtent) {
        break;
      }
      position.jumpTo(
        (position.pixels + position.viewportDimension * 0.8).clamp(
          0,
          position.maxScrollExtent,
        ),
      );
      await tester.pump();
      seen.addAll(visibleWording(tester));
    }
  }
  return seen.toList();
}

void expectEnglish(Iterable<String> wording, String where) {
  final turkish = [
    for (final w in wording)
      if (_turkishLetters.hasMatch(w) || _turkishWords.hasMatch(w)) w,
  ];
  expect(turkish, isEmpty, reason: 'Turkish wording on $where');
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1170,
      2532,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 3;
    binding.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
  });

  testWidgets('an English device sees the whole trainer in English', (
    tester,
  ) async {
    final store = memoryStore();
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    expect(Lang.en, isTrue);

    expectEnglish(visibleWording(tester), 'welcome');
    await tapKey(tester, 'get_started');
    expectEnglish(visibleWording(tester), 'role');
    await tapKey(tester, 'opt_singer');
    await tapKey(tester, 'ob_continue');
    expectEnglish(visibleWording(tester), 'range');
    await tapKey(tester, 'ob_continue');
    expectEnglish(visibleWording(tester), 'focus');
    await tapKey(tester, 'opt_voice');
    await tapKey(tester, 'opt_interval');
    await tapKey(tester, 'ob_continue');
    expectEnglish(visibleWording(tester), 'minutes');
    await tapKey(tester, 'minutes_10');
    await tapKey(tester, 'ob_continue');
    expectEnglish(visibleWording(tester), 'reminder');
    await tapKey(tester, 'reminder_skip');
    expectEnglish(visibleWording(tester), 'ready');
    expect(find.text('Your plan is ready'), findsOneWidget);
    await tester.tap(find.text('Go to home'));
    await settle(tester);

    // English defaults to letter names; solfège has the longest Settings
    // value, which once overflowed.
    expect(store.notation, NoteNotation.letter);
    store.notation = NoteNotation.solfege;
    expectEnglish(await wordingWithScroll(tester), 'Today');
    expect(find.text('Today'), findsWidgets);
    for (final tab in ['tab_1', 'tab_koro', 'tab_2']) {
      await tapKey(tester, tab);
      expectEnglish(await wordingWithScroll(tester), tab);
    }
    expect(find.text('Choir'), findsWidgets);
    // Settings sits behind the profile button at the top of the tab.
    tester
        .state<ScrollableState>(find.byType(Scrollable).last)
        .position
        .jumpTo(0);
    await tester.pump();
    await tapKey(tester, 'open_settings');
    expectEnglish(await wordingWithScroll(tester), 'settings');

    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    Future<void> visit(String where, Widget screen) async {
      nav.push(MaterialPageRoute<void>(builder: (_) => screen));
      await settle(tester);
      expectEnglish(await wordingWithScroll(tester), where);
      nav.pop();
      await settle(tester);
    }

    for (final kind in TrainerKind.values) {
      await visit('${kind.id} skill', SkillScreen(trainer: kind));
      await visit('${kind.id} practice', PracticeSetupScreen(trainer: kind));
      await visit('${kind.id} stats', TrainerStatsScreen(trainer: kind));
      for (final node in trainerPaths[kind]!.nodes.take(3)) {
        await visit('${node.id} lesson', LessonFlow(node: node));
      }
      final last = trainerPaths[kind]!.nodes.last;
      await visit('${last.id} lesson', LessonFlow(node: last));
    }
    await visit('breath', const BreathScreen(totalSeconds: 60));
    await visit('membership', const MembershipScreen());
    await visit('range test', const RangeTestScreen());
    await visit('voice count', const VoiceCountScreen());

    // A lesson walked past its overview: listen, then sing.
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            LessonFlow(node: trainerPaths[TrainerKind.interval]!.nodes[1]),
      ),
    );
    await settle(tester);
    for (var page = 0; page < 4; page++) {
      final next = find.byType(BigButton).last;
      await tester.ensureVisible(next);
      await tester.tap(next);
      await settle(tester);
      expectEnglish(await wordingWithScroll(tester), 'lesson page $page');
    }
    nav.pop();
    await settle(tester, 1500);
  });

  testWidgets('a Turkish device keeps the trainer in Turkish', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('tr', 'TR')];
    final store = memoryStore();
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    expect(Lang.en, isFalse);
    expect(find.text('Başlayalım'), findsOneWidget);
  });

  test('wording follows the language, numbers and capitals included', () {
    Lang.en = true;
    expect(percent(0.8), '80%');
    expect(trCaps('skills'), 'SKILLS');
    expect(TrainerKind.interval.title, 'Interval Training');
    expect(
      trainerPaths[TrainerKind.pitch]!.nodes.first.title,
      'Getting started',
    );
    Lang.en = false;
    expect(percent(0.8), '%80');
    expect(trCaps('beceriler'), 'BECERİLER');
    expect(trainerPaths[TrainerKind.pitch]!.nodes.first.title, 'Başlarken');
  });
}
