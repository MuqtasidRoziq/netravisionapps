import 'dart:math' as math;
import 'dart:ui';

/// Tingkat risiko objek khusus Mode Dalam Ruangan.
///
/// Nilai ini sengaja terpisah dari mode deteksi lain. Kamera RGB tunggal tidak
/// cukup andal untuk menyatakan sebuah jalur "aman", sehingga mesin hanya
/// memberi tingkat kewaspadaan berdasarkan posisi dan ukuran objek di frame.
enum IndoorRiskLevel { none, notice, warning, critical }

enum IndoorDirection { kiri, depan, kanan }

enum IndoorProximity { sangatDekat, dekat, sedang, jauh }

/// Bentuk netral hasil deteksi agar kebijakan Indoor dapat diuji tanpa kamera.
class IndoorObservation {
  const IndoorObservation({
    required this.label,
    required this.confidence,
    required this.box,
  });

  final String label;
  final double confidence;
  final Rect box;
}

class IndoorTarget {
  const IndoorTarget({
    required this.label,
    required this.confidence,
    required this.box,
    required this.direction,
    required this.proximity,
    required this.risk,
    required this.inTravelPath,
    required this.score,
  });

  final String label;
  final double confidence;
  final Rect box;
  final IndoorDirection direction;
  final IndoorProximity proximity;
  final IndoorRiskLevel risk;
  final bool inTravelPath;
  final double score;

  String get alertKey => '${label.toLowerCase()}:${direction.name}';
}

class IndoorScene {
  const IndoorScene({required this.targets});

  final List<IndoorTarget> targets;

  IndoorTarget? get primaryHazard {
    for (final target in targets) {
      if (target.risk == IndoorRiskLevel.critical ||
          target.risk == IndoorRiskLevel.warning) {
        return target;
      }
    }
    return null;
  }
}

/// Analisis scene yang konservatif untuk pendamping mobilitas dalam ruangan.
///
/// Mesin ini tidak mencoba memberi instruksi belok. Object detection tidak
/// mengetahui apakah sisi kiri/kanan benar-benar bebas, sehingga instruksi
/// menghindar dapat berbahaya. Yang diberikan hanya lokasi relatif, kedekatan
/// kualitatif, dan perintah berhenti ketika objek memenuhi koridor jalan.
class IndoorAssistEngine {
  IndoorAssistEngine._();

  static const double corridorLeft = 0.31;
  static const double corridorRight = 0.69;

  /// Kelas COCO yang realistis menjadi penghalang mobilitas di dalam ruangan.
  /// Nama Indonesia mengikuti `assets/models/indoor/labels.txt`; nama Inggris
  /// dipertahankan sebagai fallback bila metadata model berubah.
  static const Set<String> mobilityObstacleLabels = {
    'orang',
    'person',
    'sepeda',
    'bicycle',
    'sepeda motor',
    'motorcycle',
    'bangku',
    'bench',
    'kucing',
    'cat',
    'anjing',
    'dog',
    'tas punggung',
    'backpack',
    'tas tangan',
    'handbag',
    'koper',
    'suitcase',
    'bola',
    'sports ball',
    'papan luncur',
    'skateboard',
    'botol',
    'bottle',
    'kursi',
    'chair',
    'sofa',
    'couch',
    'tanaman pot',
    'potted plant',
    'tempat tidur',
    'bed',
    'meja makan',
    'dining table',
    'toilet',
  };

  static IndoorScene analyze(Iterable<IndoorObservation> observations) {
    final targets = observations.where(_isValid).map(_analyzeTarget).toList()
      ..sort(_compareTargets);
    return IndoorScene(targets: List.unmodifiable(targets));
  }

  static bool _isValid(IndoorObservation observation) {
    final box = observation.box;
    return observation.label.trim().isNotEmpty &&
        observation.confidence.isFinite &&
        observation.confidence >= 0 &&
        box.left.isFinite &&
        box.top.isFinite &&
        box.right.isFinite &&
        box.bottom.isFinite &&
        box.width > 0 &&
        box.height > 0 &&
        box.right > 0 &&
        box.bottom > 0 &&
        box.left < 1 &&
        box.top < 1;
  }

