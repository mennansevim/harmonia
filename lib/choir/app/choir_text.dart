import 'package:flutter/widgets.dart';

import '../data/choir_bundle.dart';
import '../domain/assignment.dart';
import '../domain/choir.dart';
import '../domain/resource.dart';
import '../domain/submission.dart';

/// Choir module wording. Turkish on Turkish devices, English everywhere else,
/// so a choir abroad can use the module today; the rest of the app is still
/// Turkish. New languages are added here.
class CT {
  const CT(this.en);
  final bool en;

  static CT of(BuildContext context) =>
      CT(Localizations.localeOf(context).languageCode != 'tr');

  String _(String tr, String english) => en ? english : tr;

  // Hub
  String get tabLabel => _('Koro', 'Choir');
  String get hubSubtitle => _(
    'Ödevler, eşlikli kayıt, şefin geri bildirimi',
    'Assignments, accompanied takes, your conductor\'s feedback',
  );
  String get introTitle => _('Koronun tek yeri', 'One place for your choir');
  String get introBody => _(
    'Şef ödevi verir, MIDI ile çalışırsın, tek telefonla eşlikli kaydedersin, şef dinleyip geri döner.',
    'The conductor sets the work, you practise with the MIDI, record with accompaniment on one phone, and the conductor replies.',
  );
  String get createChoir => _('Koro oluştur', 'Create a choir');
  String get openPackage => _('Koro paketini aç', 'Open a choir package');
  String get openFile => _('Gelen dosyayı aç', 'Open a received file');
  String get howSharing => _(
    'Sunucu yok: dosyalar bu cihazda kalır. Paylaşımı sen yaparsın; koronun kullandığı her kanal olur.',
    'No server: files stay on this device. You do the sharing, over whatever your choir already uses.',
  );
  String get choirName => _('Koronun adı', 'Choir name');
  String get yourName => _('Adın', 'Your name');
  String get conductorRole => _('Şef', 'Conductor');
  String get create => _('Oluştur', 'Create');
  String get joinTitle => _('Koroya katıl', 'Join the choir');
  String get whichPart => _('Partin hangisi?', 'Which part do you sing?');
  String get join => _('Katıl', 'Join');
  String get loadErrorBody => _(
    'Koro verileri okunamadı. Veriyi korumak için değişiklik kaydedilmiyor.',
    'Choir data could not be read. To protect it, nothing is being saved.',
  );

  String partName(ChoirPart p) => switch (p) {
    ChoirPart.soprano => 'Soprano',
    ChoirPart.alto => 'Alto',
    ChoirPart.tenor => 'Tenor',
    ChoirPart.bass => _('Bas', 'Bass'),
  };

  String bundleProblem(BundleProblem p) => switch (p) {
    BundleProblem.notABundle => _(
      'Bu bir Harmonia koro dosyası değil.',
      'This is not a Harmonia choir file.',
    ),
    BundleProblem.tooLarge => _('Dosya çok büyük.', 'This file is too large.'),
    BundleProblem.damaged => _(
      'Dosya bozuk ya da eksik.',
      'This file is damaged or incomplete.',
    ),
    BundleProblem.newerVersion => _(
      'Bu dosya için uygulamayı güncelle.',
      'Update the app to open this file.',
    ),
    BundleProblem.ownChoir => _(
      'Bu paketi sen hazırladın.',
      'You made this package yourself.',
    ),
    BundleProblem.unknownChoir => _(
      'Önce koronun paketini aç.',
      'Open your choir\'s package first.',
    ),
    BundleProblem.wrongChoir => _(
      'Bu paket başka bir şefe ait.',
      'This package belongs to another conductor.',
    ),
    BundleProblem.notForYou => _(
      'Bu dosya sana gönderilmemiş.',
      'This file was not meant for you.',
    ),
  };

  String bundleOutcome(BundleOutcome o) => switch (o) {
    BundleOutcome.needsJoin => joinTitle,
    BundleOutcome.choirUpdated => _('Koro güncellendi.', 'Choir updated.'),
    BundleOutcome.takeReceived => _(
      'Kayıt dinleme sırasına eklendi.',
      'Take added to your listening queue.',
    ),
    BundleOutcome.feedbackReceived => _(
      'Şefin geri bildirimi geldi.',
      'Your conductor\'s feedback is here.',
    ),
    BundleOutcome.nothingNew => _('Yeni bir şey yok.', 'Nothing new.'),
  };

