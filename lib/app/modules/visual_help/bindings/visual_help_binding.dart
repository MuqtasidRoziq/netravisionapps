import 'package:get/get.dart';
import '../controllers/visual_help_controller.dart';

class VisualHelpBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VisualHelpController>(() => VisualHelpController());
  }
}