  static IndoorTarget _analyzeTarget(IndoorObservation observation) {
    final box = Rect.fromLTRB(
      observation.box.left.clamp(0.0, 1.0),
      observation.box.top.clamp(0.0, 1.0),
      observation.box.right.clamp(0.0, 1.0),
      observation.box.bottom.clamp(0.0, 1.0),
    );
    final direction = directionOf(box);
    final proximity = proximityOf(box);
    final inPath = isInTravelPath(box);
    final isObstacle = mobilityObstacleLabels.contains(
      observation.label.trim().toLowerCase(),
    );

    var risk = IndoorRiskLevel.none;
    if (isObstacle && inPath) {
      risk = switch (proximity) {
        IndoorProximity.sangatDekat => IndoorRiskLevel.critical,
        IndoorProximity.dekat => IndoorRiskLevel.warning,
        IndoorProximity.sedang => IndoorRiskLevel.notice,
        IndoorProximity.jauh => IndoorRiskLevel.none,
      };
    }

    // Keyakinan rendah tidak boleh menghasilkan alarm keras satu frame.
    if (observation.confidence < 0.50 && risk == IndoorRiskLevel.critical) {
      risk = IndoorRiskLevel.warning;
    } else if (observation.confidence < 0.45 &&
        risk == IndoorRiskLevel.warning) {
      risk = IndoorRiskLevel.notice;
    }

    final area = box.width * box.height;
    final pathOverlap = _pathOverlap(box);
    final score =
        risk.index * 1000 +
        pathOverlap * 100 +
        area * 20 +
        observation.confidence;

    return IndoorTarget(
      label: observation.label.trim().toLowerCase(),
      confidence: observation.confidence,
      box: box,
      direction: direction,
      proximity: proximity,
      risk: risk,
      inTravelPath: inPath,
      score: score,
    );
  }

  static IndoorDirection directionOf(Rect box) {
    final centerX = (box.left + box.right) / 2;
    if (centerX < 0.38) return IndoorDirection.kiri;
    if (centerX > 0.62) return IndoorDirection.kanan;
    return IndoorDirection.depan;
  }

  /// Kedekatan kualitatif dari luas serta dimensi kotak.
  ///
  /// Tidak ada nilai meter: ukuran fisik objek bervariasi dan kamera ini tidak
  /// memiliki data depth. Hasil hanya dipakai untuk prioritas kewaspadaan.
  static IndoorProximity proximityOf(Rect box) {
    final area = box.width * box.height;
    if (area >= 0.20 || box.width >= 0.68 || box.height >= 0.78) {
      return IndoorProximity.sangatDekat;
    }
    if (area >= 0.075 || box.width >= 0.42 || box.height >= 0.58) {
      return IndoorProximity.dekat;
    }
    if (area >= 0.025 || box.width >= 0.22 || box.height >= 0.34) {
      return IndoorProximity.sedang;
    }
    return IndoorProximity.jauh;
  }

  /// Sebuah objek dianggap menyentuh koridor jalan bila kotaknya cukup masuk
  /// bagian tengah frame dan bagian bawahnya mencapai area lantai/pengguna.
  static bool isInTravelPath(Rect box) {
    if (box.bottom < 0.48) return false;
    final overlap = _pathOverlap(box);
    final requiredOverlap = math.min(0.08, box.width * 0.30);
    return overlap >= requiredOverlap;
  }

  static double _pathOverlap(Rect box) {
    return math.max(
      0,
      math.min(box.right, corridorRight) - math.max(box.left, corridorLeft),
    );
  }

  static int _compareTargets(IndoorTarget a, IndoorTarget b) {
    final scoreOrder = b.score.compareTo(a.score);
    if (scoreOrder != 0) return scoreOrder;
    return a.label.compareTo(b.label);
  }

  static String warningSpeech(IndoorTarget target) {
    final label = _spokenLabel(target.label);
    final location = directionText(target.direction);
    if (target.risk == IndoorRiskLevel.critical) {
      return 'Berhenti. Ada $label sangat dekat $location. '
          'Periksa dengan tongkat sebelum melangkah.';
    }
    return 'Hati-hati. Ada $label dekat $location.';
  }

  static String statusText(IndoorScene scene) {
    final hazard = scene.primaryHazard;
    if (hazard != null) {
      final prefix = hazard.risk == IndoorRiskLevel.critical
          ? 'BERHENTI'
          : 'Hati-hati';
      return '$prefix: ${_capitalize(hazard.label)} '
          '${proximityText(hazard.proximity)} '
          '${directionText(hazard.direction)}';
    }
    if (scene.targets.isNotEmpty) {
      return '${scene.targets.length} objek dikenali. Ketuk untuk ringkasan.';
    }
    return 'Memindai jalur di depan...';
  }

