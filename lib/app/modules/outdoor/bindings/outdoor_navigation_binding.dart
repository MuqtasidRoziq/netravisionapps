import 'package:get/get.dart';
import '../../../services/location_service.dart';
import '../../../services/nearby_places_service.dart';
import '../../../services/pedestrian_routing_service.dart';
import '../controllers/outdoor_navigation_controller.dart';

class OutdoorNavigationBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<LocationService>()) {
      Get.put(LocationService());
    }
    if (!Get.isRegistered<NearbyPlacesService>()) {
      Get.put(NearbyPlacesService());
    }
    if (!Get.isRegistered<PedestrianRoutingService>()) {
      Get.put(PedestrianRoutingService());
    }
    Get.lazyPut<OutdoorNavigationController>(() => OutdoorNavigationController());
  }
}
