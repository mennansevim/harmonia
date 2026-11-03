import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/resonia_theme.dart';
import '../../application/data_export.dart';
import '../../application/practice_preferences.dart';
import '../../application/result_history.dart';
import '../../domain/models/learner_profile.dart';
import '../common/ui/resonia_ui.dart';

/// DATA-03 local part: copy an audio-free export to the clipboard, or add
/// results from a pasted export. Nothing is sent anywhere by the app.
class DataTransferScreen extends StatefulWidget {
  const DataTransferScreen({
    super.key,
    required this.history,
    required this.profile,
    this.preferences,
    this.onPreferencesImported,
    this.clock,
  });
  final ResultHistoryRepository history;
  final LearnerProfile? profile;
  final PracticePreferencesRepository? preferences;
  final VoidCallback? onPreferencesImported;
  final DateTime Function()? clock;

  @override
  State<DataTransferScreen> createState() => _DataTransferScreenState();
}

class _DataTransferScreenState extends State<DataTransferScreen> {
  final _input = TextEditingController();
  String? _exportStatus;
  String? _importStatus;
  var _busy = false;
  var _generation = 0;

  @override
  void didUpdateWidget(covariant DataTransferScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.history, widget.history) ||
        !identical(oldWidget.profile, widget.profile) ||
        !identical(oldWidget.preferences, widget.preferences)) {
      _generation++;
      _busy = false;
      _exportStatus = null;
      _importStatus = null;
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    if (_busy) return;
    final generation = _generation;
    final history = widget.history;
    final profile = widget.profile;
    final preferences = widget.preferences;
    final clock = widget.clock ?? DateTime.now;
    setState(() {
      _busy = true;
      _exportStatus = null;
    });
    try {
      final entries = await history.load();
      PortablePracticePreferences? portable;
      if (preferences != null) {
        try {
          portable = await preferences.loadPortablePreferences();
        } catch (_) {
          if (mounted && generation == _generation) {
            _exportStatus =
                'Çalışma tercihleri okunamadığı için dışa aktarılamadı. Panoya hiçbir şey yazılmadı.';
          }
          return;
        }
      }
      if (!mounted || generation != _generation) return;
      final text = LocalDataExport.encode(
        profile: profile,
        entries: entries,
        exportedAt: clock(),
        preferences: portable,
      );
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted || generation != _generation) return;
      _exportStatus =
          '${entries.length} sonuç, hedef seçimin${portable == null ? '' : ' ve çalışma tercihlerin'} panoya kopyalandı. Ses kaydı içermez. '
          'Panodaki metni nereye yapıştırdığına sen karar verirsin; uygulama hiçbir yere göndermez.';
    } on HistoryStorageException {
      if (generation == _generation) {
        _exportStatus = 'Geçmiş okunamadığı için dışa aktarılamadı.';
      }
    } on LocalDataFormatException {
      if (generation == _generation) {
        _exportStatus =
            'Dışa aktarma 4 MB sınırını aştığı için panoya yazılmadı.';
      }
    } on PlatformException {
      if (generation == _generation) {
        _exportStatus =
            'Panoya kopyalama doğrulanamadı. Yeniden deneyebilirsin.';
      }
    } on MissingPluginException {
      if (generation == _generation) {
        _exportStatus =
            'Bu cihazda pano kullanılamıyor. Yeniden deneyebilirsin.';
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    final LocalDataDocument doc;
    try {
      doc = LocalDataExport.decode(_input.text);
    } on LocalDataFormatException catch (e) {
      setState(() => _importStatus = _reason(e.reason));
      return;
    }
    final generation = _generation;
    final history = widget.history;
    final preferences = widget.preferences;
    final onPreferencesImported = widget.onPreferencesImported;
    setState(() {
      _busy = true;
      _importStatus = null;
    });
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Sonuçlar eklensin mi?'),
          content: Text(
            '${doc.entries.length} sonuç bulundu. Aynı deneme veya oturum zaten varsa tekrar sayılmaz; '
            'aynı kimlikte farklı içerik varsa mevcut kayıt korunur. Hedef seçimin değişmez.'
            '${doc.preferences != null && preferences != null ? ' Günlük süre ve haftalık hedef uygulanır; hatırlatma ve titreşim bu cihaza özel kalır.' : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              key: const Key('confirm_import'),
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Ekle'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted || generation != _generation) return;
      final r = await LocalDataExport.importResults(doc, history);
      var preferenceStatus = '';
      if (doc.preferences != null && preferences != null) {
        try {
          await preferences.savePortablePreferences(doc.preferences!);
          if (mounted && generation == _generation) {
            onPreferencesImported?.call();
          }
          preferenceStatus = ' Çalışma tercihleri uygulandı.';
        } catch (_) {
          preferenceStatus =
              ' Sonuçlar işlendi; çalışma tercihleri kaydedilemedi.';
        }
      }
      if (!mounted || generation != _generation) return;
      _importStatus =
          'Eklendi: ${r.recorded}. Zaten vardı: ${r.duplicate}. '
          'Çakışan (korundu): ${r.conflict}. Yer yok: ${r.storageFull}.$preferenceStatus';
    } on HistoryStorageException {
      if (generation == _generation) {
        _importStatus =
            'Geçmiş kaydedilemedi. Bu gruptan hiçbir sonuç eklenmedi; yeniden deneyebilirsin.';
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
      }
    }
  }

  static String _reason(String r) => switch (r) {
    'too_large' => 'Metin çok büyük (4 MB sınırı).',
    'not_json' || 'not_object' => 'Bu bir Vocalart dışa aktarma metni değil.',
    'version' || 'keys' =>
      'Desteklenmeyen dışa aktarma sürümü veya biçimi. Hiçbir şey eklenmedi.',
    _ => 'Metin bozuk veya eksik. Hiçbir şey eklenmedi.',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LessonScaffold(
      progress: null,
      counter: 'Yerel',
      closeLabel: 'Veri taşımayı kapat',
      top: [
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: StatusPill('Ses kaydı içermez'),
        ),
        const SizedBox(height: ResoniaSpacing.md),
        Text('Verilerini taşı', style: text.headlineSmall),
        const Text('Hedef, sonuç ve çalışma planı. Sunucuya gönderilmez.'),
        const SizedBox(height: ResoniaSpacing.md),
        Text('Dışa aktar', style: text.titleMedium),
        const SizedBox(height: ResoniaSpacing.xs),
        const Text(
          'Sonuçlar, günlük süre ve haftalık hedef panoya kopyalanır. Ses, hatırlatma ve titreşim taşınmaz.',
        ),
        const SizedBox(height: ResoniaSpacing.sm),
        ChunkyButton(
          key: const Key('export_copy'),
          onPressed: _busy ? null : _export,
          icon: Icons.copy,
          label: 'Panoya kopyala',
        ),
        if (_exportStatus != null)
          Padding(
            padding: const EdgeInsets.only(top: ResoniaSpacing.sm),
            child: Semantics(
              liveRegion: true,
              child: Text(_exportStatus!, key: const Key('export_status')),
            ),
          ),
        const SizedBox(height: ResoniaSpacing.lg),
        Text('İçe aktar', style: text.titleMedium),
        const SizedBox(height: ResoniaSpacing.xs),
        const Text(
          'Başka bir cihazdan kopyaladığın metni buraya yapıştır. Önce tamamı doğrulanır; bozuksa hiçbir şey eklenmez.',
        ),
        const SizedBox(height: ResoniaSpacing.sm),
        TextField(
          key: const Key('import_text'),
          controller: _input,
          enabled: !_busy,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Dışa aktarma metni',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: ResoniaSpacing.sm),
        ChunkyButton(
          key: const Key('import_apply'),
          onPressed: _busy ? null : _import,
          tone: ChunkyTone.neutral,
          label: 'Doğrula ve ekle',
        ),
        if (_importStatus != null)
          Padding(
            padding: const EdgeInsets.only(top: ResoniaSpacing.sm),
            child: Semantics(
              liveRegion: true,
              child: Text(_importStatus!, key: const Key('import_status')),
            ),
          ),
        if (_busy)
          Semantics(
            liveRegion: true,
            child: const Text(
              'Onay veya işlem bekleniyor…',
              key: Key('transfer_busy'),
            ),
          ),
      ],
    );
  }
}
