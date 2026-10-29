import 'dart:async';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../../../data/models/navigation_models.dart';
import '../../../services/location_service.dart';
import '../../../services/nearby_places_service.dart';
import '../../../services/pedestrian_routing_service.dart';
import '../../../services/tts_service.dart';
import '../../../services/vibration_service.dart';

enum OutdoorState {
  idle,
  searching,
  placesFound,
  routeCalculating,
  navigating,
  arrived,
}

class OutdoorNavigationController extends GetxController {
  final TtsService _ttsService = Get.find<TtsService>();
  final VibrationService _vibrationService = Get.find<VibrationService>();
  final LocationService locationService = Get.find<LocationService>();
  final NearbyPlacesService _placesService = Get.find<NearbyPlacesService>();
  final PedestrianRoutingService _routingService = Get.find<PedestrianRoutingService>();

  final Rx<OutdoorState> state = OutdoorState.idle.obs;
  final RxList<NearbyPlaceModel> nearbyPlaces = <NearbyPlaceModel>[].obs;
  final Rx<NearbyPlaceModel?> selectedPlace = Rx<NearbyPlaceModel?>(null);
  final Rx<NavigationRoute?> activeRoute = Rx<NavigationRoute?>(null);

  final RxInt currentStepIndex = 0.0.toInt().obs;
  final RxDouble remainingDistanceToStep = 0.0.obs;
  final RxDouble remainingTotalDistance = 0.0.obs;
  final RxString currentInstruction = ''.obs;

  // Mode Layar Gelap (Curtain Screen) untuk hemat baterai & privasi
  final RxBool isCurtainScreen = false.obs;

  // Mode Pelindung Kamera (Vision Guard) on-demand
  final RxBool isVisionGuardActive = false.obs;

  StreamSubscription<Position?>? _navPositionSub;
  double? _lastSpokenDistance;
  DateTime _lastOffRouteCheck = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void onInit() {
    super.onInit();
    locationService.startTracking();
  }

  @override
  void onReady() {
    super.onReady();
    _announceWelcome();
  }

  @override
  void onClose() {
    _navPositionSub?.cancel();
    locationService.stopTracking();
    super.onClose();
  }

  void _announceWelcome() {
    _ttsService.speak(
      'Mode Outdoor dan Navigasi Peta aktif. '
      'Pilih kategori tempat terdekat, atau ketuk tombol Di Mana Saya untuk mengetahui lokasi Anda.',
    );
  }

  /// Fitur "Di mana saya sekarang?"
  Future<void> announceWhereAmI() async {
    HapticFeedback.mediumImpact();
    final pos = locationService.currentPosition.value;
    final heading = locationService.currentHeading.value;
    final cardinal = locationService.headingToCardinal(heading);
    final address = locationService.currentAddress.value;

    if (pos == null) {
      _ttsService.speak('Menunggu sinyal GPS. Mohon pastikan Anda berada di luar ruangan.', isUrgent: true);
      return;
    }

    final accuracy = pos.accuracy.round();
    final message = 'Anda berada di $address. Menghadap ke arah $cardinal. Akurasi GPS $accuracy meter.';
    _ttsService.speak(message, isUrgent: true);
  }

  /// Mencari tempat terdekat berdasarkan kategori
  Future<void> searchNearbyCategory(PlaceCategory category) async {
    HapticFeedback.mediumImpact();
    state.value = OutdoorState.searching;
    _ttsService.speak('Mencari ${category.title} terdekat...');

    final results = await _placesService.findNearbyByCategory(category);
    nearbyPlaces.assignAll(results);

    if (results.isEmpty) {
      state.value = OutdoorState.idle;
      _ttsService.speak('Tidak ditemukan ${category.title} dalam radius satu kilometer.', isUrgent: true);
      return;
    }

    state.value = OutdoorState.placesFound;
    final closest = results.first;
    _ttsService.speak(
      'Ditemukan ${results.length} tempat. Yang terdekat adalah ${closest.name}, '
      'berjarak ${closest.formattedDistance}, di ${closest.clockDirection} Anda. '
      'Ketuk dua kali untuk memulai rute jalan kaki ke tempat ini.',
      isUrgent: true,
    );
  }

