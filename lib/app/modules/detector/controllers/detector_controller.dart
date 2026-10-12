import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../../data/models/vision_mode.dart';
import '../../../data/models/vision_model_config.dart';
import '../../../data/models/visual_help_models.dart';
import '../../../routes/app_pages.dart';
import '../../../services/tts_service.dart';
import '../../../services/vibration_service.dart';
import '../../../utils/helpers/danger_speech_policy.dart';
import '../../../utils/helpers/detection_filter.dart';
import '../../../utils/helpers/object_speech_helper.dart';
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
  final RxString currentStatusText = 'Menyiapkan kamera & model AI...'.obs;
  final RxString lastDetectedObject = ''.obs;
  final RxBool isPaused = false.obs;

  // Throttle: proses maksimal 2 frame per detik agar CPU & TTS tidak dibanjiri.
  static const _frameIntervalMs = 500;
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Gating pengumuman: kalimat biasa hanya diucapkan ulang bila label atau
  // band jarak berubah, atau cooldown lewat — agar ucapan tidak terputus terus.
  static const _announceCooldownMs = 3000;
  String _lastAnnouncedLabel = '';
  ProximityBand? _lastAnnouncedBand;
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
  int _emptyCurrencyFrames = 0;

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
    mode = Get.arguments is VisionMode
        ? Get.arguments as VisionMode
        : VisionMode.indoor;
    // Terapkan segera; YOLOViewController mengingat nilainya dan menyamplikannya
    // ke native saat platform view menempel.
    yoloController.setNumItemsThreshold(_maxNumItems);
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
    currentStatusText.value = mode == VisionMode.currency
        ? 'Arahkan uang ke kamera...'
        : 'Mencari objek di depan Anda...';
    ttsService.speak(mode.announcement);
  }

  /// Dipanggil [YOLOView] bila model gagal dimuat.
  void handleModelError(Object error, String modelPath, YOLOTask? task) {
    currentStatusText.value = 'Gagal memuat model. Periksa file assets.';
    ttsService.speak('Peringatan: Gagal memuat model deteksi.');
  }

  /// Callback hasil inferensi per frame dari [YOLOView].
  void handleResults(List<YOLOResult> results) {
    if (isPaused.value || results.isEmpty) return;

    final now = DateTime.now();
    if (now.difference(_lastFrameTime).inMilliseconds < _frameIntervalMs) {
      return;
    }
    _lastFrameTime = now;

    _processDetectionResults(results);
  }

  void _processDetectionResults(List<YOLOResult> results) {
    // 1. Saring label yang layak diumumkan + ambang batas keyakinan + (khusus uang)
    //    bentuk kotak & rasio aspek yang memang valid uang Rupiah.
    final validDetections = results
        .where((r) => r.confidence >= modelConfig.confidenceThreshold)
        .where((r) => ObjectSpeechHelper.shouldAnnounce(r.className, mode))
        .where((r) =>
            mode != VisionMode.currency ||
            DetectionFilter.isPlausibleMoneyBox(r.normalizedBox,
                label: r.className))
        .toList();

    if (validDetections.isEmpty) {
      if (mode == VisionMode.currency) {
        _emptyCurrencyFrames++;
        if (_emptyCurrencyFrames >= 4) {
          _lastAnnouncedLabel = '';
          _recentClassIndices.clear();
          if (currentStatusText.value != 'Arahkan uang ke kamera...') {
            currentStatusText.value = 'Arahkan uang ke kamera...';
          }
        }
      }
      return;
    }
    _emptyCurrencyFrames = 0;

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

    // Untuk mode baca uang: JANGAN spam suara setiap interval cooldown bila uangnya sama.
    // Tunanetra dapat mengetuk layar kapan saja (On-Demand Repeat) jika ingin mendengar ulang nominal.
    final bool shouldSpeak = dangerDecision.speak ||
        changed ||
        (cooldownPassed && !isDangerous && mode != VisionMode.currency);

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

  void handleScreenTap() {
    HapticFeedback.mediumImpact();
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

  /// Meminta Bantuan Visual langsung dari aktivitas deteksi aktif
  void requestVisualHelp() {
    HapticFeedback.mediumImpact();
    // 1. Matikan audio dan getaran deteksi saat berpindah
    ttsService.stop();
    vibrationService.stop();

    // 2. Jeda deteksi kamera agar tidak bentrok dengan video call
    yoloController.pause();
    isPaused.value = true;

    // 3. Susun konteks tugas otomatis sesuai mode
    TaskType taskType;
    switch (mode) {
      case VisionMode.indoor:
        taskType = TaskType.findObject;
        break;
      case VisionMode.currency:
        taskType = TaskType.readLabel;
        break;
      case VisionMode.outdoor:
        taskType = TaskType.generalHelp;
        break;
    }

    final detected = lastDetectedObject.value.isNotEmpty ? lastDetectedObject.value : null;

    final context = TaskContext(
      taskType: taskType,
      targetName: detected,
      unverifiedAiLabel: detected,
      sourceScreen: 'detector_${mode.name}',
    );

    ttsService.speak('Membuka menu Bantuan Visual untuk ${taskType.label}');
    Get.toNamed(Routes.VISUAL_HELP, arguments: context);
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
