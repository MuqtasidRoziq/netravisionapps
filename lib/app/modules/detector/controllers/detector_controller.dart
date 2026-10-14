import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../../data/models/vision_mode.dart';
import '../../../data/models/vision_model_config.dart';
import '../../../data/models/visual_help_models.dart';
import '../../../routes/app_pages.dart';
import '../../../services/compass_service.dart';
import '../../../services/directions_service.dart';
import '../../../services/location_service.dart';
import '../../../services/places_service.dart';
import '../../../services/tts_service.dart';
import '../../../services/vibration_service.dart';
import '../../../utils/helpers/danger_speech_policy.dart';
import '../../../utils/helpers/detection_filter.dart';
import '../../../utils/helpers/geo_math.dart';
import '../../../utils/helpers/navigation_models.dart';
import '../../../utils/helpers/object_speech_helper.dart';
import '../../../utils/helpers/spatial_estimator.dart';
import '../../../utils/helpers/speech_result_filter.dart';
import '../../../utils/helpers/stt_retry_policy.dart';
import '../../../utils/helpers/tts_policy.dart';
import '../../../services/currency_ocr_service.dart';


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
  final Rx<Rect?> activeDetectionBox = Rx<Rect?>(null);
  final RxString activeDetectionLabel = ''.obs;

  /// Kata kunci barang yang dicari (hanya aktif pada [VisionMode.itemSearch]).
  String targetItem = '';

  // ====================== Navigasi Mode Jalan (Outdoor) ======================
  final LocationService locationService = Get.find<LocationService>();
  final CompassService compassService = Get.find<CompassService>();
  final DirectionsService directionsService = Get.put(DirectionsService());
  final PlacesService placesService = Get.put(PlacesService());

  /// True saat mode aktif outdoor (navigasi peta aktif).
  final RxBool isOutdoor = false.obs;

  /// Posisi GPS terakhir (di-follow kamera peta).
  final Rx<GeoPoint?> userPosition = Rx<GeoPoint?>(null);

  /// Arah hadap (kompas), untuk panah overlay.
  final RxDouble userHeading = 0.0.obs;

  /// Lokasi/kopas layanan berfungsi.
  final RxBool locationAvailable = false.obs;

  /// Polyline rute aktif.
  final Rx<List<GeoPoint>> routePolyline = Rx<List<GeoPoint>>([]);

  /// Titik tujuan di peta.
  final Rx<GeoPoint?> destinationPoint = Rx<GeoPoint?>(null);

  /// Peta kecil vs layar penuh.
  final RxBool mapExpanded = false.obs;

  /// Sedang mendengarkan ucapan tujuan.
  final RxBool isListeningDestination = false.obs;

  /// Teks status navigasi (banner).
  final RxString navStatus = ''.obs;

  /// Nama alamat/jalan terkini pengguna (Reverse Geocoding).
  final RxString currentAddress = ''.obs;
  GeoPoint? _lastGeocodedPosition;
  bool _isGeocoding = false;

  SpeechToText? _speech;
  NavigationGuider? _navGuider;
  StreamSubscription<GeoPoint>? _positionSub;
  StreamSubscription<double>? _compassSub;
  Timer? _navTicker;
  GeoPoint? _lastNavPosition;
  bool _navPrompted = false;
  bool _arrivedSpoken = false;
  bool _sttAvailable = false;
  int _sttInitAttempts = 0;
  String? _sttLocaleId;

  /// Fase sesi dengar tujuan (lihat [DestinationSpeechPhase]).
  DestinationSpeechPhase speechPhase = DestinationSpeechPhase.idle;

  /// Percobaan dengar berjalan saat ini (1 = pertama, dst.).
  int _sttAttempt = 0;

  /// Mencegah `listen()` dipanggil dua kali beruntun (race tombol mic).
  bool _sttStarting = false;

  /// True bila sesi berhenti karena izin mikrofon ditolak.
  bool _sttPermissionDenied = false;

  /// True bila hasil akhir tujuan sesi ini sudah diproses.
  bool _finalHandled = false;

  /// Rekaman kata terakhir dari STT (untuk antisipasi status done tanpa finalResult).
  String _lastRecognizedWords = '';

  /// Memberi waktu plugin mengirim hasil akhir setelah status `done`.
  Timer? _listenDrainTimer;
  static const _drainGrace = Duration(milliseconds: 1200);

  bool _navBusy = false;
  bool _coordinatesAnnounced = false;

  // Throttle: proses frame hingga 5 fps agar deteksi responsif tanpa membebani baterai.
  static const _frameIntervalMs = 200;
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

  // Verifikasi Angka Nominal (On-Device Google ML Kit OCR)
  CurrencyOcrService? _currencyOcr;
  bool _isOcrBusy = false;
  DateTime _lastOcrScanTime = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastOcrVerifiedNominal;
  DateTime _lastOcrVerifiedTime = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _currencyOcrTimer;
  int _consecutiveEmptyOcrCount = 0;

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
    // Ambil kata kunci target barang (hanya untuk mode itemSearch)
    targetItem = Get.parameters['targetItem'] ?? '';

    if (Get.isRegistered<CurrencyOcrService>()) {
      _currencyOcr = Get.find<CurrencyOcrService>();
    } else {
      _currencyOcr = Get.put(CurrencyOcrService());
    }

    // Terapkan segera; YOLOViewController mengingat nilainya dan menyamplikannya
    // ke native saat platform view menempel (mencegah threshold reset ke 0.25).
    yoloController.setThresholds(
      confidenceThreshold: modelConfig.confidenceThreshold,
      iouThreshold: modelConfig.iouThreshold,
      numItemsThreshold: _maxNumItems,
    );

    // Khusus mode baca uang: sembunyikan kotak visual keliru bawaan model
    // dan mulai pemindaian OCR aktif mandiri
    if (mode == VisionMode.currency) {
      yoloController.setShowOverlays(false);
      _startCurrencyOcrTimer();
    }

    if (mode == VisionMode.outdoor) {
      isOutdoor.value = true;
      yoloController.setShowOverlays(false);
      _setupNavigation();
    }
  }

  @override
  void onReady() {
    super.onReady();
    if (mode == VisionMode.outdoor) {
      _promptDestination();
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
        _currencyOcrTimer?.cancel();
        ttsService.stop();
        vibrationService.stop();
        yoloController.pause();
        break;
      case AppLifecycleState.resumed:
        if (!isPaused.value) {
          yoloController.resume();
          if (mode == VisionMode.currency) {
            yoloController.setShowOverlays(false);
            _startCurrencyOcrTimer();
          }
        }
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Dipanggil [YOLOView] setelah model berhasil dimuat/diganti.
  void handleModelLoad(String modelPath, YOLOTask? task) {
    yoloController.setThresholds(
      confidenceThreshold: modelConfig.confidenceThreshold,
      iouThreshold: modelConfig.iouThreshold,
      numItemsThreshold: _maxNumItems,
    );
    if (mode == VisionMode.currency) {
      yoloController.setShowOverlays(false);
      _startCurrencyOcrTimer();
      currentStatusText.value = 'Arahkan uang ke kamera...';
    } else if (mode == VisionMode.itemSearch && targetItem.isNotEmpty) {
      currentStatusText.value = 'Mencari "$targetItem" di depan Anda...';
    } else if (mode == VisionMode.outdoor && destinationPoint.value == null) {
      yoloController.setShowOverlays(false);
      currentStatusText.value = 'Silakan sebutkan tujuan Anda...';
    } else {
      currentStatusText.value = 'Mencari objek di depan Anda...';
    }
    if (mode != VisionMode.outdoor) {
      ttsService.speak(mode.announcement);
    }
    if (mode == VisionMode.itemSearch && targetItem.isNotEmpty) {
      ttsService.speak('Arahkan kamera untuk mencari $targetItem.');
    }
    if (mode == VisionMode.outdoor) {
      _promptDestination();
    }
  }

  /// Dipanggil [YOLOView] bila model gagal dimuat.
  void handleModelError(Object error, String modelPath, YOLOTask? task) {
    currentStatusText.value = 'Gagal memuat model. Periksa file assets.';
    ttsService.speak('Peringatan: Gagal memuat model deteksi.');
  }

  /// Callback hasil inferensi per frame dari [YOLOView].
  void handleResults(List<YOLOResult> results) {
    if (isPaused.value || results.isEmpty) return;
    // Pada mode jalan: jeda proses deteksi sebelum tujuan rute ditentukan atau saat mendengarkan STT tujuan
    if (mode == VisionMode.outdoor && (destinationPoint.value == null || isListeningDestination.value)) {
      if (activeDetectionBox.value != null || activeDetectionLabel.value.isNotEmpty) {
        activeDetectionBox.value = null;
        activeDetectionLabel.value = '';
      }
      return;
    }

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
    var validDetections = results
        .where((r) => r.confidence >= modelConfig.confidenceThreshold)
        .where((r) => ObjectSpeechHelper.shouldAnnounce(r.className, mode,
            classIndex: r.classIndex))
        .where((r) =>
            mode != VisionMode.currency ||
            DetectionFilter.isPlausibleMoneyBox(r.normalizedBox,
                label: r.className))
        .toList();

    // 1b. Khusus mode pencarian barang: hanya tampilkan yang cocok target.
    if (mode == VisionMode.itemSearch && targetItem.isNotEmpty) {
      final target = targetItem.toLowerCase();
      validDetections = validDetections.where((r) {
        final label = ObjectSpeechHelper.resolveLabel(r.className,
                classIndex: r.classIndex)
            .toLowerCase();
        // Cocokkan bila label mengandung kata kunci target atau sebaliknya
        return label.contains(target) ||
            target.split(' ').any((word) => word.length > 2 && label.contains(word));
      }).toList();
      // Jika tidak ada yang cocok, jangan umumkan apa pun
      if (validDetections.isEmpty) return;
    }

    // 1c. Mode Jalan: deteksi kamera berperan sebagai pendamping keselamatan,
    //     bukan pembicara utama.
    //     - Fase memilih tujuan (belum ada rute): sistem standby, hanya bahaya
    //       yang SANGAT dekat (<= 2,5 m) diumumkan, agar pengguna bisa fokus
    //       mendengar arahan peta/menentukan tujuan.
    //     - Fase navigasi aktif: hanya rintangan berbahaya yang dekat
    //       (<= 3 m) yang diumumkan, agar arahan turn-by-turn tidak tertimpa.
    if (mode == VisionMode.outdoor) {
      // Jangan deteksi/umumkan apa pun selama rute belum dibuat. "Google Maps"
      // belum menyuruh berjalan, jadi kamera cukup standby agar tidak
      // mengganggu pengguna saat menentukan tujuan.
      if (destinationPoint.value == null) {
        activeDetectionBox.value = null;
        activeDetectionLabel.value = '';
        return;
      }
      // Fase navigasi aktif: hanya rintangan berbahaya yang dekat (<= 3 m)
      // diumumkan, agar arahan turn-by-turn tidak tertimpa.
      const double maxMeters = 3.0;
      final closeDanger = validDetections.where((d) {
        if (!ObjectSpeechHelper.isDangerousObstacle(d.className,
            classIndex: d.classIndex)) {
          return false;
        }
        final spatial = SpatialEstimator.of(d);
        if (spatial.meters != null) return spatial.meters! <= maxMeters;
        return spatial.band == ProximityBand.sangatDekat ||
            spatial.band == ProximityBand.dekat;
      }).toList();
      if (closeDanger.isEmpty) {
        activeDetectionBox.value = null;
        activeDetectionLabel.value = '';
        return;
      }
      validDetections = closeDanger;
    }

    if (validDetections.isEmpty) {
      activeDetectionBox.value = null;
      activeDetectionLabel.value = '';
      if (mode == VisionMode.currency) {
        _emptyCurrencyFrames++;
        if (_emptyCurrencyFrames >= 4) {
          _lastAnnouncedLabel = '';
          _recentClassIndices.clear();
          _lastOcrVerifiedNominal = null;
          activeDetectionBox.value = null;
          activeDetectionLabel.value = '';
          if (currentStatusText.value != 'Arahkan uang ke kamera...') {
            currentStatusText.value = 'Arahkan uang ke kamera...';
          }
        }
      }
      return;
    }

    _emptyCurrencyFrames = 0;


    // 2. Prioritas: Pada mode indoor dan outdoor, prioritaskan objek yang LEBIH DEKAT
    //    ke pengguna terlebih dahulu agar tidak menabrak rintangan langsung.
    //    Bahaya dipertimbangkan sebagai penentu prioritas pada jarak sebanding.
    //    Untuk mode currency / itemSearch, gunakan deteksi terbaik (confidence × luas).
    final YOLOResult targetDetection =
        (mode == VisionMode.indoor || mode == VisionMode.outdoor)
            ? DetectionFilter.selectClosest(validDetections)
            : DetectionFilter.selectBest(validDetections);

    final bool isDangerous = ObjectSpeechHelper.isDangerousObstacle(
      targetDetection.className,
      classIndex: targetDetection.classIndex,
    );

    // 3. Konfirmasi temporal: label baru hanya diumumkan bila stabil (muncul
    //    2 dari 3 frame terakhir, atau 3 dari 4 frame khusus Mode Baca Uang)
    //    agar blip satu frame dan fluktuasi objek acak tidak jadi suara.
    //    Rintangan berbahaya dikecualikan — keselamatan tidak menunggu.
    _recentClassIndices.add(targetDetection.classIndex);
    final int windowSize = mode == VisionMode.currency
        ? DetectionFilter.currencyTemporalWindowSize
        : DetectionFilter.temporalWindowSize;
    final int requiredHits = mode == VisionMode.currency
        ? DetectionFilter.currencyTemporalRequiredHits
        : DetectionFilter.temporalRequiredHits;

    if (_recentClassIndices.length > windowSize) {
      _recentClassIndices.removeAt(0);
    }
    if (!isDangerous &&
        !DetectionFilter.isStable(_recentClassIndices, targetDetection.classIndex,
            windowSize: windowSize, requiredHits: requiredHits)) {
      return;
    }

    // Khusus Mode Baca Uang: Selalu picu validasi angka nominal via OCR on-device
    if (mode == VisionMode.currency) {
      _runCurrencyOcrVerification();
    }

    final bool hasRecentOcrVerification = mode == VisionMode.currency &&
        _lastOcrVerifiedNominal != null &&
        DateTime.now().difference(_lastOcrVerifiedTime).inMilliseconds < 4500;

    // Untuk uang: bila belum ada verifikasi OCR angka, tampilkan status membaca
    // dan JANGAN biarkan YOLO membacakan nominal yang belum tervalidasi angkanya.
    if (mode == VisionMode.currency && !hasRecentOcrVerification) {
      currentStatusText.value = 'Membaca nominal uang...';
      activeDetectionBox.value = null;
      activeDetectionLabel.value = '';
      return;
    }

    final String rawLabel =
        (mode == VisionMode.currency && hasRecentOcrVerification)
            ? _lastOcrVerifiedNominal!
            : targetDetection.className;
    final String detectedLabel = (mode == VisionMode.currency)
        ? rawLabel
        : ObjectSpeechHelper.resolveLabel(rawLabel,
            classIndex: targetDetection.classIndex);
    lastDetectedObject.value = detectedLabel;

    if (mode == VisionMode.currency && hasRecentOcrVerification) {
      activeDetectionBox.value = targetDetection.normalizedBox;
      activeDetectionLabel.value =
          ObjectSpeechHelper.formatDisplayName(detectedLabel, mode);
    } else {
      activeDetectionBox.value = null;
      activeDetectionLabel.value = '';
    }

    final spatial = (mode == VisionMode.indoor || mode == VisionMode.outdoor)
        ? SpatialEstimator.of(targetDetection)
        : null;

    final displayName =
        ObjectSpeechHelper.formatDisplayName(detectedLabel, mode, spatial: spatial);
    currentStatusText.value = isDangerous
        ? '⚠️ $displayName'
        : (mode == VisionMode.currency
            ? 'Terdeteksi: $displayName (Validasi Angka)'
            : 'Terdeteksi: $displayName');

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
        priority: isDangerous && dangerDecision.urgent
            ? TtsPriority.danger
            : TtsPriority.normal,
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

  // ====================== Validasi Nominal Uang (OCR) ======================

  void _startCurrencyOcrTimer() {
    _currencyOcrTimer?.cancel();
    _currencyOcrTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!isPaused.value && mode == VisionMode.currency) {
        _runCurrencyOcrVerification();
      }
    });
  }

  /// Memverifikasi angka nominal uang kertas Rupiah menggunakan Google ML Kit OCR on-device.
  Future<void> _runCurrencyOcrVerification({bool isUrgent = false}) async {
    if (_isOcrBusy || _currencyOcr == null || mode != VisionMode.currency || isPaused.value) {
      return;
    }

    final now = DateTime.now();
    if (!isUrgent && now.difference(_lastOcrScanTime).inMilliseconds < 600) {
      return;
    }
    _lastOcrScanTime = now;
    _isOcrBusy = true;

    try {
      final Uint8List? bytes = await yoloController.capturePhoto(withOverlays: false);
      if (bytes != null && bytes.isNotEmpty) {
        final String? recognizedNominal = await _currencyOcr?.recognizeRupiah(bytes);
        if (recognizedNominal != null) {
          _consecutiveEmptyOcrCount = 0;
          _lastOcrVerifiedNominal = recognizedNominal;
          _lastOcrVerifiedTime = DateTime.now();
          _announceVerifiedRupiah(recognizedNominal, isUrgent: isUrgent);
        } else {
          _consecutiveEmptyOcrCount++;
          // Bila uang sudah dijauhkan dari pandangan kamera selama > 2.5 detik
          if (_consecutiveEmptyOcrCount >= 4) {
            if (_lastOcrVerifiedNominal != null) {
              _lastOcrVerifiedNominal = null;
              _lastAnnouncedLabel = '';
              currentStatusText.value = 'Arahkan uang ke kamera...';
            }
          }
          if (isUrgent) {
            ttsService.speak(
              'Angka nominal belum terbaca jelas. Pastikan angka uang menghadap kamera.',
            );
          }
        }
      }
    } catch (_) {
      // Abaikan bila kamera sedang pergantian frame
    } finally {
      _isOcrBusy = false;
    }
  }

  void _announceVerifiedRupiah(String nominal, {bool isUrgent = false}) {
    lastDetectedObject.value = nominal;
    final displayName = ObjectSpeechHelper.formatDisplayName(nominal, mode);
    currentStatusText.value = 'Terdeteksi: $displayName (Validasi Angka)';

    final speechText = ObjectSpeechHelper.formatForTts(nominal, mode);
    final now = DateTime.now();
    final bool changed = nominal != _lastAnnouncedLabel;
    final bool cooldownPassed =
        now.difference(_lastAnnounceTime).inMilliseconds >= 2500;

    if (isUrgent || changed || cooldownPassed) {
      _lastAnnouncedLabel = nominal;
      _lastAnnounceTime = now;
      ttsService.speak(speechText);
      HapticFeedback.mediumImpact();
    }
  }

  // ====================== Navigasi (Mode Jalan) ======================

  /// Inisialisasi navigasi: izin lokasi + stream GPS & kompas + ticker.
  Future<void> _setupNavigation() async {
    // 1. Hubungkan kompas secepatnya agar arah hadap langsung tersedia
    _compassSub = compassService.headingStream().listen(
      (heading) {
        userHeading.value = heading;
      },
      onError: (_) {},
    );

    // 2. Timer ticker panduan navigasi
    _navTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final pos = _lastNavPosition;
      if (pos != null) _feedNavigation(pos);
    });

    // 3. Pastikan izin lokasi aktif
    final granted = await locationService.ensurePermission();
    locationAvailable.value = granted;
    if (!granted) {
      navStatus.value = 'Lokasi tidak tersedia';
      ttsService.speak(
          'Peringatan: izin lokasi belum aktif. Peta navigasi tidak dapat dipakai.');
      return;
    }

    // 4. Ambil posisi terakhir dari cache sistem (instan!)
    final cachedPos = await locationService.lastKnownPosition();
    if (cachedPos != null && userPosition.value == null) {
      userPosition.value = cachedPos;
      _fetchAddress(cachedPos);
    }

    // 5. Hubungkan stream posisi aktif
    _positionSub = locationService.positionStream().listen(
      (position) {
        userPosition.value = position;
        _feedNavigation(position);
        if (currentAddress.value.isEmpty || _shouldRefreshAddress(position)) {
          _fetchAddress(position);
        }

        // Jika saat navigasi rute aktif koordinat baru terkunci, umumkan ke pengguna
        if (!_coordinatesAnnounced && mode == VisionMode.outdoor && destinationPoint.value != null) {
          _coordinatesAnnounced = true;
          final lat = position.lat.toStringAsFixed(4);
          final lng = position.lng.toStringAsFixed(4);
          final h = compassService.lastHeading ??
              (userHeading.value > 0 ? userHeading.value : null);
          final headingStr = (h != null)
              ? ', menghadap ke arah ${CompassService.headingToCardinalDirection(h)}'
              : '';
          ttsService.speak(
            'Titik koordinat terkunci: latitude $lat, longitude $lng$headingStr.',
          );
        }
      },
      onError: (_) {},
    );

    // 6. Jika cache kosong, minta posisi saat ini di background
    if (userPosition.value == null) {
      locationService.currentPosition().then((pos) {
        if (pos != null && userPosition.value == null) {
          userPosition.value = pos;
          _fetchAddress(pos);
        }
      });
    }
  }

  bool _shouldRefreshAddress(GeoPoint current) {
    if (_lastGeocodedPosition == null) return true;
    return haversineMeters(_lastGeocodedPosition!, current) > 40.0;
  }

  Future<void> _fetchAddress(GeoPoint position) async {
    if (_isGeocoding) return;
    _isGeocoding = true;
    _lastGeocodedPosition = position;
    try {
      final addr = await placesService.reverseGeocode(position);
      if (addr != null && addr.isNotEmpty) {
        currentAddress.value = addr;
      }
    } catch (_) {
    } finally {
      _isGeocoding = false;
    }
  }

  /// Masukkan posisi ke mesin panduan (dipanggil saat GPS update + tiap detik).
  void _feedNavigation(GeoPoint position) {
    _lastNavPosition = position;
    final guider = _navGuider;
    if (guider == null) return;

    final tick = guider.tick(position, DateTime.now());
    if (tick.arrived) {
      if (!_arrivedSpoken) {
        _arrivedSpoken = true;
        navStatus.value = 'Anda telah tiba di tujuan';
        routePolyline.value = [];
        destinationPoint.value = null;
        if (mode == VisionMode.outdoor) {
          yoloController.setShowOverlays(false);
        }
        final speech = tick.speech ?? 'Anda telah tiba di tujuan';
        if (mode == VisionMode.outdoor) {
          ttsService.speak(speech, priority: TtsPriority.navigation);
        }
      }
      return;
    }

    _arrivedSpoken = false;
    final speech = tick.speech;
    if (speech != null && speech.isNotEmpty && mode == VisionMode.outdoor) {
      // Arahan navigasi diberi prioritas agar tidak tenggelam oleh pengumuman
      // rintangan kamera, tetapi tetap mengalah pada bahaya yang lebih dekat.
      ttsService.speak(speech, priority: TtsPriority.navigation);
    }

    // Banner status disegarkan jarang agar tidak flicker.
    if (tick.remainingMeters >= 0 &&
        (navStatus.value.isEmpty || !navStatus.value.startsWith('Rute ke'))) {
      // Biarkan banner "Rute ke ..." stabil; detail belok dibacakan TTS.
    }
  }

  /// Saat model kamera siap & mode jalan: sapa & buka mic untuk tujuan secara responsif.
  Future<void> _promptDestination() async {
    if (_navPrompted || _navBusy || !isOutdoor.value) return;
    _navPrompted = true;
    navStatus.value = 'Mode jalan aktif...';

    // Panaskan mesin STT lebih awal agar izin mikrofon siap
    unawaited(_ensureSpeechReady());

    // Ambil cache posisi terakhir secara instan bila tersedia
    final cached = await locationService.lastKnownPosition();
    if (cached != null && userPosition.value == null) {
      userPosition.value = cached;
      _fetchAddress(cached);
    }

    if (!isOutdoor.value) return;

    final greeting = 'Mode jalan aktif. Silakan sebutkan tujuan Anda.';
    navStatus.value = 'Silakan sebutkan tujuan Anda...';

    // Sapa pengguna dan tunggu hingga selesai sebelum mic dibuka otomatis
    await ttsService.speakAndWait(greeting, priority: TtsPriority.navigation);

    // Buka mikrofon untuk mendengarkan tujuan user
    if (isOutdoor.value && !isListeningDestination.value && destinationPoint.value == null) {
      await startDestinationListening(announcePrompt: false);
    }
  }

  /// Siapkan mesin STT sekali saja, dengan percobaan ulang terbatas + pemilihan
  /// locale. Mengembalikan true bila siap dipakai.
  ///
  /// Init ulang penting karena `initialize` bisa gagal sesaat (mis. saat ponsel
  /// baru bangun / layanan pengenalan belum siap) — jangan menyerah permanen.
  Future<bool> _ensureSpeechReady() async {
    final speech = _speech ??= SpeechToText();
    if (_sttAvailable) return true;
    // Batasi percobaan agar tidak memanggil platform tanpa henti bila benar-benar
    // tidak ada mikrofon/layanan.
    if (_sttInitAttempts >= 4) return false;

    try {
      _sttAvailable = await speech.initialize(
        onError: (error) => _handleDestinationSttError(error.errorMsg),
        onStatus: (status) => _handleDestinationSttStatus(status),
      );
    } catch (_) {
      _sttAvailable = false;
    }
    _sttInitAttempts++;

    if (_sttAvailable) {
      _sttPermissionDenied = false;
      _sttLocaleId = await _pickSpeechLocale(speech) ?? 'id_ID';
    } else {
      // initialize() mengembalikan false saat izin mikrofon ditolak.
      try {
        _sttPermissionDenied = !(await speech.hasPermission);
      } catch (_) {}
    }
    return _sttAvailable;
  }

  /// Pilih locale Indonesia ('id_ID') sebagai default agar akurasi bahasa optimal.
  Future<String?> _pickSpeechLocale(SpeechToText speech) async {
    try {
      final locales = await speech.locales();
      for (final locale in locales) {
        final id = locale.localeId.replaceAll('-', '_').toLowerCase();
        if (id == 'id_id' || id == 'id') return locale.localeId;
      }
    } catch (_) {}
    return 'id_ID';
  }

  /// Mulai mendengarkan ucapan tujuan (dipicu otomatis & tombol mikrofon).
  Future<void> startDestinationListening({bool announcePrompt = false}) async {
    if (!isOutdoor.value || _navBusy) return;

    // Pemicu manual (tombol mikrofon) → reset putaran percobaan & izin.
    if (!announcePrompt) {
      _sttInitAttempts = 0;
      _sttAttempt = 0;
      _sttPermissionDenied = false;
    }

    // Sudah ada sesi dengar (termasuk sedang disiapkan/mengering) → toggle stop.
    if (isListeningDestination.value) {
      stopDestinationListening();
      return;
    }

    if (_sttStarting) return;

    if (!await _ensureSpeechReady()) {
      speechPhase = DestinationSpeechPhase.idle;
      isListeningDestination.value = false;
      if (_sttPermissionDenied) {
        navStatus.value = 'Izin mikrofon diperlukan';
        ttsService.speak(
            'Izin mikrofon belum diberikan. Ketuk layar lalu izinkan mikrofon.',
            priority: TtsPriority.navigation);
      } else {
        navStatus.value = 'Mikrofon tidak tersedia';
        ttsService.speak('Mikrofon tidak tersedia di perangkat ini.',
            priority: TtsPriority.navigation);
      }
      return;
    }

    await _runDestinationListen(attempt: 1, announcePrompt: announcePrompt);
  }

  /// Jalankan satu putaran sesi dengar ([attempt] mulai dari 1).
  Future<void> _runDestinationListen({
    required int attempt,
    required bool announcePrompt,
  }) async {
    if (!isOutdoor.value || destinationPoint.value != null) return;
    if (_sttStarting) return;

    _sttStarting = true;
    _sttAttempt = attempt;
    _listenDrainTimer?.cancel();
    _listenDrainTimer = null;
    _lastRecognizedWords = '';
    _finalHandled = false;

    try {
      // 1. Matikan audio TTS segera agar suara speaker tidak masuk ke mikrofon.
      await ttsService.stop();

      if (!await _ensureSpeechReady()) {
        speechPhase = DestinationSpeechPhase.idle;
        isListeningDestination.value = false;
        _continueOrFinishListen(attempt,
            errorMsg: _sttPermissionDenied
                ? 'error_permission'
                : 'error_recognition_unavailable');
        return;
      }
      final speech = _speech!;

      if (announcePrompt) {
        navStatus.value = 'Mempersiapkan mikrofon...';
        await ttsService.speakAndWait('Silakan sebutkan tujuan Anda.',
            priority: TtsPriority.navigation);
      }

      navStatus.value = attempt > 1
          ? 'Mendengarkan ulang ($attempt/${SttRetryPolicy.maxAutoRetries})...'
          : 'Mendengarkan tujuan Anda...';

      // 2. Beri jeda agar speaker HP benar-benar senyap sebelum mic merekam.
      await Future.delayed(const Duration(milliseconds: 250));
      if (!isOutdoor.value || destinationPoint.value != null) return;

      // Lepaskan sesi lama terlebih dahulu bila masih aktif
      if (speech.isListening) {
        try {
          await speech.cancel();
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 150));
      }

      // 3. Tahan SEMUA TTS selama mic aktif (tak ada gema ke STT). Sekaligus
      //    menghentikan TTS & melepas audio focus agar mic benar-benar mendengar.
      await ttsService.beginListeningSession();
      speechPhase = DestinationSpeechPhase.listening;
      HapticFeedback.heavyImpact();
      isListeningDestination.value = true;

      try {
        await speech.listen(
          onResult: _onDestinationSpeech,
          listenOptions: SpeechListenOptions(
            listenFor: const Duration(seconds: 8),
            pauseFor: const Duration(seconds: 4),
            localeId: _sttLocaleId ?? 'id_ID',
            listenMode: ListenMode.dictation,
            cancelOnError: true,
          ),
        );
      } catch (_) {
        speechPhase = DestinationSpeechPhase.error;
        isListeningDestination.value = false;
        ttsService.endListeningSession();
        _continueOrFinishListen(
          attempt,
          errorMsg: 'error_busy',
          giveUpMessage:
              'Gagal membuka mikrofon. Ketuk tombol mikrofon untuk mencoba lagi.',
        );
      }
    } finally {
      _sttStarting = false;
    }
  }

  void stopDestinationListening() {
    _finalHandled = true;
    _listenDrainTimer?.cancel();
    _listenDrainTimer = null;
    speechPhase = DestinationSpeechPhase.idle;
    try {
      _speech?.stop();
    } catch (_) {}
    ttsService.endListeningSession();
    isListeningDestination.value = false;
    if (destinationPoint.value == null && isOutdoor.value) {
      navStatus.value = 'Ketuk mikrofon untuk sebutkan tujuan';
    }
  }

  /// Selesaikan sesi yang berakhir tanpa hasil akhir (timeout/jeda senyap).
  void _finishListenAttemptWithoutResult() {
    if (_finalHandled) return;
    if (speechPhase != DestinationSpeechPhase.listening &&
        speechPhase != DestinationSpeechPhase.draining) {
      return;
    }

    // Jika platform mengirim done tanpa finalResult=true tetapi kata tujuan sudah sempat terdengar:
    if (_lastRecognizedWords.trim().isNotEmpty &&
        SpeechResultFilter.isUsable(_lastRecognizedWords, minChars: 2)) {
      _processDestinationResult(_lastRecognizedWords, _sttAttempt);
      return;
    }

    final attempt = _sttAttempt;
    speechPhase = DestinationSpeechPhase.idle;
    ttsService.endListeningSession();
    isListeningDestination.value = false;
    if (destinationPoint.value != null || !isOutdoor.value) return;
    _continueOrFinishListen(attempt);
  }

  /// Putuskan: otomatis dengar ulang sampai [SttRetryPolicy.maxAutoRetries],
  /// atau kembali ke pengguna bila sudah habis / error tidak bisa diulang.
  void _continueOrFinishListen(
    int failedAttempt, {
    String? errorMsg,
    String? retryHint,
    String? giveUpMessage,
  }) {
    if (destinationPoint.value != null || !isOutdoor.value) return;

    final retryable = errorMsg == null || SttRetryPolicy.shouldRetry(errorMsg);
    if (retryable && SttRetryPolicy.canRetry(failedAttempt)) {
      final next = failedAttempt + 1;
      navStatus.value = 'Mendengarkan ulang ($next/${SttRetryPolicy.maxAutoRetries})';
      ttsService.speak(retryHint ?? SttRetryPolicy.retryAnnouncement(next),
          priority: TtsPriority.navigation);
      Future<void>.delayed(SttRetryPolicy.retryDelay, () {
        if (destinationPoint.value != null || !isOutdoor.value) return;
        if (isListeningDestination.value) return;
        unawaited(
            _runDestinationListen(attempt: next, announcePrompt: false));
      });
      return;
    }

    navStatus.value = 'Ketuk mikrofon untuk sebutkan tujuan';
    final fallback = (errorMsg != null && errorMsg.contains('error_permission'))
        ? 'Izin mikrofon belum diberikan. Ketuk layar lalu izinkan mikrofon.'
        : 'Tujuan tidak terdengar. Ketuk tombol mikrofon untuk mencoba lagi.';
    ttsService.speak(giveUpMessage ?? fallback, priority: TtsPriority.navigation);
  }

  void _handleDestinationSttError(String errorMsg) {
    if (errorMsg.contains('error_permission')) _sttPermissionDenied = true;
    if (_finalHandled) return;

    // Status `done` bisa tiba lebih dulu; bila sesi sudah diputuskan, abaikan.
    if (speechPhase != DestinationSpeechPhase.listening &&
        speechPhase != DestinationSpeechPhase.draining &&
        speechPhase != DestinationSpeechPhase.error) {
      return;
    }

    final attempt = _sttAttempt;
    _listenDrainTimer?.cancel();
    _listenDrainTimer = null;
    speechPhase = DestinationSpeechPhase.idle;
    ttsService.endListeningSession();
    isListeningDestination.value = false;
    if (destinationPoint.value != null || !isOutdoor.value) return;
    _continueOrFinishListen(attempt, errorMsg: errorMsg);
  }

  void _handleDestinationSttStatus(String status) {
    if (status != 'notListening' && status != 'done') return;
    if (speechPhase != DestinationSpeechPhase.listening) return;

    // Tandai sesi sedang mengering; hasil akhir mungkin masih menyusul.
    speechPhase = DestinationSpeechPhase.draining;
    _listenDrainTimer?.cancel();
    _listenDrainTimer =
        Timer(_drainGrace, _finishListenAttemptWithoutResult);
  }

  void _onDestinationSpeech(SpeechRecognitionResult result) {
    if (!isOutdoor.value || _finalHandled) return;

    final active = speechPhase == DestinationSpeechPhase.listening ||
        speechPhase == DestinationSpeechPhase.draining;
    if (!active) return;

    if (result.recognizedWords.isNotEmpty) {
      _lastRecognizedWords = result.recognizedWords;
      navStatus.value = 'Mendengar: "${result.recognizedWords}"';
    }

    if (!result.finalResult) return;

    _processDestinationResult(result.recognizedWords, _sttAttempt);
  }

  void _processDestinationResult(String rawText, int attempt) {
    if (_finalHandled) return;
    _finalHandled = true;

    _listenDrainTimer?.cancel();
    _listenDrainTimer = null;
    speechPhase = DestinationSpeechPhase.idle;
    ttsService.endListeningSession();
    isListeningDestination.value = false;

    if (destinationPoint.value != null || !isOutdoor.value) return;

    final raw = rawText.trim();

    // Bukan ucapan manusia yang valid → kemungkinan gema TTS / noise.
    if (!SpeechResultFilter.isUsable(raw, minChars: 2)) {
      _continueOrFinishListen(attempt,
          retryHint: 'Belum terdengar, tolong ulangi tujuan Anda.');
      return;
    }

    final query = extractDestinationQuery(raw);
    if (query.isEmpty) {
      _continueOrFinishListen(
        attempt,
        retryHint:
            'Apa tujuan Anda? Coba sebutkan nama tempat, misalnya warung, stasiun, atau masjid.',
      );
      return;
    }

    speechPhase = DestinationSpeechPhase.processing;
    _routeToQuery(query);
  }

  /// Terjemahkan kata tujuan → tempat → rute → panduan.
  Future<void> _routeToQuery(String query) async {
    if (_navBusy) return;
    _navBusy = true;
    try {
       final origin = userPosition.value;
       if (origin == null) {
         navStatus.value = 'Menunggu sinyal GPS...';
         ttsService.speak('Menunggu sinyal GPS untuk menentukan posisi Anda.');
         return;
       }

       // Sembunyikan peta/rute lama sebelum pencarian tujuan baru.
       destinationPoint.value = null;
       routePolyline.value = [];
       navStatus.value = 'Mencari $query...';
      ttsService.speak('Mencari $query di sekitar Anda.');

      final result = await placesService.searchBest(query: query, center: origin);
      final place = result.place;
      if (place == null) {
        navStatus.value = 'Tempat tidak ditemukan';
        ttsService.speak(
            "Tidak ditemukan '$query' di sekitar. Coba sebutkan nama atau jenis tempat lain.");
        return;
      }

      final placeDist = place.distanceMeters ?? haversineMeters(origin, place.point);
      final placeName = _cleanPlaceName(place.name);
      navStatus.value = 'Menuju $placeName';
      // Bila tempat terdekat masih jauh (di luar radius nyaman jalan kaki),
      // beri tahu pengguna jarak sebenarnya sebelum membuat rute.
      final farNote = result.beyondLocal
          ? ' Tempat terdekat cukup jauh, sekitar ${formatDistanceMeters(placeDist)} dari posisi Anda.'
          : '';
      ttsService.speak(
          'Menuju $placeName, ${formatDistanceMeters(placeDist)}.$farNote Membuat rute.',
          priority: TtsPriority.navigation);
      destinationPoint.value = place.point;
      yoloController.setShowOverlays(true);

      final route = await directionsService.getWalkingRoute(
        origin: origin,
        destination: place.point,
      );

      _navGuider = NavigationGuider(route);
      _arrivedSpoken = false;
      // Rute siap: perkecil peta agar kamera pendamping rintangan aktif.
      mapExpanded.value = false;

      final overview = route.overviewPoints.isEmpty
          ? [route.steps.first.start, route.steps.last.end]
          : route.overviewPoints;
      routePolyline.value = <GeoPoint>[origin, ...overview];
      navStatus.value =
          'Rute ke $placeName, ${formatDistanceMeters(route.totalMeters)}';

      // Arahan awal yang jelas dari peta: arah mata angin + langkah pertama.
      final first =
          route.steps.isNotEmpty ? route.steps.first.instruction : 'ikuti rute';
      final firstTarget = route.steps.isNotEmpty
          ? route.steps.first.end
          : place.point;
      final bearing = bearingDegrees(origin, firstTarget);
      final cardinal = CompassService.headingToCardinalDirection(bearing);
      ttsService.speak(
          'Rute ke $placeName sejauh ${formatDistanceMeters(route.totalMeters)}. '
          'Arahkan langkah ke arah $cardinal, lalu ${_capitalize(first)}.',
          priority: TtsPriority.navigation);
    } on PlacesException catch (e) {
      navStatus.value = e.message;
      ttsService.speak(e.message);
    } on DirectionsException catch (e) {
      navStatus.value = e.message;
      ttsService.speak(e.message);
    } catch (e) {
      debugPrint('[DetectorController] _routeToQuery error: $e');
      navStatus.value = 'Gagal membuat rute';
      ttsService.speak(
          'Terjadi kesalahan saat membuat rute. Pastikan internet terhubung.');
    } finally {
      _navBusy = false;
      if (speechPhase == DestinationSpeechPhase.processing) {
        speechPhase = DestinationSpeechPhase.idle;
      }
    }
  }

  /// Rapikan nama tempat agar TTS tidak mengulang "warung, Warung".
  String _cleanPlaceName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'tujuan';
    return trimmed;
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  void toggleMapExpanded() {
    mapExpanded.value = !mapExpanded.value;
  }

  void handleScreenTap() {
    HapticFeedback.mediumImpact();
    if (mode == VisionMode.currency) {
      if (_lastOcrVerifiedNominal != null &&
          DateTime.now().difference(_lastOcrVerifiedTime).inMilliseconds < 5000) {
        final speech =
            ObjectSpeechHelper.formatForTts(_lastOcrVerifiedNominal!, mode);
        ttsService.speak(speech);
      }
      _runCurrencyOcrVerification(isUrgent: true);
      return;
    }

    if (mode == VisionMode.outdoor) {
      final outdoorPos = userPosition.value;
      final h = compassService.lastHeading ??
          (userHeading.value > 0 ? userHeading.value : null);

      String coordStr;
      if (outdoorPos != null) {
        final lat = outdoorPos.lat.toStringAsFixed(4);
        final lng = outdoorPos.lng.toStringAsFixed(4);
        coordStr = 'Titik koordinat Anda: latitude $lat, longitude $lng';
        if (currentAddress.value.isNotEmpty) {
          coordStr += ', di ${currentAddress.value}';
        }
      } else {
        coordStr = 'Titik koordinat sedang disinkronkan oleh GPS';
      }

      String headingStr;
      if (h != null) {
        headingStr = 'Anda sedang menghadap ke arah ${CompassService.headingToCardinalDirection(h)}';
      } else {
        headingStr = 'Arah hadap sedang disesuaikan';
      }

      if (destinationPoint.value == null) {
        final text = '$coordStr. $headingStr. Silakan sebutkan tujuan Anda.';
        ttsService.speakAndWait(text, priority: TtsPriority.navigation).then((_) {
          if (isOutdoor.value && destinationPoint.value == null && !isListeningDestination.value) {
            startDestinationListening(announcePrompt: false);
          }
        });
        return;
      } else {
        final navText = navStatus.value;
        String obstacleInfo = '';
        if (lastDetectedObject.value.isNotEmpty) {
          obstacleInfo = ' Di depan Anda ada ${ObjectSpeechHelper.formatDisplayName(lastDetectedObject.value, mode)}.';
        }
        ttsService.speak(
          '$coordStr. $headingStr.$obstacleInfo $navText.',
          priority: TtsPriority.navigation,
        );
        return;
      }
    }

    if (lastDetectedObject.value.isNotEmpty) {
      final speech =
          ObjectSpeechHelper.formatForTts(lastDetectedObject.value, mode);
      ttsService.speak(speech);
    } else {
      ttsService.speak('Belum ada objek terdeteksi di depan Anda.');
    }
  }

  void togglePause() {
    isPaused.value = !isPaused.value;
    if (isPaused.value) {
      _currencyOcrTimer?.cancel();
      yoloController.pause();
      ttsService.speak('Deteksi dijeda');
    } else {
      yoloController.resume();
      if (mode == VisionMode.currency) {
        yoloController.setShowOverlays(false);
        _startCurrencyOcrTimer();
      }
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
    _currencyOcrTimer?.cancel();
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
      case VisionMode.itemSearch:
        taskType = TaskType.findObject;
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
    Get.toNamed(Routes.VISUAL_HELP, arguments: context)?.then((_) {
      resumeDetection();
    });
  }

  // Status Hitung Mundur Darurat (SOS) dari Layar Deteksi Kamera
  final RxBool isSosCountdownActive = false.obs;
  final RxInt sosCountdownSeconds = 5.obs;
  Timer? _sosCountdownTimer;

  void triggerEmergencySOS() {
    if (isSosCountdownActive.value) return;

    isSosCountdownActive.value = true;
    sosCountdownSeconds.value = 5;
    HapticFeedback.heavyImpact();

    ttsService.speak(
      'Peringatan darurat aktif. Ketuk layar untuk membatalkan.',
      priority: TtsPriority.sos,
    );

    _sosCountdownTimer?.cancel();
    _sosCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      sosCountdownSeconds.value--;
      HapticFeedback.heavyImpact();

      if (sosCountdownSeconds.value > 0) {
        ttsService.speak('${sosCountdownSeconds.value}',
            priority: TtsPriority.sos);
      } else {
        timer.cancel();
        _dispatchSosCall();
      }
    });
  }

  void cancelEmergencySOS() {
    if (!isSosCountdownActive.value) return;

    _sosCountdownTimer?.cancel();
    isSosCountdownActive.value = false;
    HapticFeedback.mediumImpact();
    ttsService.speak('Panggilan darurat dibatalkan.', priority: TtsPriority.sos);
  }

  void _dispatchSosCall() async {
    isSosCountdownActive.value = false;
    HapticFeedback.heavyImpact();
    ttsService.speak('Menghubungkan panggilan darurat sekarang...',
        priority: TtsPriority.sos);

    String? locationNotes;
    try {
      final geo = userPosition.value ?? await locationService.currentPosition();
      if (geo != null) {
        locationNotes = 'Lokasi: https://maps.google.com/?q=${geo.lat},${geo.lng}';
      }
    } catch (_) {}

    Get.toNamed(
      Routes.VISUAL_HELP,
      arguments: TaskContext(
        taskType: TaskType.generalHelp,
        targetName: '🚨 PANGGILAN DARURAT (SOS)',
        sourceScreen: 'emergency_sos',
        notes: locationNotes,
      ),
    )?.then((_) {
      resumeDetection();
    });
  }

  /// Memulihkan kembali sesi deteksi kamera dan audio setelah kembali dari bantuan visual
  void resumeDetection() {
    isPaused.value = false;
    yoloController.resume();
    if (mode == VisionMode.currency) {
      yoloController.setShowOverlays(false);
      _startCurrencyOcrTimer();
    }
    ttsService.speak('Kamera deteksi diaktifkan kembali');
  }

  @override
  void onClose() {
    _sosCountdownTimer?.cancel();
    _currencyOcrTimer?.cancel();
    _listenDrainTimer?.cancel();
    _listenDrainTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _compassSub?.cancel();
    _navTicker?.cancel();
    try {
      _speech?.cancel();
    } catch (_) {}
    stopDestinationListening();
    yoloController.dispose(); // Tutup stream zoom/lens/focus milik controller.
    ttsService.stop();
    vibrationService.stop();
    super.onClose();
  }
}