  /// Mencari tempat berdasarkan teks bebas
  Future<void> searchCustomText(String query) async {
    if (query.trim().isEmpty) return;
    HapticFeedback.mediumImpact();
    state.value = OutdoorState.searching;
    _ttsService.speak('Mencari $query di sekitar Anda...');

    final results = await _placesService.searchByText(query);
    nearbyPlaces.assignAll(results);

    if (results.isEmpty) {
      state.value = OutdoorState.idle;
      _ttsService.speak('Tidak dapat menemukan $query di sekitar lokasi Anda.', isUrgent: true);
      return;
    }

    state.value = OutdoorState.placesFound;
    final closest = results.first;
    _ttsService.speak(
      'Ditemukan ${results.length} tempat untuk $query. Terdekat adalah ${closest.name}, '
      'berjarak ${closest.formattedDistance}, di ${closest.clockDirection}.',
      isUrgent: true,
    );
  }

  /// Memulai rute navigasi jalan kaki ke tempat tujuan
  Future<void> startNavigation(NearbyPlaceModel destination) async {
    HapticFeedback.heavyImpact();
    selectedPlace.value = destination;
    state.value = OutdoorState.routeCalculating;
    _ttsService.speak('Menghitung rute pejalan kaki menuju ${destination.name}...');

    final route = await _routingService.calculateFootRoute(
      destination: destination.point,
      destinationName: destination.name,
    );

    if (route == null || route.steps.isEmpty) {
      state.value = OutdoorState.placesFound;
      _ttsService.speak('Gagal menghitung rute pejalan kaki. Coba pilih tempat lain.', isUrgent: true);
      return;
    }

    activeRoute.value = route;
    currentStepIndex.value = 0;
    remainingTotalDistance.value = route.totalDistanceMeters;

    final firstStep = route.steps.first;
    currentInstruction.value = firstStep.instruction;
    remainingDistanceToStep.value = firstStep.distanceMeters;

    state.value = OutdoorState.navigating;

    // Suara pengantar rute
    _ttsService.speak(
      'Rute siap. Total jarak ${route.formattedTotalDistance}, '
      'estimasi waktu ${route.formattedEstimatedTime}. '
      '${firstStep.instruction}',
      isUrgent: true,
    );

    _listenToNavigationProgress();
  }

  /// Memantau pergerakan pengguna sepanjang rute
  void _listenToNavigationProgress() {
    _navPositionSub?.cancel();
    _navPositionSub = locationService.currentPosition.listen((pos) {
      if (pos == null || state.value != OutdoorState.navigating) return;

      final route = activeRoute.value;
      if (route == null) return;

      final currentIdx = currentStepIndex.value;
      if (currentIdx >= route.steps.length) return;

      final currentStep = route.steps[currentIdx];
      final target = currentStep.targetPoint;

      // Hitung sisa jarak ke belokan ini
      final distToStep = locationService.calculateDistance(
        pos.latitude,
        pos.longitude,
        target.latitude,
        target.longitude,
      );
      remainingDistanceToStep.value = distToStep;

      // Hitung total sisa jarak ke tujuan akhir
      final dest = route.steps.last.targetPoint;
      final distToFinal = locationService.calculateDistance(
        pos.latitude,
        pos.longitude,
        dest.latitude,
        dest.longitude,
      );
      remainingTotalDistance.value = distToFinal;

      // Jika sudah dekat dengan belokan (< 10 meter)
      if (distToStep < 10.0) {
        _advanceToNextStep();
        return;
      }

      // Pengumuman kedekatan belokan (20 meter sebelum belok)
      if (distToStep <= 25.0 && distToStep > 15.0) {
        if (_lastSpokenDistance == null || (_lastSpokenDistance! - distToStep).abs() > 10.0) {
          _lastSpokenDistance = distToStep;
          _vibrationService.vibrateWarning();
          _ttsService.speak(
            '20 meter lagi, bersiap ${currentStep.clockFace}.',
            isUrgent: false,
          );
        }
      }

      // Cek apakah melenceng jauh dari jalur (> 40 meter)
      final now = DateTime.now();
      if (now.difference(_lastOffRouteCheck).inSeconds > 15) {
        _lastOffRouteCheck = now;
        _checkIfOffRoute(pos, route);
      }
    });
  }

