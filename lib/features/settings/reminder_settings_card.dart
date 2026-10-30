import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../application/practice_preferences.dart';
import '../../application/practice_reminder.dart';
import '../common/ui/resonia_ui.dart';

typedef ReminderTimePicker =
    Future<TimeOfDay?> Function(BuildContext context, TimeOfDay initialTime);

class ReminderSettingsCard extends StatefulWidget {
  const ReminderSettingsCard({
    super.key,
    required this.coordinator,
    this.pickTime,
  });

  final PracticeReminderCoordinator coordinator;
  final ReminderTimePicker? pickTime;

  @override
  State<ReminderSettingsCard> createState() => _ReminderSettingsCardState();
}

class _ReminderSettingsCardState extends State<ReminderSettingsCard> {
  PracticeReminderTime? _time;
  ReminderPermission? _permission;
  bool _loading = true, _updating = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait<Object?>([
        widget.coordinator.load(),
        widget.coordinator.inspectPermission(),
      ]);
      if (!mounted) return;
      setState(() {
        _time = values[0] as PracticeReminderTime?;
        _permission = values[1] as ReminderPermission;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Hatırlatma durumu okunamadı. Yeniden deneyebilirsin.';
      });
    }
  }

  Future<void> _chooseTime() async {
    if (_updating || _permission == ReminderPermission.unavailable) return;
    final initial = _time == null
        ? const TimeOfDay(hour: 19, minute: 0)
        : TimeOfDay(hour: _time!.hour, minute: _time!.minute);
    final picked = await (widget.pickTime ?? _defaultPicker)(context, initial);
    if (picked == null || !mounted) return;
    setState(() {
      _updating = true;
      _message = null;
    });
    final candidate = PracticeReminderTime(
      hour: picked.hour,
      minute: picked.minute,
    );
    final outcome = await widget.coordinator.enable(candidate);
    if (!mounted) return;
    setState(() {
      _updating = false;
      if (outcome == ReminderUpdateOutcome.enabled) _time = candidate;
      if (outcome == ReminderUpdateOutcome.denied) {
        _permission = ReminderPermission.denied;
      }
      _message = _outcomeText(outcome);
    });
  }

  Future<void> _openSettings() async {
    if (_updating) return;
    setState(() {
      _updating = true;
      _message = null;
    });
    final opened = await widget.coordinator.openSettings();
    if (!mounted) return;
    setState(() {
      _updating = false;
      _message = opened
          ? 'Bildirim ayarları açıldı. İzni değiştirdikten sonra Resonia’ya dön.'
          : 'Bildirim ayarları açılamadı. Telefon ayarlarından Resonia bildirimlerini açabilirsin.';
    });
  }

  Future<void> _disable() async {
    if (_updating || _time == null) return;
    setState(() {
      _updating = true;
      _message = null;
    });
    final outcome = await widget.coordinator.disable();
    if (!mounted) return;
    setState(() {
      _updating = false;
      if (outcome == ReminderUpdateOutcome.disabled) _time = null;
      _message = _outcomeText(outcome);
    });
  }

  Future<TimeOfDay?> _defaultPicker(BuildContext context, TimeOfDay initial) =>
      showTimePicker(context: context, initialTime: initial);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final unavailable = _permission == ReminderPermission.unavailable;
    return Card(
      key: const Key('reminder_settings'),
      margin: const EdgeInsets.only(bottom: ResoniaSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(ResoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('Çalışma hatırlatması', style: text.titleMedium),
            ),
            const SizedBox(height: ResoniaSpacing.sm),
            if (_loading)
              const Text('Hatırlatma durumu okunuyor…')
            else if (unavailable) ...[
              const Text(
                'Bu sürümde cihaz bildirimi henüz bağlı değil. Resonia izin istemez ve hatırlatma kurmaz.',
                key: Key('reminder_unavailable'),
              ),
              const SizedBox(height: ResoniaSpacing.sm),
              const StatusPill('Kullanılamıyor', tone: PillTone.neutral),
            ] else ...[
              Text(
                _time == null
                    ? 'Kapalı. Açarsan önce cihaz izni istenir.'
                    : 'Her gün ${_format(_time!)} için ayarlı.',
                key: const Key('reminder_status'),
              ),
              const SizedBox(height: ResoniaSpacing.sm),
              ChunkyButton(
                key: const Key('reminder_choose_time'),
                tone: ChunkyTone.neutral,
                onPressed: _updating ? null : _chooseTime,
                label: _time == null ? 'Saat seç ve aç' : 'Saati değiştir',
              ),
              if (_permission == ReminderPermission.denied) ...[
                const SizedBox(height: ResoniaSpacing.sm),
                TextButton(
                  key: const Key('reminder_open_settings'),
                  onPressed: _updating ? null : _openSettings,
                  child: const Text('Bildirim ayarlarını aç'),
                ),
              ],
              if (_time != null) ...[
                const SizedBox(height: ResoniaSpacing.sm),
                TextButton(
                  key: const Key('reminder_disable'),
                  onPressed: _updating ? null : _disable,
                  child: const Text('Hatırlatmayı kapat'),
                ),
              ],
            ],
            if (_updating || _message != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: ResoniaSpacing.sm),
                  child: Text(
                    _updating ? 'Cihazda doğrulanıyor…' : _message!,
                    key: const Key('reminder_message'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _format(PracticeReminderTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

String _outcomeText(ReminderUpdateOutcome outcome) => switch (outcome) {
  ReminderUpdateOutcome.enabled => 'Hatırlatma cihazda doğrulandı ve açıldı.',
  ReminderUpdateOutcome.disabled => 'Hatırlatma kapatıldı.',
  ReminderUpdateOutcome.denied =>
    'Bildirim izni verilmedi. Cihaz ayarlarından değiştirebilirsin.',
  ReminderUpdateOutcome.unavailable =>
    'Bu cihazda hatırlatma kurulamadı; açık olarak kaydedilmedi.',
  ReminderUpdateOutcome.failed =>
    'Hatırlatma değiştirilemedi; önceki ayar korundu.',
  ReminderUpdateOutcome.busy => 'Önceki işlem hâlâ sürüyor.',
};
