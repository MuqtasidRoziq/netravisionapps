import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../../data/models/vision_mode.dart';
import '../../../data/models/vision_model_config.dart';
import '../../../services/tts_service.dart';
import '../../../services/vibration_service.dart';
import '../../../utils/helpers/danger_speech_policy.dart';
import '../../../utils/helpers/detection_filter.dart';
import '../../../utils/helpers/object_speech_helper.dart';
import '../../../utils/helpers/single_object_search_catalog.dart';
import '../../../utils/helpers/spatial_estimator.dart';

/// Orkestrasi deteksi NetraVision di atas plugin `ultralytics_yolo`.
///
/// Kamera + inferensi ditangani native oleh [YOLOView] (layout NCHW didukung
/// penuh). Controller ini hanya: memilih model sesuai mode, menyaring hasil
/// deteksi, menentukan prioritas bahaya, lalu membacakan lewat TTS.
class DetectorController extends GetxController with WidgetsBindingObserver {
  final TtsService ttsService = Get.find<TtsService>();
  final VibrationService vibrationService = Get.find<VibrationService>();

  /// Dikendalikan secara imperatif dan dipasang ke [YOLOView] di layer view.
  final YOLOViewController yoloController = YOLOViewController();

  late VisionMode mode;
  final RxString targetObject = 'ponsel'.obs;
  /// Bounding box normalisasi (0.0..1.0) khusus objek tunggal yang sedang dicari
  final Rx<Rect?> targetBox = Rx<Rect?>(null);
  final RxDouble targetConfidence = 0.0.obs;
  final RxString currentStatusText = 'Menyiapkan kamera & model AI...'.obs;
  final RxString lastDetectedObject = ''.obs;
  final RxBool isPaused = false.obs;

  // Buffer persistensi temporal khusus Mode Cari Objek:
  // Menjaga kotak dan status tidak berkedip (flicker) saat ada frame yang sempat drop
  // akibat gerakan kamera atau blur sesaat.
  static const int _targetPersistenceMs = 600;
  DateTime _lastTargetDetectedTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Throttle: proses maksimal 2 frame per detik agar CPU & TTS tidak dibanjiri.
  static const _frameIntervalMs = 500;
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Gating pengumuman: kalimat biasa hanya diucapkan ulang bila label atau
  // band jarak berubah, atau cooldown lewat — agar ucapan tidak terputus terus.
  static const _announceCooldownMs = 3000;
  String _lastAnnouncedLabel = '';
  ProximityBand? _lastAnnouncedBand;
  HorizontalZone? _lastSearchHorizontal;
  DateTime _lastAnnounceTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Gating pengumuman bahaya: "Awas" diredam agar tidak seranah tiap frame.
  static const _dangerCooldownMs = 5000;
  static const _dangerReannounceMinGapMs = 2000;
  bool _lastFrameWasDanger = false;
  String _lastDangerLabel = '';
  ProximityBand? _lastDangerBand;
  double? _lastDangerMeters;
  DateTime _lastDangerSpeakTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Histori classIndex frame-frame terakhir yang diproses, untuk konfirmasi
  // temporal (label baru hanya diumumkan bila stabil beberapa frame).
  final List<int> _recentClassIndices = [];

  /// Konfigurasi model untuk mode aktif (sumber tunggal di
  /// [VisionModelConfig]): path model, task, dan ambang threshold.
  VisionModelConfig get modelConfig => VisionModelConfig.forMode(mode);

