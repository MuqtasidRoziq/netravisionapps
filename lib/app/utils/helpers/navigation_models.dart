import 'geo_math.dart';

/// Buang frase perintah dari kalimat tujuan (hasil STT), sisakan kata tujuan
/// yang sudah dinormalisasi ke entitas tempat yang dikenali (misal: "masjid", "lapangan").
///
/// Contoh:
/// - "saya ingin pergi ke warung" → "warung"
/// - "lokasi masjid" → "masjid"
/// - "dimana masjid terdekat" → "masjid"
/// - "mau sholat" → "masjid"
/// - "ada lapangan di dekat sini" → "lapangan"
String extractDestinationQuery(String sentence) {
  final original = sentence.trim();
  var lower = original.toLowerCase();
  // Hapus tanda baca
  lower = lower.replaceAll(RegExp(r'[^\w\s]'), ' ');

  // 1. Bersihkan frasa sistem / TalkBack yang mungkin bocor ke mikrofon
  final systemPhrases = [
    'silakan sebutkan tujuan anda',
    'silakan ucapkan tujuan anda',
    'silakan sebutkan tujuan',
    'silakan ucapkan tujuan',
    'sebutkan tujuan anda',
    'ucapkan tujuan anda',
    'sebutkan tujuan',
    'ucapkan tujuan',
    'tujuan navigasi',
    'tujuan anda',
    'tujuan saya',
  ];
  for (final phrase in systemPhrases) {
    lower = lower.replaceAll(phrase, ' ');
  }

  // 2. Bersihkan awalan perintah, pertanyaan, dan arahan (diurutkan dari terpanjang)
  const prefixes = [
    'tolong tunjukkan jalan ke',
    'tolong tunjukkan rute ke',
    'tolong tunjukkan arah ke',
    'tolong tunjukkan arah',
    'tolong tunjukkan ke',
    'tolong tunjukkan',
    'tolong tunjukkin jalan ke',
    'tolong tunjukkin rute ke',
    'tolong tunjukkin arah ke',
    'tolong tunjukkin arah',
    'tolong tunjukkin ke',
    'tolong tunjukkin',
    'tolong pandukan saya ke',
    'tolong pandu saya ke',
    'tolong pandu ke',
    'tolong pandu',
    'tolong antarkan saya ke',
    'tolong antarkan ke',
    'tolong antar saya ke',
    'tolong antar ke',
    'tolong tuntun saya ke',
    'tolong tuntun ke',
    'tolong tuntun',
    'tolong bawakan saya ke',
    'tolong bawa saya ke',
    'tolong bawa ke',
    'tolong carikan jalan ke',
    'tolong carikan rute ke',
    'tolong carikan arah ke',
    'tolong carikan tempat',
    'tolong carikan saya',
    'tolong carikan',
    'tolong cari jalan ke',
    'tolong cari rute ke',
    'tolong cari arah ke',
    'tolong cari tempat',
    'tolong cari saya',
    'tolong cari',
    'saya ingin pergi ke',
    'saya mau pergi ke',
    'saya ingin jalan ke',
    'saya mau jalan ke',
    'saya ingin ke',
    'saya mau ke',
    'mau pergi ke',
    'ingin pergi ke',
    'mau jalan ke',
    'ingin jalan ke',
    'tunjukkan jalan ke',
    'tunjukkan rute ke',
    'tunjukkan arah ke',
    'tunjukkan arah',
    'tunjukkan ke',
    'tunjukkan',
    'tunjukkin jalan ke',
    'tunjukkin rute ke',
    'tunjukkin arah ke',
    'tunjukkin arah',
    'tunjukkin ke',
    'tunjukkin',
    'pandukan saya ke',
    'pandu saya ke',
    'pandu arah ke',
    'pandu jalan ke',
    'pandu rute ke',
    'pandu ke',
    'pandu',
    'antarkan saya ke',
    'antarkan ke',
    'antar saya ke',
    'antar ke',
    'tuntun saya ke',
    'tuntun jalan ke',
    'tuntun ke',
    'tuntun',
    'bawakan saya ke',
    'bawa saya ke',
    'bawa ke',
    'carikan jalan ke',
    'carikan rute ke',
    'carikan arah ke',
    'carikan tempat',
    'carikan saya',
    'carikan',
    'cari jalan ke',
    'cari rute ke',
    'cari arah ke',
    'cari tempat',
    'cari saya',
    'cari',
    'apakah ada tempat',
    'apakah ada',
    'ada tempat',
    'ada',
    'dimana ada',
    'di mana ada',
    'dimanakah',
    'dimana',
    'di manakah',
    'di mana',
    'lokasi tempat',
    'lokasi',
    'posisi tempat',
    'posisi',
    'titik tempat',
    'titik',
    'rute jalan ke',
    'rute menuju ke',
    'rute menuju',
    'rute ke',
    'rute',
    'jalur jalan ke',
    'jalur menuju ke',
    'jalur menuju',
    'jalur ke',
    'jalur',
    'arah jalan ke',
    'arah menuju ke',
    'arah menuju',
    'arah ke',
    'arah',
    'jalan menuju ke',
    'jalan menuju',
    'jalan ke',
    'menuju ke',
    'menuju',
    'pergi ke',
    'tujuan ke',
    'tujuan saya ke',
    'tujuan saya',
    'tujuan',
    'mau ke',
    'ingin ke',
    'ke mana',
    'ke',
    'mau sholat di',
    'mau sholat ke',
    'mau sholat',
    'sholat di',
    'sholat ke',
    'sholat',
    'mau makan di',
    'mau makan ke',
    'mau makan',
    'tempat makan',
    'makan di',
    'tempat ibadah',
    'tempat sholat',
  ];

  for (final prefix in prefixes) {
    final pattern = RegExp('^\\s*${RegExp.escape(prefix)}\\b');
    if (pattern.hasMatch(lower)) {
      lower = lower.replaceFirst(pattern, ' ').trim();
      break;
    }
  }

  // 3. Bersihkan modifier relatif (seperti "terdekat dari sini", "di sekitar sini", dll.)
  final modifierPatterns = [
    RegExp(r'\b(yang paling dekat dari sini|paling dekat dari sini|yang terdekat dari sini|terdekat dari sini)\b'),
    RegExp(r'\b(yang paling dekat|paling dekat|yang terdekat|terdekat)\b'),
    RegExp(r'\b(yang ada di dekat sini|yang ada di sekitar sini|yang ada di sini|yang ada)\b'),
    RegExp(r'\b(di dekat sini|dekat sini|di sekitar sini|sekitar sini|di sini|dari sini)\b'),
    RegExp(r'\b(yang dekat|dekat)\b'),
    RegExp(r'\b(dong|ya|sih|deh|nih|lah|tolong|kah|coba)\b'),
  ];
  for (final pattern in modifierPatterns) {
    lower = lower.replaceAll(pattern, ' ');
  }

  lower = lower.replaceAll(RegExp(r'\s+'), ' ').trim();

  // 4. Normalisasi semantik kata kunci tempat populer di Indonesia
  final normalized = _normalizePlaceCategory(lower, original.toLowerCase());
  if (normalized.isNotEmpty) return normalized;

  if (lower.isNotEmpty) return lower;
  return original;
}