  /// Maju ke langkah instruksi berikutnya
  void _advanceToNextStep() {
    final route = activeRoute.value;
    if (route == null) return;

    final nextIdx = currentStepIndex.value + 1;
    if (nextIdx >= route.steps.length) {
      // Sampai di tujuan!
      state.value = OutdoorState.arrived;
      currentInstruction.value = 'Anda sudah tiba di ${route.destinationName}.';
      _vibrationService.vibrateSuccess();
      _ttsService.speak(
        'Alhamdulillah, Anda sudah tiba di ${route.destinationName}. Navigasi selesai.',
        isUrgent: true,
      );
      return;
    }

    currentStepIndex.value = nextIdx;
    final nextStep = route.steps[nextIdx];
    currentInstruction.value = nextStep.instruction;
    remainingDistanceToStep.value = nextStep.distanceMeters;
    _lastSpokenDistance = null;

    _vibrationService.vibrateNotification();
    _ttsService.speak(nextStep.instruction, isUrgent: true);
  }

  /// Deteksi jika pengguna melenceng dari jalur
  void _checkIfOffRoute(Position pos, NavigationRoute route) {
    double minDistance = double.infinity;
    for (final pt in route.polylinePoints) {
      final d = locationService.calculateDistance(pos.latitude, pos.longitude, pt.latitude, pt.longitude);
      if (d < minDistance) minDistance = d;
    }

    if (minDistance > 45.0) {
      _vibrationService.vibrateDanger();
      _ttsService.speak(
        'Peringatan: Anda berada ${minDistance.round()} meter di luar rute. Menghitung ulang arah ke tujuan...',
        isUrgent: true,
      );
      if (selectedPlace.value != null) {
        startNavigation(selectedPlace.value!);
      }
    }
  }

  /// Mengulang instruksi navigasi saat ini (dipicu ketukan layar)
  void repeatCurrentInstruction() {
    HapticFeedback.lightImpact();
    if (state.value == OutdoorState.navigating) {
      final step = activeRoute.value?.steps[currentStepIndex.value];
      final dist = remainingDistanceToStep.value.round();
      final total = remainingTotalDistance.value.round();
      final msg = '$dist meter lagi: ${step?.instruction ?? currentInstruction.value}. Sisa total perjalanan $total meter.';
      _ttsService.speak(msg, isUrgent: true);
    } else {
      announceWhereAmI();
    }
  }

  /// Membatalkan navigasi rute aktif
  void cancelNavigation() {
    HapticFeedback.mediumImpact();
    _navPositionSub?.cancel();
    activeRoute.value = null;
    selectedPlace.value = null;
    state.value = OutdoorState.idle;
    _ttsService.speak('Navigasi rute dihentikan.', isUrgent: true);
  }

  /// Toggle Mode Layar Gelap (Curtain Screen)
  void toggleCurtainScreen() {
    HapticFeedback.heavyImpact();
    isCurtainScreen.value = !isCurtainScreen.value;
    if (isCurtainScreen.value) {
      _ttsService.speak('Mode Layar Gelap aktif. Layar dimatikan untuk menghemat baterai. Ketuk layar kapan saja untuk mendengarkan rute.');
    } else {
      _ttsService.speak('Mode Layar Gelap dimatikan. Layar kembali terlihat.');
    }
  }

  /// Toggle Mode Pelindung Kamera (Vision Guard)
  void toggleVisionGuard() {
    HapticFeedback.mediumImpact();
    isVisionGuardActive.value = !isVisionGuardActive.value;
    if (isVisionGuardActive.value) {
      _ttsService.speak('Pelindung Kamera aktif. Kamera siap memindai rintangan langkah di depan Anda.');
    } else {
      _ttsService.speak('Pelindung Kamera dinonaktifkan.');
    }
  }
}
