import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:netravisionapps/app/data/models/visual_help_models.dart';
import 'package:netravisionapps/app/modules/visual_help/controllers/visual_help_controller.dart';
import 'package:netravisionapps/app/services/contacts_service.dart';
import 'package:netravisionapps/app/services/fallback_service.dart';
import 'package:netravisionapps/app/services/livekit_call_service.dart';
import 'package:netravisionapps/app/services/tts_service.dart';
import 'package:netravisionapps/app/services/vibration_service.dart';
import 'package:netravisionapps/app/services/visual_help_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VisualHelpController Flow Tests', () {
    late VisualHelpController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();

      // Registrasi service dependencies
      await Get.putAsync(() => TtsService().init());
      await Get.putAsync(() async => VibrationService());
      await Get.putAsync(() => ContactsService().init());
      Get.put(FallbackService());
      await Get.putAsync(() => VisualHelpService().init());
      Get.put(LiveKitCallService());

      controller = Get.put(VisualHelpController());
    });

    tearDown(() {
      Get.reset();
    });

    test('Inisialisasi controller memiliki default TaskType.generalHelp dan penerima komunitas', () {
      expect(controller.selectedTaskType.value, TaskType.generalHelp);
      expect(controller.recipientTarget.value, RecipientTarget.communityVolunteers);
      expect(controller.remainingSeconds.value, 45);
      expect(controller.isViewingSnapshot.value, false);
    });

    test('Beralih peran antara pengguna dan relawan', () async {
      final vService = controller.visualHelpService;
      expect(vService.currentRole.value, 'user');

      await vService.switchRole('companion');
      expect(vService.currentRole.value, 'companion');

      await vService.switchRole('user');
      expect(vService.currentRole.value, 'user');
    });

    test('Memilih konteks tugas dan mengubah target pencarian', () {
      controller.selectedTaskType.value = TaskType.findObject;
      controller.targetNameController.text = 'Dompet Hitam';

      expect(controller.selectedTaskType.value, TaskType.findObject);
      expect(controller.targetNameController.text, 'Dompet Hitam');
    });

    test('Membuka dan menutup tampilan cuplikan sementara (snapshot)', () async {
      final callService = controller.liveKitCallService;
      expect(controller.isViewingSnapshot.value, false);

      await controller.takeSnapshot();
      expect(controller.isViewingSnapshot.value, true);
      expect(callService.currentSnapshot.value, isNotNull);

      controller.returnToLiveVideo();
      expect(controller.isViewingSnapshot.value, false);
      expect(callService.currentSnapshot.value, isNull);
    });
  });
}