  // Choir screen
  String get assignments => _('Ödevler', 'Assignments');
  String get noAssignments => _('Henüz ödev yok.', 'No assignments yet.');
  String get noAssignmentsSinger => _(
    'Henüz ödev yok. Şef yeni paket gönderince buradan aç.',
    'No assignments yet. Open the next package your conductor sends.',
  );
  String get newAssignment => _('Yeni ödev', 'New assignment');
  String get library => _('Kaynaklar', 'Library');
  String get librarySub => _(
    'Notalar, ders kayıtları, notlar',
    'Scores, rehearsal recordings, notes',
  );
  String get listeningQueue => _('Dinleme sırası', 'Listening queue');
  String queueCount(int n) => n == 0
      ? _('Bekleyen kayıt yok', 'No takes waiting')
      : _('$n kayıt bekliyor', '$n takes waiting');
  String get shareChoir => _('Koro paketini paylaş', 'Share the choir package');
  String get shareChoirSub => _(
    'Ödevleri, MIDI\'leri ve kaynakları koroya gönder',
    'Send assignments, MIDI files and the library to the choir',
  );
  String get singers => _('Koristler', 'Singers');
  String get singersEmpty => _(
    'Koristler ilk kayıtlarını gönderince burada görünür.',
    'Singers appear here once they send their first take.',
  );
  String get leaveChoir => _('Bu cihazdan kaldır', 'Remove from this device');
  String get leaveTitle =>
      _('Koro bu cihazdan silinsin mi?', 'Remove this choir from this device?');
  String get leaveBody => _(
    'Ödevler, kayıtlar ve kaynaklar bu cihazdan silinir. Geri alınamaz.',
    'Assignments, takes and library items are deleted from this device. This cannot be undone.',
  );
  String get cancel => _('Vazgeç', 'Cancel');
  String get delete => _('Sil', 'Delete');

  // Due dates
  String dueLabel(DateTime now, DateTime due) {
    final local = due.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final days = day.difference(today).inDays;
    if (now.isAfter(due)) return _('Süresi geçti', 'Past due');
    if (days == 0) return _('Bugün son gün', 'Due today');
    if (days == 1) return _('Yarın son gün', 'Due tomorrow');
    return _('$days gün kaldı', '$days days left');
  }

  String get noDue => _('Son tarih yok', 'No due date');
  String dueToday(String title, String label) =>
      _('Koro ödevi: $title · $label', 'Choir work: $title · $label');
  String piecesDone(int done, int total) =>
      _('$done / $total eser gönderildi', '$done of $total pieces sent');

  // Editor
  String get assignmentTitle => _('Ödev başlığı', 'Assignment title');
  String get parts => _('Partiler', 'Parts');
  String get dueDate => _('Son gönderim', 'Due');
  String get chooseDue => _('Tarih seç', 'Choose a date');
  String get noteToChoir =>
      _('Koroya not (isteğe bağlı)', 'Note to the choir (optional)');
  String get pieces => _('Eserler', 'Pieces');
  String get addPiece => _('Eser ekle', 'Add a piece');
  String get addPieceHint => _(
    'Birden fazla eser isteyebilirsin; her biri ayrı kaydedilir.',
    'You can ask for several pieces; each is recorded separately.',
  );
  String get publish => _('Yayınla ve paylaş', 'Publish and share');
  String get needTitlePartPiece => _(
    'Başlık, en az bir parti ve bir eser gerekli.',
    'Add a title, at least one part and one piece.',
  );

