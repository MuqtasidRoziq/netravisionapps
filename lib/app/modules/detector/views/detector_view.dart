import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/vision_mode.dart';
import '../../../widgets/reusable_camera_view.dart';
import '../controllers/detector_controller.dart';

class DetectorView extends GetView<DetectorController> {
  const DetectorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return ReusableCameraView(
        title: controller.mode.title,
        statusText: controller.currentStatusText.value,
        subtitle: 'Ketuk layar kapan saja untuk cek rintangan',
        isPaused: controller.isPaused.value,
        onTapScreen: () => controller.handleScreenTap(),
        onTogglePause: () => controller.togglePause(),
        onBack: () => Get.back(),
      );
    });
  }
}