  /// Batas maksimum deteksi per frame; mode uang sengaja kecil agar tidak
  /// "rame" dibanjiri deteksi palsu.
  int get _maxNumItems => mode == VisionMode.currency ? 5 : 30;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    if (Get.arguments is VisionMode) {
      mode = Get.arguments as VisionMode;
    } else if (Get.arguments is Map) {
      final args = Get.arguments as Map;
      mode = (args['mode'] as VisionMode?) ?? VisionMode.indoor;
      if (args['target'] != null) {
        targetObject.value = args['target'].toString().trim().toLowerCase();
      }
    } else {
      mode = VisionMode.indoor;
    }
    // Terapkan segera; YOLOViewController mengingat nilainya dan menyamplikannya
    // ke native saat platform view menempel.
    yoloController.setNumItemsThreshold(_maxNumItems);
    if (mode == VisionMode.findObject) {
      yoloController.setShowOverlays(false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // Hentikan suara & preview saat app ke background agar hemat baterai.
        ttsService.stop();
        vibrationService.stop();
        yoloController.pause();
        break;
      case AppLifecycleState.resumed:
        if (!isPaused.value) {
          yoloController.resume();
        }
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Dipanggil [YOLOView] setelah model berhasil dimuat/diganti.
  void handleModelLoad(String modelPath, YOLOTask? task) {
    if (mode == VisionMode.currency) {
      yoloController.setShowOverlays(true);
      currentStatusText.value = 'Arahkan uang ke kamera...';
      ttsService.speak(mode.announcement);
    } else if (mode == VisionMode.findObject) {
      // Sembunyikan seluruh bounding box objek lain secara native
      // agar fokus visual murni hanya ke 1 objek yang dipilih.
      yoloController.setShowOverlays(false);
      targetBox.value = null;
      targetConfidence.value = 0.0;
      currentStatusText.value = 'Mencari ${targetObject.value}...';
      ttsService.speak(
        'Mode Cari Objek aktif. Mencari ${targetObject.value}. Arahkan kamera ke sekeliling ruangan.',
      );
    } else {
      yoloController.setShowOverlays(true);
      currentStatusText.value = 'Mencari objek di depan Anda...';
      ttsService.speak(mode.announcement);
    }
  }

  /// Dipanggil [YOLOView] bila model gagal dimuat.
  void handleModelError(Object error, String modelPath, YOLOTask? task) {
    currentStatusText.value = 'Gagal memuat model. Periksa file assets.';
    ttsService.speak('Peringatan: Gagal memuat model deteksi.');
  }

  /// Callback hasil inferensi per frame dari [YOLOView].
  void handleResults(List<YOLOResult> results) {
    if (isPaused.value || results.isEmpty) {
      if (mode == VisionMode.findObject) {
        targetBox.value = null;
        targetConfidence.value = 0.0;
      }
      return;
    }

    // Khusus Mode Cari Objek: update posisi kotak visual sehalus mungkin (per frame)
    // dan pastikan HANYA 1 objek target yang terdeteksi & ditampilkan.
    if (mode == VisionMode.findObject) {
      final target = targetObject.value.trim().toLowerCase();
      final targetMatches = results
          .where((r) => SingleObjectSearchCatalog.matches(r.className, target))
          .toList();

      if (targetMatches.isNotEmpty) {
        final best = DetectionFilter.selectBest(targetMatches);
        _lastTargetDetectedTime = DateTime.now();
        targetBox.value = best.normalizedBox;
        targetConfidence.value = best.confidence;
      } else {
        final elapsed = DateTime.now().difference(_lastTargetDetectedTime).inMilliseconds;
        if (elapsed > _targetPersistenceMs) {
          targetBox.value = null;
          targetConfidence.value = 0.0;
        }
      }
    }

    final now = DateTime.now();
    if (now.difference(_lastFrameTime).inMilliseconds < _frameIntervalMs) {
      return;
    }
    _lastFrameTime = now;

    _processDetectionResults(results);
  }

  void _processDetectionResults(List<YOLOResult> results) {
    // 0. Cabang khusus Mode Cari Objek Tunggal
    if (mode == VisionMode.findObject) {
      _processSingleObjectSearch(results);
      return;
    }

    // 1. Saring label yang layak diumumkan + (khusus uang) bentuk kotak yang
    //    memang layak uang (ukuran cukup, tidak terpotong tepi).
    final validDetections = results
        .where((r) => ObjectSpeechHelper.shouldAnnounce(r.className, mode))
        .where((r) =>
            mode != VisionMode.currency ||
            DetectionFilter.isPlausibleMoneyBox(r.normalizedBox))
        .toList();
    if (validDetections.isEmpty) return;

    // 2. Prioritas: rintangan berbahaya langsung; selain itu ambil deteksi
    //    terbaik (confidence × luas) — uang asli besar menang atas palsu kecil.
    final dangerous =
        validDetections
            .where(
              (d) => ObjectSpeechHelper.isDangerousObstacle(d.className),
            )
            .toList();
    final bool isDangerous = dangerous.isNotEmpty;
    final YOLOResult targetDetection = isDangerous
        ? dangerous.first
        : DetectionFilter.selectBest(validDetections);

    // 3. Konfirmasi temporal: label baru hanya diumumkan bila stabil (muncul
    //    2 dari 3 frame terakhir) agar blip satu frame tidak jadi suara.
    //    Rintangan berbahaya dikecualikan — keselamatan tidak menunggu.
    _recentClassIndices.add(targetDetection.classIndex);
    if (_recentClassIndices.length > DetectionFilter.temporalWindowSize) {
      _recentClassIndices.removeAt(0);
    }
    if (!isDangerous &&
        !DetectionFilter.isStable(_recentClassIndices, targetDetection.classIndex)) {
      return;
    }

    final String detectedLabel = targetDetection.className;
    lastDetectedObject.value = detectedLabel;

    final spatial = (mode == VisionMode.indoor || mode == VisionMode.outdoor)
        ? SpatialEstimator.of(targetDetection)
        : null;

    final displayName =
        ObjectSpeechHelper.formatDisplayName(detectedLabel, mode, spatial: spatial);
    currentStatusText.value = isDangerous
        ? '⚠️ $displayName'
        : 'Terdeteksi: $displayName';

    final speechText =
        ObjectSpeechHelper.formatForTts(detectedLabel, mode, spatial: spatial);

    // Gating: bahaya diredam ("Awas" saat pertama, memburuk, atau pengingat
    // periodik). Kalimat biasa hanya bila label/band berubah atau cooldown
    // lewat — agar ucapan berjalan tak terputus.
    final announceTime = DateTime.now();
    final band = spatial?.band;

    final DangerSpeechDecision dangerDecision =
        isDangerous
            ? DangerSpeechPolicy.decide(
                firstDanger: !_lastFrameWasDanger,
                worsened: DangerSpeechPolicy.worsened(
                  label: detectedLabel,
                  band: band,
                  meters: spatial?.meters,
                  prevLabel: _lastDangerLabel,
                  prevBand: _lastDangerBand,
                  prevMeters: _lastDangerMeters,
                ),
                msSinceLast: announceTime
                    .difference(_lastDangerSpeakTime)
                    .inMilliseconds,
                escalationMinGapMs: _dangerReannounceMinGapMs,
                periodicCooldownMs: _dangerCooldownMs,
              )
            : const DangerSpeechDecision(speak: false, urgent: false);

    final bool changed =
        !isDangerous &&
        (detectedLabel != _lastAnnouncedLabel ||
            band != _lastAnnouncedBand);
    final bool cooldownPassed =
        announceTime.difference(_lastAnnounceTime).inMilliseconds >=
        _announceCooldownMs;

    final bool shouldSpeak =
        dangerDecision.speak || changed || (cooldownPassed && !isDangerous);

    // Bookkeeping per frame untuk deteksi bahaya.
    _lastFrameWasDanger = isDangerous;
    if (isDangerous) {
      _lastDangerLabel = detectedLabel;
      _lastDangerBand = band;
      _lastDangerMeters = spatial?.meters;
      if (dangerDecision.speak) {
        _lastDangerSpeakTime = announceTime;
      }
    }

    if (shouldSpeak) {
      _lastAnnouncedLabel = detectedLabel;
      _lastAnnouncedBand = band;
      _lastAnnounceTime = announceTime;
      ttsService.speak(
        speechText,
        isUrgent: isDangerous ? dangerDecision.urgent : false,
      );
    }

    // Getaran proporsional: hanya indoor/outdoor, dipicu bila bahaya atau dekat.
    if (mode == VisionMode.indoor || mode == VisionMode.outdoor) {
      if (isDangerous ||
          spatial?.band == ProximityBand.sangatDekat ||
          spatial?.band == ProximityBand.dekat) {
        vibrationService.vibrateNear(
          band: spatial?.band ?? ProximityBand.dekat,
          dangerous: isDangerous,
        );
      } else {
        vibrationService.stop();
      }
    } else {
      // Mode uang: tidak ikut getaran (sesuai permintaan).
      vibrationService.stop();
    }
  }

  /// Pemrosesan khusus mode pencarian objek tunggal.
  void _processSingleObjectSearch(List<YOLOResult> results) {
    final target = targetObject.value.trim().toLowerCase();
    final matches = results
        .where((r) => SingleObjectSearchCatalog.matches(r.className, target))
        .toList();

    final now = DateTime.now();

    if (matches.isEmpty) {
      final elapsedSinceDetected = now.difference(_lastTargetDetectedTime).inMilliseconds;
      // Bila masih dalam batas persistensi temporal (drop frame sesaat karena gerak kamera),
      // pertahankan status agar getaran dan pengumuman arah tidak terputus kaget.
      if (elapsedSinceDetected < _targetPersistenceMs && targetBox.value != null) {
        return;
      }

      currentStatusText.value = 'Mencari $target...';
      vibrationService.stop();

      // Pengingat periodik tiap 6 detik jika target belum tampak di kamera
      if (now.difference(_lastAnnounceTime).inMilliseconds >= 6000) {
        _lastAnnounceTime = now;
        ttsService.speak('$target belum terlihat. Putar kamera perlahan.');
      }
      return;
    }

    final bestTarget = DetectionFilter.selectBest(matches);
    final spatial = SpatialEstimator.of(bestTarget);
    lastDetectedObject.value = target;

    final displayName = ObjectSpeechHelper.formatDisplayName(
      target,
      mode,
      spatial: spatial,
      targetObject: target,
    );
    currentStatusText.value = displayName;

    final speechText = ObjectSpeechHelper.formatForTts(
      target,
      mode,
      spatial: spatial,
      targetObject: target,
    );

    final band = spatial.band;
    final hor = spatial.horizontal;

    final bool positionChanged =
        hor != _lastSearchHorizontal || band != _lastAnnouncedBand;
    final bool cooldownPassed =
        now.difference(_lastAnnounceTime).inMilliseconds >= 2500;

    if (positionChanged || cooldownPassed) {
      _lastSearchHorizontal = hor;
      _lastAnnouncedBand = band;
      _lastAnnounceTime = now;
      final bool isSuperClose = band == ProximityBand.sangatDekat;
      ttsService.speak(speechText, isUrgent: isSuperClose);
    }

    // Getaran taktil memandu kedekatan:
    vibrationService.vibrateNear(
      band: band,
      dangerous: band == ProximityBand.sangatDekat,
    );
  }

  /// Mengganti target objek yang ingin dicari secara interaktif
  void setTargetObject(String newTarget) {
    targetObject.value = newTarget.trim().toLowerCase();
    targetBox.value = null;
    targetConfidence.value = 0.0;
    _lastTargetDetectedTime = DateTime.fromMillisecondsSinceEpoch(0);
    _lastAnnouncedLabel = '';
    _lastAnnouncedBand = null;
    _lastSearchHorizontal = null;
    _lastAnnounceTime = DateTime.fromMillisecondsSinceEpoch(0);
    lastDetectedObject.value = '';
    currentStatusText.value = 'Mencari ${targetObject.value}...';
    HapticFeedback.mediumImpact();
    ttsService.speak(
      'Target diubah ke ${targetObject.value}. Arahkan kamera ke sekitar.',
      isUrgent: true,
    );
  }

  void handleScreenTap() {
    HapticFeedback.mediumImpact();
    if (mode == VisionMode.findObject) {
      final target = targetObject.value;
      if (lastDetectedObject.value == target) {
        ttsService.speak(
          'Target $target terdeteksi di hadapan kamera Anda.',
          isUrgent: true,
        );
      } else {
        ttsService.speak(
          'Target $target belum terlihat. Silakan gerakkan kamera ke sekitar.',
          isUrgent: true,
        );
      }
      return;
    }

    if (lastDetectedObject.value.isNotEmpty) {
      final speech =
          ObjectSpeechHelper.formatForTts(lastDetectedObject.value, mode);
      if (mode == VisionMode.currency) {
        ttsService.speak(speech, isUrgent: true);
      } else {
        ttsService.speak('Objek di depan: $speech', isUrgent: true);
      }
    } else {
      if (mode == VisionMode.currency) {
        ttsService.speak('Belum ada uang terdeteksi di depan kamera.',
            isUrgent: true);
      } else {
        ttsService.speak('Belum ada objek terdeteksi di depan Anda.',
            isUrgent: true);
      }
    }
  }

  void togglePause() {
    isPaused.value = !isPaused.value;
    if (isPaused.value) {
      yoloController.pause();
      ttsService.speak('Deteksi dijeda');
    } else {
      yoloController.resume();
      ttsService.speak('Deteksi dilanjutkan');
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    yoloController.dispose(); // Tutup stream zoom/lens/focus milik controller.
    ttsService.stop();
    vibrationService.stop();
    super.onClose();
  }
}
