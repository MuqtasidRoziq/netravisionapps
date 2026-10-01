import 'package:get/get.dart';
import '../controllers/detector_controller.dart';

class DetectorBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DetectorController>(
      () => DetectorController(),
    );
  }
}