  // Piece editor
  String get pieceTitle => _('Eserin adı', 'Piece title');
  String get howSung => _('Nasıl okunacak?', 'How should it be sung?');
  String modeName(PieceMode m) => switch (m) {
    PieceMode.solfege => _('Solfej', 'Solfège'),
    PieceMode.lyrics => _('Sözlü', 'With lyrics'),
  };
  String modeHint(PieceMode m) => switch (m) {
    PieceMode.solfege => _('Nota değerleriyle oku.', 'Read it on the notes.'),
    PieceMode.lyrics => _('Sözleriyle söyle.', 'Sing it with the words.'),
  };
  String get range => _('Hangi bölüm?', 'Which passage?');
  String get fromMeasure => _('Ölçü', 'From bar');
  String get toMeasure => _('Ölçüye', 'To bar');
  String get wholeWork =>
      _('Boş bırakırsan eserin tamamı.', 'Leave empty for the whole work.');
  String get sectionNote => _(
    'Ya da yazıyla (B harfinden sona)',
    'Or in words (letter B to the end)',
  );
  String get midiFile => _('MIDI dosyası', 'MIDI file');
  String get chooseMidi => _('MIDI seç', 'Choose MIDI');
  String midiSummary(int measures, int tracks) =>
      _('$measures ölçü · $tracks kanal', '$measures bars · $tracks tracks');
  String get withAccompaniment =>
      _('Eşlikli kayıt iste', 'Ask for an accompanied take');
  String get accompanimentHint => _(
    'Korist MIDI\'yi kulaklıktan duyar; kayıt eşlikle birlikte gelir.',
    'The singer hears the MIDI on headphones; the take arrives with it.',
  );
  String get partMap =>
      _('Kanallar hangi partiye ait?', 'Which part is each track?');
  String get accompanimentTrack => _('Eşlik', 'Accompaniment');
  String get rightsTitle =>
      _('Bu dosyayı paylaşma hakkın', 'Your right to share this file');
  String rightsName(RightsDeclaration r) => switch (r) {
    RightsDeclaration.ownRecording => _('Kendim hazırladım', 'I made it'),
    RightsDeclaration.licensed => _('Lisansım var', 'I hold a licence'),
    RightsDeclaration.publicDomain => _('Kamu malı', 'Public domain'),
    RightsDeclaration.unknown => _('Bilmiyorum', 'I don\'t know'),
  };
  String get rightsBlocked => _(
    'Hakkı belirsiz dosya koroya dağıtılamaz.',
    'A file with unclear rights cannot go out to the choir.',
  );
  String get midiBad =>
      _('Bu MIDI dosyası okunamadı.', 'This MIDI file could not be read.');
  String get rangeBad =>
      _('Bu ölçüler dosyada yok.', 'Those bars are not in this file.');
  String get savePiece => _('Eseri ekle', 'Add piece');

  // Assignment
  String sectionText(AssignmentPiece p) {
    if (p.fromMeasure != null) {
      return _(
        'Ölçü ${p.fromMeasure}–${p.toMeasure}',
        'Bars ${p.fromMeasure}–${p.toMeasure}',
      );
    }
    return p.sectionNote.isNotEmpty ? p.sectionNote : _('Tamamı', 'Whole work');
  }

  String get accompanied => _('Eşlikli', 'Accompanied');
  String get unaccompanied => _('Eşliksiz', 'Unaccompanied');
  String get practise => _('Çalış', 'Practise');
  String get record => _('Kaydet', 'Record');
  String get recordAgain => _('Yeniden kaydet', 'Record again');
  String get listen => _('Dinle', 'Listen');
  String get sendToConductor => _('Şefe gönder', 'Send to conductor');
  String get deleteTake => _('Kaydı sil', 'Delete take');
  String get notYours => _(
    'Bu ödev senin partin için değil.',
    'This assignment is not for your part.',
  );

  String statusName(SubmissionStatus? s) => switch (s) {
    null => _('Kaydedilmedi', 'Not recorded'),
    SubmissionStatus.draft => _('Gönderilmedi', 'Not sent'),
    SubmissionStatus.submitted => _('Gönderildi', 'Sent'),
    SubmissionStatus.listened => _('Dinlendi', 'Listened to'),
    SubmissionStatus.accepted => _('Kabul edildi', 'Accepted'),
    SubmissionStatus.revisionRequested => _('Tekrar isteniyor', 'Please redo'),
  };

  String get lateTag => _('Son tarihten sonra', 'After the due date');
  String get sharedFile =>
      _('Dosya paylaşıma hazır.', 'The file is ready to share.');
  String takeKindName(TakeKind k) => switch (k) {
    TakeKind.accompaniedMix => accompanied,
    TakeKind.unaccompanied => unaccompanied,
    TakeKind.imported => _('Başka cihazdan', 'From another device'),
  };

