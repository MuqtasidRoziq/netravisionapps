import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:netravisionapps/app/modules/home/controllers/home_controller.dart';
import 'package:netravisionapps/app/services/tts_service.dart';

void main() {
  group('Emergency SOS Grace Period & Auto-Dispatch Tests', () {
    late HomeController homeController;

    setUp(() {
      Get.testMode = true;
      Get.put<TtsService>(TtsService());
      homeController = HomeController();
    });

    tearDown(() {
      Get.reset();
    });

    test('Pemicuan triggerEmergencySOS mengaktifkan countdown 3 detik', () {
      expect(homeController.isSosCountdownActive.value, false);
      expect(homeController.sosCountdownSeconds.value, 3);

      homeController.triggerEmergencySOS();

      expect(homeController.isSosCountdownActive.value, true);
      expect(homeController.sosCountdownSeconds.value, 3);
    });

    test('Ketukan pengguna membatalkan panggilan darurat sebelum waktu habis', () {
      homeController.triggerEmergencySOS();
      expect(homeController.isSosCountdownActive.value, true);

      homeController.cancelEmergencySOS();
      expect(homeController.isSosCountdownActive.value, false);
    });
  });
}
