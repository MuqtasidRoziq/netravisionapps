import 'package:get/get.dart';

import '../controllers/item_search_controller.dart';

class ItemSearchBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ItemSearchController>(
      () => ItemSearchController(),
    );
  }
}

