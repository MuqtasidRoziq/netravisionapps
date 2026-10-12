import 'package:get/get.dart';

import '../modules/detector/bindings/detector_binding.dart';
import '../modules/detector/views/detector_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/item_search/bindings/item_search_binding.dart';
import '../modules/item_search/views/item_search_view.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';

import '../modules/visual_help/bindings/visual_help_binding.dart';
import '../modules/visual_help/views/visual_help_call_view.dart';
import '../modules/visual_help/views/visual_help_home_view.dart';
import '../modules/visual_help/views/visual_help_waiting_view.dart';
import '../modules/visual_help/views/trusted_contacts_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.SPLASH;

  static final routes = [
    GetPage(
      name: _Paths.SPLASH,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: _Paths.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.DETECTOR,
      page: () => const DetectorView(),
      binding: DetectorBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: _Paths.ITEM_SEARCH,
      page: () => const ItemSearchView(),
      binding: ItemSearchBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: _Paths.VISUAL_HELP,
      page: () => const VisualHelpHomeView(),
      binding: VisualHelpBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: _Paths.VISUAL_HELP_WAITING,
      page: () => const VisualHelpWaitingView(),
      binding: VisualHelpBinding(),
    ),
    GetPage(
      name: _Paths.VISUAL_HELP_CALL,
      page: () => const VisualHelpCallView(),
      binding: VisualHelpBinding(),
    ),
    GetPage(
      name: _Paths.TRUSTED_CONTACTS,
      page: () => const TrustedContactsView(),
      binding: VisualHelpBinding(),
    ),
  ];
}