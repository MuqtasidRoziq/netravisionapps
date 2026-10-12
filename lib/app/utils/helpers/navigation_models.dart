import 'geo_math.dart';

/// Buang frase perintah dari kalimat tujuan (hasil STT), sisakan kata tujuan.
///
/// Contoh: "saya ingin pergi ke warung" → "warung".
String extractDestinationQuery(String sentence) {
  var lower = sentence.trim().toLowerCase();
  const prefixes = [
    'saya ingin pergi ke',
    'tolong antar saya ke',
    'tolong bawa saya ke',
    'saya mau pergi ke',
    'tolong carikan',
    'saya ingin ke',
    'saya mau ke',
    'mau pergi ke',
    'ingin pergi ke',
    'tolong cari',
    'pergi ke',
    'mau ke',
    'ingin ke',
    'carikan',
    'cari saya',
    'cari',
    'ke',
  ];
  for (final prefix in prefixes) {
    if (lower.startsWith(prefix)) {
      final after = lower.substring(prefix.length).trim();
      if (after.isNotEmpty) return after;
    }
  }
  return sentence.trim();
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