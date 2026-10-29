import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/models/navigation_models.dart';
import '../../../data/models/vision_mode.dart';
import '../../../routes/app_pages.dart';
import '../../../utils/constants/app_colors.dart';
import '../../detector/controllers/detector_controller.dart';
import '../controllers/outdoor_navigation_controller.dart';

class OutdoorNavigationView extends GetView<OutdoorNavigationController> {
  const OutdoorNavigationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 1. Jika Mode Layar Gelap (Curtain Screen) aktif untuk hemat baterai
      if (controller.isCurtainScreen.value) {
        return _buildCurtainScreen();
      }

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(context),
        body: SafeArea(
          child: Column(
            children: [
              // Banner Alamat Saat Ini
              _buildLocationHeader(),

              // Konten Utama Dinamis Berdasarkan State Navigasi
              Expanded(
                child: switch (controller.state.value) {
                  OutdoorState.idle => _buildIdleMenu(context),
                  OutdoorState.searching => _buildLoadingState('Mencari tempat terdekat...'),
                  OutdoorState.placesFound => _buildPlacesFoundList(),
                  OutdoorState.routeCalculating => _buildLoadingState('Menghitung rute pejalan kaki...'),
                  OutdoorState.navigating => _buildActiveNavigationScreen(),
                  OutdoorState.arrived => _buildArrivedScreen(),
                },
              ),
            ],
          ),
        ),
      );
    });
  }

  /// AppBar dengan tombol navigasi, suara lokasi, dan mode hemat baterai
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      toolbarHeight: 70,
      leading: Semantics(
        label: 'Kembali ke Menu Utama',
        button: true,
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryBlue),
          onPressed: () {
            HapticFeedback.lightImpact();
            Get.back();
          },
        ),
      ),
      title: const Text(
        'Navigasi & Tempat',
        style: TextStyle(
          color: AppColors.primaryBlue,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: [
        // Tombol Di Mana Saya?
        Semantics(
          label: 'Di mana saya sekarang? Ketuk untuk mendengarkan alamat saat ini',
          button: true,
          child: IconButton(
            tooltip: 'Lokasi Saya',
            icon: const Icon(Icons.my_location_rounded, color: AppColors.primaryBlue, size: 28),
            onPressed: () => controller.announceWhereAmI(),
          ),
        ),

        // Tombol Mode Layar Gelap (Curtain Screen)
        Semantics(
          label: 'Mode Layar Gelap. Ketuk untuk mematikan layar guna menghemat baterai.',
          button: true,
          child: IconButton(
            tooltip: 'Layar Gelap (Hemat Baterai)',
            icon: const Icon(Icons.visibility_off_rounded, color: AppColors.primaryBlue, size: 28),
            onPressed: () => controller.toggleCurtainScreen(),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// Banner informasi posisi real-time pengguna
  Widget _buildLocationHeader() {
    return Obx(() {
      final address = controller.locationService.currentAddress.value;
      final heading = controller.locationService.currentHeading.value.round();
      final cardinal = controller.locationService.headingToCardinal(heading.toDouble());

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.lightBlueBorder, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.navigation_rounded, color: AppColors.primaryBlue, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Menghadap $cardinal ($heading°)',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  /// Menu awal: Pilihan Kategori Tempat Terdekat
  Widget _buildIdleMenu(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        const Text(
          'Cari Tempat Terdekat:',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),

        // Kategori 1: Halte & Stasiun
        _buildCategoryCard(
          title: '1. Halte & Stasiun Terdekat',
          subtitle: 'Transportasi umum, busway, KRL',
          icon: Icons.directions_bus_rounded,
          onTap: () => controller.searchNearbyCategory(PlaceCategory.transport),
        ),
        const SizedBox(height: 10),

        // Kategori 2: Minimarket & Toko
        _buildCategoryCard(
          title: '2. Minimarket & Toko',
          subtitle: 'Indomaret, Alfamart, kelontong',
          icon: Icons.storefront_rounded,
          onTap: () => controller.searchNearbyCategory(PlaceCategory.convenience),
        ),
        const SizedBox(height: 10),

        // Kategori 3: Apotek & Klinik
        _buildCategoryCard(
          title: '3. Apotek & Klinik',
          subtitle: 'Obat, puskesmas, rumah sakit',
          icon: Icons.local_hospital_rounded,
          onTap: () => controller.searchNearbyCategory(PlaceCategory.health),
        ),
        const SizedBox(height: 10),

        // Kategori 4: Tempat Ibadah
        _buildCategoryCard(
          title: '4. Tempat Ibadah Terdekat',
          subtitle: 'Masjid, musholla, gereja',
          icon: Icons.mosque_rounded,
          onTap: () => controller.searchNearbyCategory(PlaceCategory.worship),
        ),
        const SizedBox(height: 10),

        // Kategori 5: Warung & Makan
        _buildCategoryCard(
          title: '5. Warung Makan & Kuliner',
          subtitle: 'Warung, restoran terdekat',
          icon: Icons.restaurant_rounded,
          onTap: () => controller.searchNearbyCategory(PlaceCategory.food),
        ),
        const SizedBox(height: 10),

        // Kategori 6: Cari Nama Tempat Bebas
        _buildCategoryCard(
          title: '6. Cari Nama Tempat Spesifik',
          subtitle: 'Ketik nama gedung, toko, atau jalan',
          icon: Icons.search_rounded,
          onTap: () => _showSearchDialog(context),
        ),
        const SizedBox(height: 16),

        // Pintasan Langsung: Kamera Detektor Rintangan Outdoor
        Semantics(
          label: 'Buka Kamera Deteksi Rintangan Outdoor Langsung',
          hint: 'Ketuk dua kali untuk membuka kamera pemindai tiang dan lubang',
          button: true,
          child: Material(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.mediumImpact();
                Get.delete<DetectorController>(force: true);
                Get.toNamed(Routes.DETECTOR, arguments: VisionMode.outdoor);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Icon(Icons.videocam_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kamera Deteksi Rintangan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Pindai tiang, lubang jalan & trotoar langsung',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Kartu Kategori Tempat
  Widget _buildCategoryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: '$title. $subtitle.',
      button: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.lightBlueBorder, width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primaryBlue, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: AppColors.primaryBlue, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tampilan Daftar Tempat yang Ditemukan
  Widget _buildPlacesFoundList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ditemukan ${controller.nearbyPlaces.length} Tempat:',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Batal'),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  controller.state.value = OutdoorState.idle;
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: controller.nearbyPlaces.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final place = controller.nearbyPlaces[index];
              return _buildPlaceItem(place, index + 1);
            },
          ),
        ),
      ],
    );
  }

  /// Baris Tempat Terdekat dalam Daftar
  Widget _buildPlaceItem(NearbyPlaceModel place, int number) {
    return Semantics(
      label: '$number. ${place.speechAnnouncement}. Ketuk dua kali untuk memulai rute.',
      button: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => controller.startNavigation(place),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.lightBlueBorder, width: 1.2),
            ),
            child: Row(
              children: [
                // Nomor urut
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.lightBlue,
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.lightBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              place.formattedDistance,
                              style: const TextStyle(
                                color: AppColors.primaryBlue,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              place.clockDirection,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (place.address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          place.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black45, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.directions_walk_rounded, color: AppColors.primaryBlue, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tampilan Navigasi Rute Aktif (Instruksi Belokan + Peta Kontras Tinggi + Tindakan)
  Widget _buildActiveNavigationScreen() {
    final route = controller.activeRoute.value;
    if (route == null) return const SizedBox();

    final stepIdx = controller.currentStepIndex.value;
    final currentStep = stepIdx < route.steps.length ? route.steps[stepIdx] : route.steps.last;
    final userPos = controller.locationService.currentGpsPosition.value;
    final userLatLng = userPos != null ? LatLng(userPos.latitude, userPos.longitude) : route.polylinePoints.first;

    return Column(
      children: [
        // 1. Kartu Instruksi Belokan Besar (Ramah Penglihatan Lemah & Tunanetra)
        Semantics(
          label: 'Instruksi: ${controller.currentInstruction.value}. '
              'Jarak ke belokan ${controller.remainingDistanceToStep.value.round()} meter. '
              'Ketuk di sini untuk mengulang instruksi.',
          button: true,
          child: GestureDetector(
            onTap: () => controller.repeatCurrentInstruction(),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      currentStep.turnType.icon,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${controller.remainingDistanceToStep.value.round()} m lagi',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                currentStep.clockFace,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          controller.currentInstruction.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 2. Peta Visual OpenStreetMap (Untuk Pendamping / Low Vision)
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.lightBlueBorder, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: userLatLng,
                initialZoom: 17.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.netravision.apps',
                ),
                // Garis Rute Pejalan Kaki
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: route.polylinePoints,
                      color: AppColors.primaryBlue,
                      strokeWidth: 6.0,
                    ),
                  ],
                ),
                // Titik Marker Pengguna & Tujuan
                MarkerLayer(
                  markers: [
                    // Marker Lokasi Pengguna
                    Marker(
                      point: userLatLng,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 6),
                          ],
                        ),
                        child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                    // Marker Tujuan Akhir
                    Marker(
                      point: route.polylinePoints.last,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFC62828),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 6),
                          ],
                        ),
                        child: const Icon(Icons.flag_rounded, color: Colors.white, size: 26),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 3. Tombol Aksi Bawah
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2)),
            ],
          ),
          child: Row(
            children: [
              // Tombol Ulangi Suara (Besar)
              Expanded(
                flex: 2,
                child: Semantics(
                  label: 'Ulangi instruksi navigasi rute saat ini',
                  button: true,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lightBlue,
                      foregroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.lightBlueBorder, width: 1.5),
                      ),
                    ),
                    icon: const Icon(Icons.volume_up_rounded, size: 24),
                    label: const Text(
                      'Ulangi Suara',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => controller.repeatCurrentInstruction(),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Tombol Hentikan Navigasi
              Expanded(
                flex: 1,
                child: Semantics(
                  label: 'Hentikan navigasi rute',
                  button: true,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFEBEE),
                      foregroundColor: const Color(0xFFC62828),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0xFFFFCDD2), width: 1.5),
                      ),
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 24),
                    label: const Text(
                      'Stop',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => controller.cancelNavigation(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Tampilan saat tiba di tujuan
  Widget _buildArrivedScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 72),
            ),
            const SizedBox(height: 20),
            const Text(
              'Alhamdulillah!',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              controller.currentInstruction.value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => controller.cancelNavigation(),
              child: const Text('Kembali ke Menu Utama', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// Indikator Loading Suara
  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primaryBlue),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.primaryBlue,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// Layar Gelap Total (Curtain Screen) untuk Hemat Baterai Ekstrem & Privasi
  Widget _buildCurtainScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Semantics(
          label: 'Mode Layar Gelap Aktif. Ketuk di mana saja pada layar untuk mengulang info rute atau lokasi.',
          hint: 'Ketuk layar untuk mendengarkan arah',
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => controller.repeatCurrentInstruction(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.visibility_off_rounded, color: Colors.white30, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Mode Layar Gelap (Hemat Baterai)',
                        style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ketuk di mana saja untuk mengulang suara',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                      const SizedBox(height: 32),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.visibility_rounded),
                        label: const Text('Nyalakan Layar Kembali'),
                        onPressed: () => controller.toggleCurtainScreen(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Dialog Pencarian Nama Tempat Bebas
  void _showSearchDialog(BuildContext context) {
    final textController = TextEditingController();
    Get.defaultDialog(
      title: 'Cari Tempat Spesifik',
      titleStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Misal: Stasiun Gambir, Toko Roti',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (val) {
            Get.back();
            controller.searchCustomText(val);
          },
        ),
      ),
      textConfirm: 'Cari',
      textCancel: 'Batal',
      confirmTextColor: Colors.white,
      buttonColor: AppColors.primaryBlue,
      onConfirm: () {
        Get.back();
        controller.searchCustomText(textController.text);
      },
    );
  }
}
