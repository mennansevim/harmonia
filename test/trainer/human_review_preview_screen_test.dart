import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/lang.dart';
import 'package:resonia/trainer/settings/human_review_preview_screen.dart';
import 'package:resonia/trainer/settings/membership_screen.dart';
import 'package:resonia/trainer/ui/kit.dart';

void main() {
  setUp(() => Lang.en = false);

  Future<void> openPreview(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: trainerTheme(), home: const MembershipScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plus'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('membership_cta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('membership_cta')));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Key key) async {
    await tester.scrollUntilVisible(
      find.byKey(key),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Plus preview is human-written and has no submission path', (
    tester,
  ) async {
    await openPreview(tester);

    expect(find.text('Başvurunu hazırla'), findsOneWidget);
    expect(find.textContaining('gerçek bir eğitimci'), findsOneWidget);
    expect(find.textContaining('Yapay zekâ'), findsOneWidget);
    await reveal(tester, const Key('human_review_recording_disabled'));

    final recording = tester.widget<OutlinedButton>(
      find.byKey(const Key('human_review_recording_disabled')),
    );
    expect(recording.onPressed, isNull);

    await reveal(tester, const Key('human_review_submit'));
    final submit = tester.widget<BigButton>(
      find.byKey(const Key('human_review_submit')),
    );
    expect(submit.onPressed, isNull);
    expect(find.textContaining('hak tüketilmez'), findsOneWidget);
  });

  testWidgets('local choices never unlock the closed service', (tester) async {
    await openPreview(tester);

    await tester.tap(find.byKey(const Key('human_review_goal_voice')));
    await tester.enterText(
      find.byKey(const Key('human_review_question')),
      'İkinci cümlede girişimi nasıl daha kararlı tutabilirim?',
    );
    await reveal(tester, const Key('human_review_progress_thirtyDays'));
    await tester.tap(find.byKey(const Key('human_review_progress_thirtyDays')));
    await tester.pump();

    await reveal(tester, const Key('human_review_submit'));
    final submit = tester.widget<BigButton>(
      find.byKey(const Key('human_review_submit')),
    );
    expect(submit.onPressed, isNull);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('human_review_consent_disabled')),
          )
          .onChanged,
      isNull,
    );
  });

  testWidgets('preview remains usable on a narrow large-text phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: trainerTheme(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: const HumanReviewPreviewScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Başvurunu hazırla'), findsOneWidget);
    await reveal(tester, const Key('human_review_submit'));
    expect(find.byKey(const Key('human_review_submit')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
