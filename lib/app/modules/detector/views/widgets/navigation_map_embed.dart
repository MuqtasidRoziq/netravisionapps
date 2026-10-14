import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  StreamSubscription<GeoPoint?>? _destSub;
  StreamSubscription<List<GeoPoint>>? _routeSub;
  static const _fallbackCenter = LatLng(-6.2, 106.816666);
  GeoPoint? _lastCameraCenter;
  final _destMarketId = const MarkerId('destination');
  final _userMarkerId = const MarkerId('user_position');
  late final LatLng _initialPosition;
  bool _isMapReady = false;
  Set<Polyline> _polylines = const {};
  Set<Marker> _markers = const {};

  @override
  void initState() {
    super.initState();
    final pos = widget.controller.userPosition.value;
    _initialPosition =
        pos != null ? LatLng(pos.lat, pos.lng) : _fallbackCenter;
    _updateOverlays();

    _subscription = widget.controller.userPosition.listen((pos) {
      if (pos == null) return;
      // Selalu perbarui marker posisi pengguna di peta.
      _updateOverlays();
      final moved = _lastCameraCenter == null ||
          haversineMeters(_lastCameraCenter!, pos) > 3.0;
      if (!moved || _mapController == null) return;
      _moveTo(pos);
    });

    _destSub = widget.controller.destinationPoint.listen((_) {
      _updateOverlays();
    });

    _routeSub = widget.controller.routePolyline.listen((_) {
      _updateOverlays();
    });

    // Beri jeda 600ms sebelum me-mount GoogleMap native PlatformView
    // agar kamera YOLO selesai mengunci buffer camera tanpa bentrok Surface.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isMapReady = true;
        });
      }
    });
  }

  void _updateOverlays() {
    final dest = widget.controller.destinationPoint.value;
    final route = widget.controller.routePolyline.value;
    final user = widget.controller.userPosition.value;
    if (!mounted) return;
    setState(() {
      _polylines = route.isEmpty
          ? const {}
          : {
              Polyline(
                polylineId: const PolylineId('route'),
                color: AppColors.primaryBlue,
                width: 6,
                points: route.map((p) => LatLng(p.lat, p.lng)).toList(),
              ),
            };
      _markers = {
        // Titik posisi pengguna agar koordinat selalu terlihat di peta.
        if (user != null)
          Marker(
            markerId: _userMarkerId,
            position: LatLng(user.lat, user.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure),
            infoWindow: const InfoWindow(title: 'Posisi Anda'),
          ),
        if (dest != null)
          Marker(
            markerId: _destMarketId,
            position: LatLng(dest.lat, dest.lng),
            infoWindow: const InfoWindow(title: 'Tujuan'),
          ),
      };
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _destSub?.cancel();
    _routeSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white54, width: 1.5),
        boxShadow: const [
          BoxShadow(
              color: Colors.black45, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [_buildMap(), _buildOverlay()],
        ),
      ),
    );
  }

  Widget _buildMap() {
    if (!_isMapReady) {
      return Container(
        color: const Color(0xFF1E293B),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition:
          CameraPosition(target: _initialPosition, zoom: 17),
      onMapCreated: (controller) {
        _mapController = controller;
        final p = widget.controller.userPosition.value;
        if (p != null) _moveTo(p);
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      scrollGesturesEnabled: widget.controller.mapExpanded.value,
      polylines: _polylines,
      markers: _markers,
    );
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
    return Stack(
      children: [
        // Panah arah hadap di tengah peta.
        IgnorePointer(
          child: Center(
            child: Obx(() {
              final heading = widget.controller.userHeading.value;
              return Transform.rotate(
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
              );
            }),
          ),
        ),

        // Tombol mikrofon (dari atas: mikrofon).
        Positioned(
          top: 6,
          right: 6,
          child: _smallButton(
            icon: Icons.mic_rounded,
            semanticLabel: 'Ucapkan tujuan rute navigasi',
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
                semanticLabel: widget.controller.mapExpanded.value
                    ? 'Perkecil peta'
                    : 'Perbesar peta',
                onTap: () => widget.controller.toggleMapExpanded(),
              )),
        ),
      ],
    );
  }

  Widget _smallButton({
    required IconData icon,
    required String semanticLabel,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
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
      ),
    );
  }
}