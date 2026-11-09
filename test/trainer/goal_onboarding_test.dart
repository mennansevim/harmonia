// WIDE-01/02: goal → minutes → first session, legacy save compatibility,
// permission-free first run and the post-first-session reminder.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/trainer/domain/music.dart';
import 'package:resonia/trainer/domain/trainers.dart';
import 'package:resonia/trainer/home/daily_route.dart';
import 'package:resonia/trainer/onboarding/onboarding_flow.dart';
import 'package:resonia/trainer/state/trainer_store.dart';
import 'package:resonia/trainer/ui/kit.dart';

import 'trainer_app_test.dart' show app, memoryStore, settle, tapKey;

/// Texts of the steps that moved out of onboarding.
const _movedOut = [
  'Mikrofonunu deneyelim',
  'Ses aralığını ölçelim',
  'Günlük hatırlatma ister misin?',
  'Vocalart\'ı nasıl kullanacaksın?',
  'Önce neye odaklanalım?',
];

void _expectNoMovedStep() {
  for (final t in _movedOut) {
    expect(find.text(t), findsNothing, reason: t);
  }
}

Future<TrainerStore> _onboard(
  WidgetTester tester,
  String goal, {
  bool toggleChoir = false,
  int minutes = 10,
  String level = 'beginner',
}) async {
  final store = memoryStore();
  await store.load();
  await tester.pumpWidget(app(store));
  await settle(tester);
  await tapKey(tester, 'get_started');
  await tapKey(tester, 'ob_continue'); // Name is optional.
  await tapKey(tester, 'goal_$goal');
  if (toggleChoir) await tapKey(tester, 'ob_choir');
  await tapKey(tester, 'ob_continue');
  await tapKey(tester, 'level_$level');
  await tapKey(tester, 'ob_continue');
  await tapKey(tester, 'minutes_$minutes');
  await tapKey(tester, 'ob_continue');
  return store;
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1170,
      2532,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 3;
  });

  group('DailyRoute.plan', () {
    test('no goal keeps the legacy minutes-only route exactly', () {
      for (final m in dailyMinuteChoices) {
        final legacy = DailyRoute.forMinutes(m);
        final planned = DailyRoute.plan(minutes: m);
        expect(planned.breathSeconds, legacy.breathSeconds, reason: '$m');
        expect(planned.voiceStep, legacy.voiceStep, reason: '$m');
        expect(planned.lesson, isTrue);
        expect(planned.goal, isNull);
      }
    });

    test('every goal routes to ready content only', () {
      for (final g in PracticeGoal.values) {
        for (final m in dailyMinuteChoices) {
          final r = DailyRoute.plan(goal: g, minutes: m);
          expect(r.goal, g);
          expect(r.stepCount, greaterThan(0), reason: '$g $m');
          // A lesson appears only when the goal has a ready one.
          expect(r.lesson, g.lesson != null, reason: '$g $m');
        }
      }
    });

    test('voice goals are never a silent interval-only route', () {
      for (final g in [PracticeGoal.voice, PracticeGoal.choir]) {
        for (final m in dailyMinuteChoices) {
          final r = DailyRoute.plan(goal: g, minutes: m);
          expect(r.breath, isTrue, reason: '$g $m');
          expect(r.voiceStep, m > 3, reason: '$g $m');
        }
      }
      expect(PracticeGoal.voice.lesson, TrainerKind.pitch);
    });

    test('speech/stage has no lesson and says its content is pending', () {
      final r = DailyRoute.plan(goal: PracticeGoal.stage, minutes: 3);
      expect(r.lesson, isFalse);
      expect(r.voiceStep, isFalse);
      expect(r.breath, isTrue);
      expect(r.stepCount, 1);
      expect(PracticeGoal.stage.lesson, isNull);
      expect(PracticeGoal.stage.pendingContent, isNotNull);
    });

    test('listening goals open no microphone step', () {
      for (final g in [
        PracticeGoal.beginner,
        PracticeGoal.ear,
        PracticeGoal.exam,
      ]) {
        for (final m in dailyMinuteChoices) {
          expect(DailyRoute.plan(goal: g, minutes: m).voiceStep, isFalse);
        }
      }
    });

    test('an unknown stored goal falls back to the legacy route', () {
      final r = routeFor({'goal': 'astronaut'}, 10);
      expect(r.goal, isNull);
      expect(r.lesson, isTrue);
    });
  });

  group('resumeStep maps saves from older builds', () {
    test('old steps land on the nearest new step', () {
      expect(resumeStep('role'), Ob.goal);
      expect(resumeStep('mic'), Ob.goal);
      expect(resumeStep('part'), Ob.goal);
      expect(resumeStep('focus'), Ob.goal);
      expect(resumeStep('notation'), Ob.minutes);
      expect(resumeStep('minutes'), Ob.minutes);
      expect(resumeStep('reminder'), Ob.ready);
      expect(resumeStep('ready'), Ob.ready);
      expect(resumeStep('goal'), Ob.goal);
      expect(resumeStep('garbage'), Ob.welcome);
    });
  });

  testWidgets('first run is goal → minutes → ready, no permission step', (
    tester,
  ) async {
    final store = memoryStore();
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    expect(find.text('Sesini ve kulağını\nher gün geliştir'), findsOneWidget);
    await tapKey(tester, 'get_started');
    await tapKey(tester, 'ob_continue'); // Name is optional.
    await tapKey(tester, 'ob_continue'); // Name is optional.
    expect(find.text('Ne için çalışıyorsun?'), findsOneWidget);
    expect(find.text('2/4'), findsOneWidget);
    // Continue stays disabled until a goal is picked.
    await tapKey(tester, 'ob_continue');
    expect(find.text('Ne için çalışıyorsun?'), findsOneWidget);
    _expectNoMovedStep();

    await tapKey(tester, 'goal_choir');
    // Rehearsal prep implies a choir; shown as a ticked, clearable box.
    expect(store.inChoir, isTrue);
    expect(
      tester.getSemantics(find.byKey(const Key('ob_choir'))),
      // ignore: deprecated_member_use
      containsSemantics(hasCheckedState: true, isChecked: true),
    );
    await tapKey(tester, 'ob_continue');
    expect(find.text('Müzikte neredesin?'), findsOneWidget);
    expect(find.text('3/4'), findsOneWidget);
    // Continue stays disabled until a level is picked.
    await tapKey(tester, 'ob_continue');
    expect(find.text('Müzikte neredesin?'), findsOneWidget);
    await tapKey(tester, 'level_beginner');
    await tapKey(tester, 'ob_continue');
    expect(find.text('Günde kaç dakika ayırabilirsin?'), findsOneWidget);
    expect(find.text('4/4'), findsOneWidget);
    _expectNoMovedStep();
    await tapKey(tester, 'minutes_10');
    await tapKey(tester, 'ob_continue');

    expect(find.text('Planın kuruldu'), findsOneWidget);
    expect(find.text('Koro provasına hazırlanmak'), findsOneWidget);
    expect(find.text('Aralık Eğitimi'), findsOneWidget);
    expect(
      find.text('Rotanın sonunda isteğe bağlı bir ses adımı'),
      findsOneWidget,
    );
    expect(find.text('Ödevlerin Koro sekmesinde'), findsOneWidget);
    expect(store.answers['obStep'], 'ready');
    _expectNoMovedStep();

    await tester.ensureVisible(find.text('Ana sayfaya git'));
    await tester.tap(find.text('Ana sayfaya git'));
    await settle(tester);
    expect(store.onboardingDone, isTrue);
    expect(store.setupDone, isTrue);
    expect(store.dailyMinutes, 10);
    expect(store.notation, NoteNotation.solfege);
    expect(store.answers['goal'], 'choir');
    expect(store.lastTrainer, TrainerKind.interval.id);
    expect(store.answers['focus'], [TrainerKind.interval.id]);
    // Reminder pending, but not offered before any practice.
    expect(store.answers['reminderAsked'], isFalse);
    expect(store.notifications, isFalse);
    expect(find.byKey(const Key('reminder_nudge')), findsNothing);
    // Nothing measured during onboarding.
    expect(store.koroRange, isNull);
    expect(store.part, isNull);
    expect(find.text('Koro'), findsOneWidget);
    expect(find.byKey(const Key('route_breath')), findsOneWidget);
    expect(find.byKey(const Key('route_lesson')), findsOneWidget);
    expect(find.byKey(const Key('route_voice')), findsOneWidget);
  });

  testWidgets('back from minutes keeps the picked goal', (tester) async {
    final store = memoryStore();
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    await tapKey(tester, 'get_started');
    await tapKey(tester, 'ob_continue'); // Name is optional.
    await tapKey(tester, 'ob_continue'); // Name is optional.
    await tapKey(tester, 'goal_ear');
    await tapKey(tester, 'ob_continue');
    await tester.tap(find.byTooltip('Geri').first);
    await settle(tester);
    expect(find.text('Ne için çalışıyorsun?'), findsOneWidget);
    expect(store.answers['goal'], 'ear');
    expect(
      tester.getSemantics(find.byKey(const Key('goal_ear'))),
      // ignore: deprecated_member_use
      containsSemantics(isSelected: true, isInMutuallyExclusiveGroup: true),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('goal_voice'))),
      // ignore: deprecated_member_use
      containsSemantics(isSelected: false),
    );
  });

  testWidgets('an ear goal without a choir has no Koro tab', (tester) async {
    final store = await _onboard(tester, 'ear', minutes: 5);
    expect(find.text('Aralık Eğitimi'), findsOneWidget);
    expect(
      find.text('Rotanın sonunda isteğe bağlı bir ses adımı'),
      findsNothing,
    );
    await tester.ensureVisible(find.text('Ana sayfaya git'));
    await tester.tap(find.text('Ana sayfaya git'));
    await settle(tester);
    expect(store.inChoir, isFalse);
    expect(find.text('Koro'), findsNothing);
    expect(find.byKey(const Key('route_voice')), findsNothing);
  });

  testWidgets('the choir box clears again after picking rehearsal prep', (
    tester,
  ) async {
    final store = await _onboard(tester, 'choir', toggleChoir: true);
    expect(store.answers['goal'], 'choir');
    expect(store.inChoir, isFalse);
    expect(store.roles, isEmpty);
    expect(find.text('Ödevlerin Koro sekmesinde'), findsNothing);
  });

  testWidgets('a beginner starts with note names, no microphone step', (
    tester,
  ) async {
    final store = await _onboard(tester, 'beginner', minutes: 3);
    expect(find.text('Nota Eğitimi'), findsOneWidget);
    await tester.ensureVisible(find.text('Ana sayfaya git'));
    await tester.tap(find.text('Ana sayfaya git'));
    await settle(tester);
    expect(store.lastTrainer, TrainerKind.pitch.id);
    expect(find.byKey(const Key('route_lesson')), findsOneWidget);
    expect(find.byKey(const Key('route_breath')), findsNothing);
    expect(find.byKey(const Key('route_voice')), findsNothing);
  });

  testWidgets('speech/stage gets no silent interval lesson', (tester) async {
    final store = await _onboard(tester, 'stage', minutes: 5);
    expect(find.text('Konuşma ve sahne hazırlığı'), findsOneWidget);
    expect(find.byKey(const Key('ob_pending')), findsOneWidget);
    expect(find.text('Aralık Eğitimi'), findsNothing);
    await tester.ensureVisible(find.text('Ana sayfaya git'));
    await tester.tap(find.text('Ana sayfaya git'));
    await settle(tester);
    expect(store.lastTrainer, isNull);
    expect(store.answers['focus'], isNull);
    expect(find.byKey(const Key('route_lesson')), findsNothing);
    expect(find.byKey(const Key('route_breath')), findsOneWidget);
    expect(find.byKey(const Key('route_pending')), findsOneWidget);
    expect(find.text('Hazırlığa başla'), findsOneWidget);

    // The guide's exits say "finish", not "go to the lesson".
    await tapKey(tester, 'today_begin');
    expect(find.text('Şimdilik bitir'), findsOneWidget);
    expect(find.text('Nefesi atla, derse geç'), findsNothing);
    await tapKey(tester, 'breath_skip');
    // Skipping is not finishing: the step stays open, no evidence written.
    expect(store.breathedToday, isFalse);
    expect(store.sessionToday, isFalse);
    expect(store.xp, 0);
    expect(find.text('Hazırlığa başla'), findsOneWidget);
  });

  testWidgets('the first session starts with the breath guide, no mic', (
    tester,
  ) async {
    await _onboard(tester, 'voice');
    await tapKey(tester, 'today_session_begin');
    expect(find.byKey(const Key('breath_skip')), findsOneWidget);
    expect(find.text('Nefesi atla, derse geç'), findsOneWidget);
    expect(find.text('Mikrofon kapalı'), findsOneWidget);
    expect(find.text('Sesin net geliyor mu?'), findsNothing);
  });

  testWidgets('a legacy finished save keeps its route and is not nagged', (
    tester,
  ) async {
    final store = memoryStore({
      'onboardingDone': true,
      'setupDone': true,
      'dailyMinutes': 10,
      'answers': {
        'role': 'singer',
        'focus': ['voice', 'chord'],
      },
      'lastTrainer': 'chord',
      'xp': 120,
      'breathDay': '2026-10-29',
      'days': {
        '2026-10-28': {'q': 4, 'c': 3, 's': 1},
      },
    });
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    expect(store.answers['goal'], isNull);
    expect(store.roles, {'singer'});
    expect(store.xp, 120);
    expect(find.byKey(const Key('get_started')), findsNothing);
    expect(find.byKey(const Key('route_breath')), findsOneWidget);
    expect(find.byKey(const Key('route_lesson')), findsOneWidget);
    expect(find.byKey(const Key('route_voice')), findsOneWidget);
    expect(find.byKey(const Key('route_pending')), findsNothing);
    // Active before, but they answered the old reminder step.
    expect(find.byKey(const Key('reminder_nudge')), findsNothing);
    expect(find.text('Koro'), findsOneWidget);
  });

  testWidgets('a run saved on the old focus step resumes at the goal and '
      'keeps its answers', (tester) async {
    final store = memoryStore({
      'dailyMinutes': 15,
      'koroRange': '48-67',
      'answers': {
        'obStep': 'focus',
        'role': ['conductor'],
        'focus': ['scale'],
      },
    });
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    expect(find.text('Ne için çalışıyorsun?'), findsOneWidget);
    expect(store.inChoir, isTrue);
    expect(store.koroRange, '48-67');
    await tapKey(tester, 'goal_exam');
    // Already in a choir: the conductor role is kept as it was.
    expect(store.roles, {'conductor'});
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'level_beginner');
    await tapKey(tester, 'ob_continue');
    expect(store.dailyMinutes, 15);
    await tapKey(tester, 'ob_continue');
    await tester.ensureVisible(find.text('Ana sayfaya git'));
    await tester.tap(find.text('Ana sayfaya git'));
    await settle(tester);
    expect(store.answers['focus'], ['scale']);
    expect(store.lastTrainer, TrainerKind.interval.id);
  });

  testWidgets('a run saved on the old notation step resumes at minutes', (
    tester,
  ) async {
    final store = memoryStore({
      'answers': {'obStep': 'notation'},
    });
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    expect(find.text('Günde kaç dakika ayırabilirsin?'), findsOneWidget);
    expect(find.text('4/4'), findsOneWidget);
  });

  testWidgets('a run saved on the old reminder step resumes at ready and '
      'finishes on the legacy focus', (tester) async {
    final store = memoryStore({
      'answers': {
        'obStep': 'reminder',
        'focus': ['chord'],
      },
    });
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    expect(find.text('Planın kuruldu'), findsOneWidget);
    expect(find.text('Akor Tanıma'), findsOneWidget);
    await tester.ensureVisible(find.text('Ana sayfaya git'));
    await tester.tap(find.text('Ana sayfaya git'));
    await settle(tester);
    expect(store.lastTrainer, TrainerKind.chord.id);
  });

  testWidgets('the reminder is offered once, after the first practice', (
    tester,
  ) async {
    final store = memoryStore({
      'onboardingDone': true,
      'setupDone': true,
      'dailyMinutes': 10,
      'answers': {'goal': 'voice', 'reminderAsked': false},
    });
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    expect(find.byKey(const Key('reminder_nudge')), findsNothing);

    store.markBreathDone();
    await settle(tester);
    final nudge = find.byKey(const Key('reminder_nudge'));
    await tester.scrollUntilVisible(
      nudge,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(nudge, findsOneWidget);
    // A secondary card: the route keeps the one primary action.
    expect(
      find.descendant(of: nudge, matching: find.byType(BigButton)),
      findsNothing,
    );
    await tapKey(tester, 'reminder_skip');
    expect(find.byKey(const Key('reminder_nudge')), findsNothing);
    expect(store.answers['reminderAsked'], isTrue);
    expect(store.notifications, isFalse);
  });

  testWidgets('settings changes the goal and minutes; the route follows', (
    tester,
  ) async {
    final store = memoryStore({
      'onboardingDone': true,
      'setupDone': true,
      'dailyMinutes': 10,
      'answers': {'goal': 'ear'},
    });
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    expect(find.byKey(const Key('route_voice')), findsNothing);
    await tapKey(tester, 'open_settings');
    expect(find.text('Kulağımı geliştirmek'), findsOneWidget);
    await tapKey(tester, 'settings_goal');
    await tester.tap(find.text('Konuşma ve sahne hazırlığı').last);
    await settle(tester);
    expect(store.answers['goal'], 'stage');
    await tapKey(tester, 'settings_minutes');
    await tester.tap(find.text('3 dk').last);
    await settle(tester);
    expect(store.dailyMinutes, 3);
    final route = routeFor(store.answers, store.dailyMinutes);
    expect(route.lesson, isFalse);
    expect(route.breathSeconds, 60);
  });
}
