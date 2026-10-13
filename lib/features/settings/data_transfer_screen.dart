import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/harmonia_theme.dart';
import '../../application/data_export.dart';
import '../../application/result_history.dart';
import '../../domain/models/learner_profile.dart';

/// DATA-03 local part: copy an audio-free export to the clipboard, or add
/// results from a pasted export. Nothing is sent anywhere by the app.
class DataTransferScreen extends StatefulWidget {
  const DataTransferScreen({
    super.key,
    required this.history,
    required this.profile,
    this.clock,
  });
  final ResultHistoryRepository history;
  final LearnerProfile? profile;
  final DateTime Function()? clock;

  @override
  State<DataTransferScreen> createState() => _DataTransferScreenState();
}

class _DataTransferScreenState extends State<DataTransferScreen> {
  final _input = TextEditingController();
  String? _exportStatus;
  String? _importStatus;
  var _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final entries = await widget.history.load();
      final text = LocalDataExport.encode(
        profile: widget.profile,
        entries: entries,
        exportedAt: (widget.clock ?? DateTime.now)(),
      );
      await Clipboard.setData(ClipboardData(text: text));
      _exportStatus =
          '${entries.length} sonuç ve hedef seçimin panoya kopyalandı. Ses kaydı içermez. '
          'Panodaki metni nereye yapıştırdığına sen karar verirsin; uygulama hiçbir yere göndermez.';
    } on HistoryStorageException {
      _exportStatus = 'Geçmiş okunamadığı için dışa aktarılamadı.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final LocalDataDocument doc;
    try {
      doc = LocalDataExport.decode(_input.text);
    } on LocalDataFormatException catch (e) {
      setState(() => _importStatus = _reason(e.reason));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sonuçlar eklensin mi?'),
        content: Text(
          '${doc.entries.length} sonuç bulundu. Aynı deneme zaten varsa tekrar sayılmaz; '
          'farklı içerikli aynı deneme kimliği varsa mevcut kayıt korunur. Hedef seçimin değişmez.',
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
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = await LocalDataExport.importResults(doc, widget.history);
      _importStatus =
          'Eklendi: ${r.recorded}. Zaten vardı: ${r.duplicate}. '
          'Çakışan (korundu): ${r.conflict}. Yer yok: ${r.storageFull}.';
    } on HistoryStorageException {
      _importStatus =
          'Geçmiş kaydedilemedi. Eklenenler korunur; yeniden denediğinde tekrar sayılmaz.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _reason(String r) => switch (r) {
    'too_large' => 'Metin çok büyük (4 MB sınırı).',
    'not_json' || 'not_object' => 'Bu bir Harmonia dışa aktarma metni değil.',
    'version' || 'keys' =>
      'Desteklenmeyen dışa aktarma sürümü veya biçimi. Hiçbir şey eklenmedi.',
    _ => 'Metin bozuk veya eksik. Hiçbir şey eklenmedi.',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Verilerini taşı')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HarmoniaSpacing.lg),
          children: [
            Text('Dışa aktar', style: text.titleMedium),
            const SizedBox(height: HarmoniaSpacing.xs),
            const Text(
              'Hedef seçimin ve ölçülen sonuç özetlerin (ses değil) okunabilir bir metin olarak panoya kopyalanır.',
            ),
            const SizedBox(height: HarmoniaSpacing.sm),
            FilledButton.icon(
              key: const Key('export_copy'),
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.copy),
              label: const Text('Panoya kopyala'),
            ),
            if (_exportStatus != null)
              Padding(
                padding: const EdgeInsets.only(top: HarmoniaSpacing.sm),
                child: Text(_exportStatus!, key: const Key('export_status')),
              ),
            const SizedBox(height: HarmoniaSpacing.lg),
            Text('İçe aktar', style: text.titleMedium),
            const SizedBox(height: HarmoniaSpacing.xs),
            const Text(
              'Başka bir cihazdan kopyaladığın metni buraya yapıştır. Önce tamamı doğrulanır; bozuksa hiçbir şey eklenmez.',
            ),
            const SizedBox(height: HarmoniaSpacing.sm),
            TextField(
              key: const Key('import_text'),
              controller: _input,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Dışa aktarma metni',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: HarmoniaSpacing.sm),
            OutlinedButton(
              key: const Key('import_apply'),
              onPressed: _busy ? null : _import,
              child: const Text('Doğrula ve ekle'),
            ),
            if (_importStatus != null)
              Padding(
                padding: const EdgeInsets.only(top: HarmoniaSpacing.sm),
                child: Text(_importStatus!, key: const Key('import_status')),
              ),
          ],
        ),
      ),
    );
  }
}
