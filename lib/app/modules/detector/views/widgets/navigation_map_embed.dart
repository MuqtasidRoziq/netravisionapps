import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../services/api_keys.dart';
import '../../../../utils/constants/app_colors.dart';
import '../../../../utils/helpers/geo_math.dart';
import '../../controllers/detector_controller.dart';

/// Peta kecil navigasi Mode Jalan (utara di atas, user selalu di tengah).
///
/// - Kamera mengikuti posisi GPS (dipindah saat user bergerak > ~3 m).
/// - Panah di tengah berputar mengikuti arah hadap kompas.
/// - Polyline rute + marker tujuan digambar dari controller.
/// - Tombol: mikrofon (bicara tujuan) & perbesar penuh.
class NavigationMapEmbed extends StatefulWidget {
  final DetectorController controller;

  const NavigationMapEmbed({super.key, required this.controller});

  @override
  State<NavigationMapEmbed> createState() => _NavigationMapEmbedState();
}

class _NavigationMapEmbedState extends State<NavigationMapEmbed> {
  GoogleMapController? _mapController;
  StreamSubscription<GeoPoint?>? _subscription;
  static const _fallbackCenter = LatLng(-6.2, 106.816666);
  GeoPoint? _lastCameraCenter;
  final _destMarketId = const MarkerId('destination');

  @override
  void initState() {
    super.initState();
    _subscription = widget.controller.userPosition.listen((pos) {
      if (pos == null) return;
      final moved = _lastCameraCenter == null ||
          haversineMeters(_lastCameraCenter!, pos) > 3.0;
      if (!moved || _mapController == null) return;
      _lastCameraCenter = pos;
      _mapController!.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(pos.lat, pos.lng), zoom: 17),
        ),
      );
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final child = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [_buildMap(), _buildOverlay()],
        ),
      );
      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white54, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: child,
      );
    });
  }

  Widget _buildMap() {
    if (!ApiKeys.isConfigured) {
      return Container(
        color: AppColors.surface,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, color: AppColors.textSecondary, size: 32),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Peta belum aktif. Tambahkan GOOGLE_MAPS_API_KEY saat build.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Obx(() {
      final pos = widget.controller.userPosition.value;
      final initial =
          pos != null ? LatLng(pos.lat, pos.lng) : _fallbackCenter;
      final dest = widget.controller.destinationPoint.value;
      final route = widget.controller.routePolyline.value;
      return GoogleMap(
        initialCameraPosition: CameraPosition(target: initial, zoom: 17),
        onMapCreated: (controller) {
          _mapController = controller;
          final p = widget.controller.userPosition.value;
          if (p != null) _moveTo(p);
        },
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        compassEnabled: false,
        mapToolbarEnabled: false,
        zoomControlsEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        scrollGesturesEnabled: widget.controller.mapExpanded.value,
        polylines: route.isEmpty
            ? const {}
            : {
                Polyline(
                  polylineId: const PolylineId('route'),
                  color: AppColors.primaryBlue,
                  width: 6,
                  points: route.map((p) => LatLng(p.lat, p.lng)).toList(),
                ),
              },
        markers: dest == null
            ? const {}
            : {
                Marker(
                  markerId: _destMarketId,
                  position: LatLng(dest.lat, dest.lng),
                  infoWindow: InfoWindow(title: 'Tujuan'),
                ),
              },
      );
    });
  }

  void _moveTo(GeoPoint p) {
    _lastCameraCenter = p;
    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(p.lat, p.lng), zoom: 17),
      ),
    );
  }

  Widget _buildOverlay() {
    final heading = widget.controller.userHeading.value;
    return Stack(
      children: [
        // Panah arah hadap di tengah peta.
        IgnorePointer(
          child: Center(
            child: Transform.rotate(
              angle: heading * math.pi / 180,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 8),
                  ],
                ),
                child: const Icon(Icons.navigation_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
        ),

        // Tombol mikrofon (dari atas: mikrofon).
        Positioned(
          top: 6,
          right: 6,
          child: _smallButton(
            icon: Icons.mic_rounded,
            onTap: () => widget.controller.startDestinationListening(),
          ),
        ),

        // Tombol perluas.
        Positioned(
          bottom: 6,
          right: 6,
          child: Obx(() => _smallButton(
                icon: widget.controller.mapExpanded.value
                    ? Icons.close_fullscreen_rounded
                    : Icons.open_in_full_rounded,
                onTap: () => widget.controller.toggleMapExpanded(),
              )),
        ),
      ],
    );
  }

  Widget _smallButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: AppColors.primaryBlue,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}