/// Normalisasi kata kunci/sinonim tempat umum (masjid, mushola, lapangan, apotek, dll.)
String _normalizePlaceCategory(String query, String raw) {
  final q = query.trim();
  final r = raw.trim();

  // Ibadah / Sholat (masjid, mushola, musholla, mesjid, surau, langgar)
  if (q == 'mesjid' ||
      q == 'mushola' ||
      q == 'musholla' ||
      q == 'surau' ||
      q == 'langgar' ||
      q == 'sholat' ||
      q == 'solat' ||
      q == 'ibadah' ||
      (q.isEmpty && (r.contains('sholat') || r.contains('solat') || r.contains('mesjid') || r.contains('mushola') || r.contains('ibadah')))) {
    return 'masjid';
  }

  // Sekolah Dasar (SD)
  if (q == 'sd' ||
      q == 'sekolah sd' ||
      q == 'sekolah dasar' ||
      q == 'sd negeri' ||
      q == 'sd swasta' ||
      (q.isEmpty && (r.contains('sekolah sd') || r.contains('sekolah dasar') || r.contains('sd')))) {
    return 'sekolah dasar';
  }

  // Madrasah Ibtidaiyah (MI)
  if (q == 'mi' ||
      q == 'sekolah mi' ||
      q == 'madrasah' ||
      q == 'madrasah ibtidaiyah' ||
      (q.isEmpty && (r.contains('sekolah mi') || r.contains('madrasah ibtidaiyah') || r.contains('madrasah')))) {
    return 'madrasah ibtidaiyah';
  }

  // SMP / SMA
  if (q == 'smp' || q == 'sekolah smp' || q == 'smp negeri') {
    return 'smp';
  }
  if (q == 'sma' || q == 'smk' || q == 'sekolah sma' || q == 'sma negeri') {
    return 'sma';
  }

  // Lapangan / Olahraga (futsal, stadion, gor -> lapangan)
  if (q == 'futsal' ||
      q == 'stadion' ||
      q == 'gor' ||
      (q.isEmpty && (r.contains('lapangan') || r.contains('stadion') || r.contains('futsal')))) {
    return 'lapangan';
  }

  // Makanan / Kuliner
  if (q == 'makan' ||
      q == 'lapar' ||
      q == 'kuliner' ||
      (q.isEmpty && (r.contains('makan') || r.contains('lapar')))) {
    return 'warung makan';
  }

  // Apotek / Obat
  if (q == 'apotik' || q == 'obat' || (q.isEmpty && (r.contains('apotik') || r.contains('obat')))) {
    return 'apotek';
  }

  // Toko / Minimarket
  if (q == 'belanja' || q == 'jajan' || q == 'swalayan' || q == 'kelontong') {
    return 'minimarket';
  }

  // SPBU / Bensin
  if (q == 'pom bensin' || q == 'bensin' || q == 'bbm') {
    return 'spbu';
  }

  return q;
}