  // Practice
  String get myPart => _('Partim', 'My part');
  String get fullChoir => _('Tüm koro', 'Full choir');
  String get ownVolume => _('Kendi partim', 'My part');
  String get othersVolume => _('Diğer sesler', 'Other voices');
  String get metronome => _('Metronom', 'Metronome');
  String tempoLabel(int percent) => _('Hız %$percent', 'Tempo $percent%');
  String get loop => _('Bölümü döngüye al', 'Loop this passage');
  String get countIn => _('Ön sayım', 'Count-in');
  String get preparing => _('Hazırlanıyor…', 'Preparing…');
  String get play => _('Çal', 'Play');
  String get pause => _('Duraklat', 'Pause');
  String get synthNotice => _(
    'Sesler uygulamada üretilir; piyano kaydı değildir.',
    'Sounds are generated by the app; this is not a piano recording.',
  );
  String get renderFailed =>
      _('Bu bölüm hazırlanamadı.', 'This passage could not be prepared.');
  String get tooLong => _(
    'Bölüm çok uzun; daha kısa bir aralık seç.',
    'Too long; choose a shorter passage.',
  );
  String get noMidi =>
      _('Bu eser için MIDI yok.', 'There is no MIDI for this piece.');

  // Take
  String get recordTake => _('Kayıt', 'Recording');
  String get headphonesTitle => _('Tek telefon yeter', 'One phone is enough');
  String get headphonesBody => _(
    'MIDI kulaklığından çalar, mikrofon yalnız sesini alır. Bitince ikisi birleşir ve şefe eşlikli kayıt gider. İkinci cihaz gerekmez.',
    'The MIDI plays in your headphones and the mic takes only your voice. Afterwards they are joined, so the conductor gets an accompanied take. No second device.',
  );
  String routeText(int advice) => switch (advice) {
    0 => _('Kablolu kulaklık bağlı.', 'Wired headphones connected.'),
    1 => _(
      'Bluetooth kulaklık gecikme ekler. Mümkünse kablolu kullan; gerekirse kayıttan sonra hizalarsın.',
      'Bluetooth adds delay. Use wired if you can; you can align the take afterwards.',
    ),
    2 => _(
      'Kulaklık görünmüyor. Takılıysa devam et.',
      'No headphones detected. Continue if they are plugged in.',
    ),
    _ => _(
      'Hoparlörde eşlik mikrofona girer. Kulaklık tak.',
      'On the speaker, the accompaniment would leak into the mic. Plug in headphones.',
    ),
  };
  String get checkAgain => _('Yeniden kontrol et', 'Check again');
  String get headphonesOn => _('Kulaklık takılı', 'Headphones are on');
  String get addFromDevice =>
      _('Başka cihazdaki kaydı ekle', 'Add a take from another device');
  String get singHint => _(
    'Hazır olunca başla. Önce ölçü sayımı gelir.',
    'Start when ready. A bar of counting comes first.',
  );
  String get startRecording => _('Kaydı başlat', 'Start recording');
  String get stopRecording => _('Bitir', 'Finish');
  String get recording => _('Kayıt sürüyor', 'Recording');
  String get mixing =>
      _('Eşlikle birleştiriliyor…', 'Joining with the accompaniment…');
  String get interrupted => _(
    'Kayıt kesildi (kulaklık çıktı ya da arama geldi). Baştan al.',
    'The take was interrupted (headphones removed, or a call). Start again.',
  );
  String get takeFailed => _(
    'Kayıt tamamlanamadı. Yeniden dene.',
    'The take could not be finished. Try again.',
  );
  String get micDenied => _(
    'Mikrofon izni gerekli. Ayarlardan aç.',
    'Microphone access is needed. Turn it on in Settings.',
  );
  String get alignTitle => _(
    'Sesin eşlikle aynı mı?',
    'Is your voice in time with the accompaniment?',
  );
  String get alignBody => _(
    'Geride kaldıysa sağa, öndeyse sola al. Otomatik ölçülmez, kulağınla ayarla.',
    'If you sound late, move right; early, move left. This is not measured; set it by ear.',
  );
  String alignValue(int ms) => ms == 0
      ? _('Düzeltme yok', 'No correction')
      : _(
          '${ms.abs()} ms ${ms > 0 ? 'öne' : 'geriye'}',
          '${ms.abs()} ms ${ms > 0 ? 'earlier' : 'later'}',
        );
  String get keepTake => _('Bu kaydı sakla', 'Keep this take');
  String get consentTitle => _('Kayıt izni', 'Recording consent');
  String get consentBody => _(
    'Sesin bu cihaza kaydedilir ve yalnız sen paylaşırsan şefe gider. Kaydı göndermeden silebilirsin. 18 yaşından küçüksen velinin iznini al.',
    'Your voice is saved on this device and reaches the conductor only if you share it. You can delete a take before sending. Under 18? Get a parent\'s or guardian\'s permission.',
  );
  String get agree => _('Anladım, kabul ediyorum', 'I understand and agree');
  String tooLongTake(int minutes) => _(
    'Kayıt en fazla $minutes dakika olabilir.',
    'A take can be at most $minutes minutes.',
  );
  String get fileBad =>
      _('Bu ses dosyası açılamadı.', 'This audio file could not be opened.');

