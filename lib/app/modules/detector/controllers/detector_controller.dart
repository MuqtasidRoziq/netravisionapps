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

  SpeechToText? _speech;
  NavigationGuider? _navGuider;
  StreamSubscription<GeoPoint>? _positionSub;
  StreamSubscription<double>? _compassSub;
  Timer? _navTicker;
  GeoPoint? _lastNavPosition;
  bool _navPrompted = false;
  bool _arrivedSpoken = false;
  bool _sttAvailable = false;
  bool _navBusy = false;

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

  // Verifikasi Angka Nominal (On-Device Google ML Kit OCR)
  CurrencyOcrService? _currencyOcr;
  bool _isOcrBusy = false;
  DateTime _lastOcrScanTime = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastOcrVerifiedNominal;
  DateTime _lastOcrVerifiedTime = DateTime.fromMillisecondsSinceEpoch(0);

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

    if (mode == VisionMode.outdoor) {
      isOutdoor.value = true;
      _setupNavigation();
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
    yoloController.setThresholds(
      confidenceThreshold: modelConfig.confidenceThreshold,
      iouThreshold: modelConfig.iouThreshold,
      numItemsThreshold: _maxNumItems,
    );
    if (mode == VisionMode.currency) {
      currentStatusText.value = 'Arahkan uang ke kamera...';
    } else if (mode == VisionMode.itemSearch && targetItem.isNotEmpty) {
      currentStatusText.value = 'Mencari "$targetItem" di depan Anda...';
    } else {
      currentStatusText.value = 'Mencari objek di depan Anda...';
    }
    ttsService.speak(mode.announcement);
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
        .where((r) => ObjectSpeechHelper.shouldAnnounce(r.className, mode))
        .where((r) =>
            mode != VisionMode.currency ||
            DetectionFilter.isPlausibleMoneyBox(r.normalizedBox,
                label: r.className))
        .toList();

    // 1b. Khusus mode pencarian barang: hanya tampilkan yang cocok target.
    if (mode == VisionMode.itemSearch && targetItem.isNotEmpty) {
      final target = targetItem.toLowerCase();
      validDetections = validDetections.where((r) {
        final label = r.className.toLowerCase();
        // Cocokkan bila label mengandung kata kunci target atau sebaliknya
        return label.contains(target) ||
            target.split(' ').any((word) => word.length > 2 && label.contains(word));
      }).toList();
      // Jika tidak ada yang cocok, jangan umumkan apa pun
      if (validDetections.isEmpty) return;
    }

    if (validDetections.isEmpty) {
      if (mode == VisionMode.currency) {
        _emptyCurrencyFrames++;
        if (_emptyCurrencyFrames >= 4) {
          _lastAnnouncedLabel = '';
          _recentClassIndices.clear();
          _lastOcrVerifiedNominal = null;
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
      return;
    }

    final String detectedLabel =
        (mode == VisionMode.currency && hasRecentOcrVerification)
            ? _lastOcrVerifiedNominal!
            : targetDetection.className;
    lastDetectedObject.value = detectedLabel;

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

  // ====================== Validasi Nominal Uang (OCR) ======================

  /// Memverifikasi angka nominal uang kertas Rupiah menggunakan Google ML Kit OCR on-device.
  Future<void> _runCurrencyOcrVerification({bool isUrgent = false}) async {
    if (_isOcrBusy || _currencyOcr == null || mode != VisionMode.currency) return;

    final now = DateTime.now();
    if (!isUrgent && now.difference(_lastOcrScanTime).inMilliseconds < 1200) {
      return;
    }
    _lastOcrScanTime = now;
    _isOcrBusy = true;

    try {
      final Uint8List? bytes = await yoloController.capturePhoto(withOverlays: false);
      if (bytes != null && bytes.isNotEmpty) {
        final String? recognizedNominal = await _currencyOcr?.recognizeRupiah(bytes);
        if (recognizedNominal != null) {
          _lastOcrVerifiedNominal = recognizedNominal;
          _lastOcrVerifiedTime = DateTime.now();
          _announceVerifiedRupiah(recognizedNominal, isUrgent: isUrgent);
        } else if (isUrgent) {
          ttsService.speak(
            'Angka nominal belum terbaca jelas. Ratakan dan dekatkan uang ke kamera.',
            isUrgent: true,
          );
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
      ttsService.speak(speechText, isUrgent: true);
    }
  }

  // ====================== Navigasi (Mode Jalan) ======================

  /// Inisialisasi navigasi: izin lokasi + stream GPS & kompas + ticker.
  Future<void> _setupNavigation() async {
    final granted = await locationService.ensurePermission();
    locationAvailable.value = granted;
    if (!granted) {
      navStatus.value = 'Lokasi tidak tersedia';
      ttsService.speak(
          'Peringatan: izin lokasi belum aktif. Peta navigasi tidak dapat dipakai.');
      return;
    }

    userPosition.value = await locationService.currentPosition();

    _positionSub = locationService.positionStream().listen(
      (position) {
        userPosition.value = position;
        _feedNavigation(position);
      },
      onError: (_) {},
    );

    _compassSub = compassService.headingStream().listen(
      (heading) => userHeading.value = heading,
      onError: (_) {},
    );

    _navTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final pos = _lastNavPosition;
      if (pos != null) _feedNavigation(pos);
    });
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
        final speech = tick.speech ?? 'Anda telah tiba di tujuan';
        if (mode == VisionMode.outdoor) ttsService.speak(speech);
      }
      return;
    }

    _arrivedSpoken = false;
    final speech = tick.speech;
    if (speech != null && speech.isNotEmpty && mode == VisionMode.outdoor) {
      ttsService.speak(speech);
    }

    // Banner status disegarkan jarang agar tidak flicker.
    if (tick.remainingMeters >= 0 &&
        (navStatus.value.isEmpty || !navStatus.value.startsWith('Rute ke'))) {
      // Biarkan banner "Rute ke ..." stabil; detail belok dibacakan TTS.
    }
  }

  /// Saat model kamera siap & mode jalan: sapa + ajak bicara tujuan.
  void _promptDestination() {
    if (_navPrompted || _navBusy) return;
    _navPrompted = true;
    navStatus.value = 'Silakan ucapkan tujuan...';
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!isOutdoor.value) return;
      ttsService.speak('Mode jalan aktif. Silakan bicara, Anda mau ke mana?');
    });
    Future.delayed(const Duration(milliseconds: 3600), () {
      if (isOutdoor.value) startDestinationListening();
    });
  }

  /// Mulai mendengarkan ucapan tujuan (dipicu otomatis & tombol mikrofon).
  Future<void> startDestinationListening() async {
    if (!isOutdoor.value || _navBusy) return;

    final speech = _speech ??= SpeechToText();
    if (!_sttAvailable) {
      _sttAvailable = await speech.initialize();
      if (!_sttAvailable) {
        navStatus.value = 'Mikrofon tidak tersedia';
        ttsService.speak('Mikrofon tidak tersedia di perangkat ini.');
        return;
      }
    }
    if (isListeningDestination.value) return;

    HapticFeedback.mediumImpact();
    isListeningDestination.value = true;
    navStatus.value = 'Mendengarkan tujuan...';
    ttsService.speak('Silakan ucapkan tujuan Anda.', isUrgent: true);

    await speech.listen(
      onResult: _onDestinationSpeech,
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 2),
        localeId: 'id_ID',
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
    );
  }

  void stopDestinationListening() {
    _speech?.stop();
    isListeningDestination.value = false;
  }

  void _onDestinationSpeech(SpeechRecognitionResult result) {
    if (!result.finalResult || !isOutdoor.value) return;
    isListeningDestination.value = false;
    final raw = result.recognizedWords.trim();
    if (raw.isEmpty) {
      navStatus.value = 'Tidak ada suara terdeteksi';
      ttsService.speak(
          'Tidak ada suara terdeteksi. Ketuk tombol mikrofon untuk mencoba lagi.');
      return;
    }
    final query = extractDestinationQuery(raw);
    if (query.isEmpty) {
      ttsService.speak(
          'Apa tujuan Anda? Coba sebutkan nama atau jenis tempat, misalnya warung.');
      return;
    }
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

      navStatus.value = 'Mencari $query...';
      ttsService.speak('Mencari $query di sekitar Anda.');

      final place = await placesService.searchBest(query: query, center: origin);
      if (place == null) {
        navStatus.value = 'Tempat tidak ditemukan';
        ttsService.speak(
            "Tidak ditemukan '$query' di sekitar. Coba sebutkan nama atau jenis tempat lain.");
        return;
      }

      final placeDist = place.distanceMeters ?? haversineMeters(origin, place.point);
      final placeName = _cleanPlaceName(place.name);
      navStatus.value = 'Menuju $placeName';
      ttsService.speak(
          'Menuju $placeName, ${formatDistanceMeters(placeDist)}. Membuat rute.');
      destinationPoint.value = place.point;

      final route = await directionsService.getWalkingRoute(
        origin: origin,
        destination: place.point,
      );

      _navGuider = NavigationGuider(route);
      _arrivedSpoken = false;

      final overview = route.overviewPoints.isEmpty
          ? [route.steps.first.start, route.steps.last.end]
          : route.overviewPoints;
      routePolyline.value = <GeoPoint>[origin, ...overview];
      navStatus.value =
          'Rute ke $placeName, ${formatDistanceMeters(route.totalMeters)}';

      final first =
          route.steps.isNotEmpty ? route.steps.first.instruction : 'ikuti rute';
      ttsService.speak(
          'Rute ditemukan, ${formatDistanceMeters(route.totalMeters)} menuju '
          '$placeName. ${_capitalize(first)}.');
    } on PlacesException catch (e) {
      navStatus.value = e.message;
      ttsService.speak(e.message);
    } on DirectionsException catch (e) {
      navStatus.value = e.message;
      ttsService.speak(e.message);
    } catch (_) {
      navStatus.value = 'Gagal membuat rute';
      ttsService.speak(
          'Terjadi kesalahan saat membuat rute. Pastikan internet terhubung dan API Google aktif.');
    } finally {
      _navBusy = false;
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
        ttsService.speak(speech, isUrgent: true);
      }
      _runCurrencyOcrVerification(isUrgent: true);
      return;
    }

    if (lastDetectedObject.value.isNotEmpty) {
      final speech =
          ObjectSpeechHelper.formatForTts(lastDetectedObject.value, mode);
      ttsService.speak('Objek di depan: $speech', isUrgent: true);
    } else {
      ttsService.speak('Belum ada objek terdeteksi di depan Anda.',
          isUrgent: true);
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

  /// Memulihkan kembali sesi deteksi kamera dan audio setelah kembali dari bantuan visual
  void resumeDetection() {
    isPaused.value = false;
    yoloController.resume();
    ttsService.speak('Kamera deteksi diaktifkan kembali');
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _compassSub?.cancel();
    _navTicker?.cancel();
    stopDestinationListening();
    yoloController.dispose(); // Tutup stream zoom/lens/focus milik controller.
    ttsService.stop();
    vibrationService.stop();
    super.onClose();
  }
}