/// Tempat hasil pencarian tujuan (Google Places).
class GeoPlace {
  final String name;
  final String? address;
  final GeoPoint point;
  final double? distanceMeters;

  const GeoPlace({
    required this.name,
    this.address,
    required this.point,
    this.distanceMeters,
  });
}

/// Satu langkah rute (Google Directions `steps`).
class RouteStep {
  /// Instruksi Bahasa Indonesia hasil API (html_instructions dibersihkan).
  final String instruction;

  /// Maneuver Google (turn-left, turn-right, straight, depart, arrive, ...).
  final String maneuver;

  final double distanceMeters;
  final GeoPoint start;
  final GeoPoint end;

  /// Detail jalur langkah ini (belok halus di dalam satu langkah).
  final List<GeoPoint> points;

  const RouteStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.start,
    required this.end,
    required this.points,
  });
}

/// Hasil lengkap rute pejalan kaki.
class RouteResult {
  final List<RouteStep> steps;
  final List<GeoPoint> overviewPoints;
  final GeoPoint destination;
  final double totalMeters;

  const RouteResult({
    required this.steps,
    required this.overviewPoints,
    required this.destination,
    required this.totalMeters,
  });

  int get stepCount => steps.length;
}

/// Status satu "detak" navigasi (dihasilkan dari posisi GPS terbaru).
class NavTick {
  final bool arrived;

  /// Teks yang harus dibacakan TTS (null = diam).
  final String? speech;

  final int activeStepIndex;

  /// Perkiraan sisa jarak ke tujuan (meter).
  final double remainingMeters;

  /// Jarak dari pengguna ke maneuver langkah aktif (meter).
  final double? distanceToNextManeuver;

  const NavTick({
    required this.arrived,
    this.speech,
    required this.activeStepIndex,
    required this.remainingMeters,
    this.distanceToNextManeuver,
  });
}

/// Mesin keputusan panduan turn-by-turn yang murni & mudah diuji unit.
///
/// Dipanggil sekitar 4 Hz dengan posisi GPS; hanya mengeluarkan suara pada
/// saat yang berarti (mendekati belokan, tiba, atau pengingat lurus).
class NavigationGuider {
  /// Jarak ke titik belok untuk dianggap "sudah melewati" → geser ke langkah
  /// berikutnya (harus lebih kecil dari [turnRadiusM]).
  static const double advanceRadiusM = 10;

  /// Jarak mulai membacakan: "(x) meter, {instruksi}".
  static const double approachRadiusM = 40;

  /// Jarak membacakan instruksi belok dengan tegas ("Belok kiri sekarang").
  static const double turnRadiusM = 20;

  /// Jarak ke tujuan = tiba.
  static const double arrivalRadiusM = 20;

  /// Interval pengingat "lanjutkan lurus" saat masih di langkah yang sama.
  static const Duration continueEvery = Duration(seconds: 30);

  final RouteResult route;
  int activeStep = 0;
  bool _departureSpoken = false;
  bool _approachSpoken = false;
  bool _turnSpoken = false;
  DateTime? _lastContinue;
  DateTime? _lastSpeakTime;

  NavigationGuider(this.route) {
    _lastContinue = null;
    _lastSpeakTime = null;
  }

  int get stepCount => route.steps.length;

