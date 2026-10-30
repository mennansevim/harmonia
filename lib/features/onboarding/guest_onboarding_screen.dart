import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../application/practice_preferences.dart';
import '../../domain/learning/daily_plan.dart';
import '../../domain/models/learner_profile.dart';
import '../common/ui/resonia_ui.dart';
import 'goal_selection_screen.dart';

/// Local goal → budget choice. The two stores are not one transaction:
/// successful budget writes survive a profile failure; skip preserves them.
class GuestOnboardingScreen extends StatefulWidget {
  const GuestOnboardingScreen({
    super.key,
    required this.preferences,
    required this.onComplete,
  });
  final PracticePreferencesRepository preferences;
  final Future<bool> Function(PracticeGoal goal) onComplete;
  @override
  State<GuestOnboardingScreen> createState() => _GuestOnboardingScreenState();
}

class _GuestOnboardingScreenState extends State<GuestOnboardingScreen> {
  PracticeGoal? _goal;
  DailyBudget _budget = DailyBudget.twelve;
  DailyBudget? _savedBudget;
  bool _busy = false;
  String? _error;

  void _back() {
    if (_busy) return;
    setState(() {
      _goal = null;
      _error = null;
    });
  }

  Future<void> _complete({required bool saveBudget}) async {
    if (_busy || _goal == null) return;
    final goal = _goal!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (saveBudget && _savedBudget != _budget) {
        try {
          await widget.preferences.saveDailyBudget(_budget);
          _savedBudget = _budget;
        } catch (_) {
          if (mounted) {
            setState(
              () => _error =
                  'Süre kaydedilemedi. Yeniden deneyebilir veya süreyi değiştirmeden devam edebilirsin.',
            );
          }
          return;
        }
      }
      if (!mounted) return;
      final saved = await widget.onComplete(goal);
      if (!saved && mounted) {
        setState(
          () => _error = _savedBudget == null
              ? 'Hedef kaydedilemedi. Yeniden dene.'
              : 'Süre tercihin kaydedildi; hedef kaydedilemedi. Yeniden dene.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Hedef kaydedilemedi. Yeniden dene.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_goal == null) {
      return GoalSelectionScreen(
        onSelected: (goal) => setState(() {
          _goal = goal;
          _error = null;
        }),
      );
    }
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const Key('onboarding_back'),
            tooltip: 'Hedef seçimine dön',
            icon: const Icon(Icons.arrow_back),
            onPressed: _busy ? null : _back,
          ),
          title: const Text('Günlük süre'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(ResoniaSpacing.lg),
            children: [
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: StatusPill('Yerel tercih'),
              ),
              const SizedBox(height: ResoniaSpacing.md),
              Text(
                'Her gün kaç dakika?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text('Hedefin: ${goalTitle(_goal!)}'),
              const SizedBox(height: ResoniaSpacing.sm),
              const Text(
                'Bu bir planlama tercihi; başarı veya sınava hazırlık ölçüsü değil. Süreni daha sonra günlük plandan değiştirebilirsin.',
              ),
              const SizedBox(height: ResoniaSpacing.lg),
              for (final budget in DailyBudget.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: ResoniaSpacing.md),
                  child: AnswerOption(
                    key: Key('onboarding_budget_${budget.minutes}'),
                    title: '${budget.minutes} dakika',
                    state: budget == _budget
                        ? OptionState.selected
                        : OptionState.idle,
                    onTap: _busy
                        ? null
                        : () => setState(() {
                            _budget = budget;
                            _error = null;
                          }),
                  ),
                ),
              if (_busy || _error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _busy ? 'Seçim kaydediliyor…' : _error!,
                    key: const Key('onboarding_status'),
                  ),
                ),
              const SizedBox(height: ResoniaSpacing.md),
              ChunkyButton(
                key: const Key('onboarding_finish'),
                label: 'Kaydet ve başla',
                onPressed: _busy ? null : () => _complete(saveBudget: true),
              ),
              const SizedBox(height: ResoniaSpacing.md),
              ChunkyButton(
                key: const Key('onboarding_skip_budget'),
                label: 'Süreyi değiştirmeden devam et',
                tone: ChunkyTone.neutral,
                onPressed: _busy ? null : () => _complete(saveBudget: false),
              ),
              const SizedBox(height: ResoniaSpacing.sm),
              Text(
                _savedBudget == null
                    ? 'Atlamak mevcut süre tercihini korur; tercih yoksa günlük plan 12 dakika kullanır.'
                    : 'Kaydedilen süre: ${_savedBudget!.minutes} dakika. Süreyi değiştirmeden devam etmek bunu korur.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