  /// Ringkasan diminta pengguna, maksimal tiga objek agar beban audio rendah.
  static String sceneSummary(IndoorScene scene, {int maxItems = 3}) {
    if (scene.targets.isEmpty) {
      return 'Belum ada objek yang dikenali. Ini bukan berarti jalur aman. '
          'Arahkan kamera ke depan dan tetap periksa dengan tongkat.';
    }

    final selected = <IndoorTarget>[];
    final seen = <String>{};
    for (final target in scene.targets) {
      final key = '${target.label}:${target.direction.name}';
      if (!seen.add(key)) continue;
      selected.add(target);
      if (selected.length >= maxItems) break;
    }

    final descriptions = selected
        .map((target) {
          return '${_spokenLabel(target.label)} '
              '${proximityText(target.proximity)} '
              '${directionText(target.direction)}';
        })
        .join('. ');

    final hazard = scene.primaryHazard;
    final ending = hazard == null
        ? 'Tetap periksa jalur dengan tongkat.'
        : 'Ada rintangan di jalur. Berhenti dan periksa dengan tongkat.';
    return 'Ringkasan sekitar. $descriptions. $ending';
  }

  static String directionText(IndoorDirection direction) {
    return switch (direction) {
      IndoorDirection.kiri => 'di sebelah kiri',
      IndoorDirection.depan => 'di depan',
      IndoorDirection.kanan => 'di sebelah kanan',
    };
  }

  static String proximityText(IndoorProximity proximity) {
    return switch (proximity) {
      IndoorProximity.sangatDekat => 'sangat dekat',
      IndoorProximity.dekat => 'dekat',
      IndoorProximity.sedang => 'agak jauh',
      IndoorProximity.jauh => 'jauh',
    };
  }

  static String _spokenLabel(String label) {
    return switch (label) {
      'person' => 'orang',
      'chair' => 'kursi',
      'couch' => 'sofa',
      'potted plant' => 'tanaman pot',
      'dining table' => 'meja makan',
      'bed' => 'tempat tidur',
      'bench' => 'bangku',
      'backpack' => 'tas punggung',
      'handbag' => 'tas tangan',
      'suitcase' => 'koper',
      'sports ball' => 'bola',
      'skateboard' => 'papan luncur',
      'bottle' => 'botol',
      'cat' => 'kucing',
      'dog' => 'anjing',
      'bicycle' => 'sepeda',
      'motorcycle' => 'sepeda motor',
      _ => label,
    };
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

class IndoorAlertDecision {
  const IndoorAlertDecision({required this.speak, required this.urgent});

  static const none = IndoorAlertDecision(speak: false, urgent: false);

  final bool speak;
  final bool urgent;
}

/// Peredam alarm antiframe agar deteksi sesaat tidak membanjiri pengguna.
class IndoorAlertGate {
  IndoorAlertGate({
    this.requiredStableFrames = 2,
    this.warningCooldown = const Duration(seconds: 6),
    this.criticalCooldown = const Duration(seconds: 3),
  });

  final int requiredStableFrames;
  final Duration warningCooldown;
  final Duration criticalCooldown;

  String? _candidateKey;
  int _candidateFrames = 0;
  String? _lastAlertKey;
  IndoorRiskLevel _lastAlertRisk = IndoorRiskLevel.none;
  DateTime? _lastAlertAt;

  IndoorAlertDecision evaluate(IndoorTarget? target, DateTime now) {
    if (target == null || target.risk.index < IndoorRiskLevel.warning.index) {
      _candidateKey = null;
      _candidateFrames = 0;
      return IndoorAlertDecision.none;
    }

    if (_candidateKey == target.alertKey) {
      _candidateFrames++;
    } else {
      _candidateKey = target.alertKey;
      _candidateFrames = 1;
    }

    // Semua alarm harus stabil lintas frame. Dengan pemrosesan Indoor 4 fps,
    // dua frame menambah sekitar 250 ms tetapi menahan false-positive satu frame.
    final stable = _candidateFrames >= requiredStableFrames;
    if (!stable) return IndoorAlertDecision.none;

    final changed = target.alertKey != _lastAlertKey;
    final escalated = target.risk.index > _lastAlertRisk.index;
    final cooldown = target.risk == IndoorRiskLevel.critical
        ? criticalCooldown
        : warningCooldown;
    final cooldownPassed =
        _lastAlertAt == null || now.difference(_lastAlertAt!) >= cooldown;

    if (!changed && !escalated && !cooldownPassed) {
      return IndoorAlertDecision.none;
    }

    _lastAlertKey = target.alertKey;
    _lastAlertRisk = target.risk;
    _lastAlertAt = now;
    return IndoorAlertDecision(
      speak: true,
      urgent: target.risk == IndoorRiskLevel.critical,
    );
  }

  void reset() {
    _candidateKey = null;
    _candidateFrames = 0;
    _lastAlertKey = null;
    _lastAlertRisk = IndoorRiskLevel.none;
    _lastAlertAt = null;
  }
}