  // Review
  String get reviewTake => _('Kaydı dinle', 'Listen to the take');
  String get speed => _('Hız', 'Speed');
  String get markHere => _('Bu ana işaretle', 'Mark this moment');
  String get yourComment => _('Yorumun', 'Your comment');
  String get voiceNote => _('Sesli düzeltme', 'Voice correction');
  String get voiceNoteHint => _(
    'Doğrusunu kendi sesinle söyle.',
    'Sing or say it the right way yourself.',
  );
  String get recordVoice => _('Sesini kaydet', 'Record your voice');
  String get stopVoice => _('Kaydı bitir', 'Stop recording');
  String get removeVoice => _('Sesli notu kaldır', 'Remove voice note');
  String get accept => _('Kabul et', 'Accept');
  String get askRedo => _('Tekrar iste', 'Ask for a redo');
  String get needFeedback => _(
    'Yorum, etiket, işaret ya da sesli not ekle.',
    'Add a comment, tag, mark or voice note.',
  );
  String tagName(FeedbackTag t) => switch (t) {
    FeedbackTag.pitch => _('Perde', 'Pitch'),
    FeedbackTag.rhythm => _('Ritim', 'Rhythm'),
    FeedbackTag.entry => _('Giriş', 'Entry'),
    FeedbackTag.breath => _('Nefes', 'Breath'),
    FeedbackTag.breathLeak => _('Nefes kaçağı', 'Breath leak'),
    FeedbackTag.diction => _('Söz', 'Diction'),
    FeedbackTag.dynamics => _('Nüans', 'Dynamics'),
    FeedbackTag.wellDone => _('İyi iş', 'Well done'),
  };
  String get progress => _('Durum', 'Status');
  String partProgress(PartProgress p) => _(
    '${p.singers} kişi · ${p.accepted} kabul · ${p.toReview} bekliyor · ${p.revisionRequested} tekrar · ${p.notSent} gönderilmedi',
    '${p.singers} singers · ${p.accepted} accepted · ${p.toReview} waiting · ${p.revisionRequested} redo · ${p.notSent} not sent',
  );
  String get rosterLimit => _(
    'Yalnız en az bir kayıt gönderen koristler sayılır.',
    'Only singers who have sent at least one take are counted.',
  );
  String get resendFeedback => _('Geri bildirimi paylaş', 'Share feedback');
  String get reviewDone => _(
    'Geri bildirim hazır. Koriste gönder.',
    'Feedback is ready. Send it to the singer.',
  );

  // Feedback view
  String get feedbackTitle =>
      _('Şefin geri bildirimi', 'Conductor\'s feedback');
  String get practiseThis => _('Bununla çalış', 'Practise this');
  String get playVoiceNote => _('Şefin sesini dinle', 'Hear your conductor');

  // Library
  String kindName(ResourceKind k) => switch (k) {
    ResourceKind.score => _('Notalar', 'Scores'),
    ResourceKind.rehearsalRecording => _(
      'Ders kayıtları',
      'Rehearsal recordings',
    ),
    ResourceKind.note => _('Notlar', 'Notes'),
  };
  String get addResource => _('Ekle', 'Add');
  String get libraryEmpty => _('Henüz kaynak yok.', 'Nothing here yet.');
  String get libraryHint => _(
    'Derse gelemeyenler için kayıtlar burada kalır.',
    'Rehearsal recordings stay here for those who could not come.',
  );
  String get resourceTitle => _('Başlık', 'Title');
  String get resourceText => _('Not', 'Note');
  String get chooseFile => _('Dosya seç', 'Choose a file');
  String get rehearsalDay => _('Ders günü', 'Rehearsal day');
  String get save => _('Kaydet', 'Save');
  String get personalOnly => _(
    'Bu kayıt yalnız sende kalır; koroya şefin paketi gider.',
    'This stays with you; only the conductor\'s package goes to the choir.',
  );
  String get shareLibraryHint => _(
    'Koroya ulaşması için koro paketini yeniden paylaş.',
    'Share the choir package again so the choir gets this.',
  );
  String get cannotOpen =>
      _('Bu dosya açılamadı.', 'This file could not be opened.');
  String by(String name) => _('Ekleyen: $name', 'Added by $name');
}