  /// Proses satu posisi GPS. Mengembalikan keputusan bicara atau null.
  NavTick tick(GeoPoint position, DateTime now) {
    final steps = route.steps;

    // Tiba: dekat dengan titik akhir langkah terakhir.
    final finalPoint = steps.isEmpty ? route.destination : steps.last.end;
    if (haversineMeters(position, finalPoint) <= arrivalRadiusM) {
      return NavTick(
        arrived: true,
        speech: 'Anda telah tiba di tujuan',
        activeStepIndex: activeStep,
        remainingMeters: 0,
      );
    }

    if (activeStep >= steps.length) {
      // Aman: habis langkah (jarang), tetap arahkan ke tujuan.
      return NavTick(
        arrived: true,
        speech: 'Anda telah tiba di tujuan',
        activeStepIndex: activeStep,
        remainingMeters: 0,
      );
    }

    // Geser langkah aktif bila pengguna sudah melewati titik belok langkah ini.
    while (activeStep < steps.length - 1 &&
        haversineMeters(position, steps[activeStep].end) <= advanceRadiusM) {
      activeStep++;
      _departureSpoken = false;
      _approachSpoken = false;
      _turnSpoken = false;
      _lastContinue = null;
    }

    final step = steps[activeStep];
    // Instruksi "akan datang" berasal dari langkah berikutnya bila ada,
    // karena langkah aktif adalah yang sedang dijalani (lurus).
    final upcoming = activeStep + 1 < steps.length ? steps[activeStep + 1] : null;
    final distToTurn = haversineMeters(position, step.end);
    final remaining = _remainingMeters(position);

    var speech = _decideSpeech(step, upcoming, distToTurn, remaining, now);

    return NavTick(
      arrived: false,
      speech: speech,
      activeStepIndex: activeStep,
      remainingMeters: remaining,
      distanceToNextManeuver: distToTurn,
    );
  }

  String? _decideSpeech(
    RouteStep step,
    RouteStep? upcoming,
    double distToTurn,
    double remaining,
    DateTime now,
  ) {
    // Instruksi yang relevan dibacakan = manuver yang akan datang.
    final target = upcoming ?? step;
    // Instruksi dari API (Bahasa Indonesia). Kosong → sintesis dari maneuver.
    final instruction = _cleanInstruction(target);
    final isActManeuver =
        !{'straight', 'depart', 'arrive', 'default', ''}.contains(target.maneuver);

    // Langkah pertama: berangkat.
    if (activeStep == 0 && !_departureSpoken) {
      _departureSpoken = true;
      _lastSpeakTime = now;
      return 'Mulai berjalan, $instruction';
    }

    // Mendekati belokan: sebut jarak.
    if (distToTurn <= approachRadiusM &&
        distToTurn > turnRadiusM &&
        !_approachSpoken) {
      _approachSpoken = true;
      _lastSpeakTime = now;
      final meters = distToTurn.round().clamp(1, 999);
      return '$meters meter lagi, $instruction';
    }

    // Di belokan: tegas (hanya bila memang ada aksi belok yang akan datang).
    if (distToTurn <= turnRadiusM && !_turnSpoken && isActManeuver) {
      _turnSpoken = true;
      _approachSpoken = true;
      _lastSpeakTime = now;
      return '$instruction sekarang';
    }

    // Pengingat berkala "lanjutkan lurus" selama masih di langkah yang sama.
    // Hanya bila belum ada yang dibicarakan dalam jangka continueEvery.
    final last = _lastContinue;
    final lastSpeak = _lastSpeakTime;
    if (distToTurn > approachRadiusM &&
        (last == null || now.difference(last) >= continueEvery) &&
        lastSpeak != null &&
        now.difference(lastSpeak) >= continueEvery) {
      _lastContinue = now;
      _lastSpeakTime = now;
      final sisa = formatDistanceMeters(remaining);
      return 'Lanjutkan lurus, sisa $sisa menuju tujuan';
    }

    return null;
  }

  double _remainingMeters(GeoPoint position) {
    final steps = route.steps;
    var remaining = 0.0;
    for (var i = activeStep; i < steps.length; i++) {
      remaining += steps[i].distanceMeters;
    }
    // Koreksi dengan sisa jarak menuju akhir langkah aktif.
    if (activeStep < steps.length) {
      final step = steps[activeStep];
      remaining -= step.distanceMeters;
      remaining += haversineMeters(position, step.end);
    }
    return remaining < 0 ? 0 : remaining;
  }

  String _cleanInstruction(RouteStep step) {
    final raw = step.instruction.trim();
    if (raw.isNotEmpty) return raw;
    return switch (step.maneuver) {
      'turn-left' => 'belok kiri',
      'turn-right' => 'belok kanan',
      'turn-slight-left' => 'belok sedikit ke kiri',
      'turn-slight-right' => 'belok sedikit ke kanan',
      'turn-sharp-left' => 'belok tajam ke kiri',
      'turn-sharp-right' => 'belok tajam ke kanan',
      'u-turn' => 'putar balik',
      'roundabout' || 'roundabout-left' || 'roundabout-right' => 'ikuti bundaran',
      'merge' => 'bergabung dengan jalan',
      'fork-left' => 'belok kiri',
      'fork-right' => 'belok kanan',
      'straight' => 'lurus terus',
      'depart' => 'mulai berjalan sesuai arah panah',
      _ => 'lanjutkan perjalanan',
    };
  }

  /// Bersihkan instruksi html → teks polos (Google mengirim tag <b> dst).
  static String cleanHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}