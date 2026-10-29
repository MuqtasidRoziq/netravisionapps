import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Kategori tempat penting untuk mobilitas tunanetra
enum PlaceCategory {
  transport,
  convenience,
  health,
  worship,
  food,
  custom,
}

extension PlaceCategoryExtension on PlaceCategory {
  String get title {
    switch (this) {
      case PlaceCategory.transport:
        return 'Halte & Stasiun';
      case PlaceCategory.convenience:
        return 'Minimarket & Toko';
      case PlaceCategory.health:
        return 'Apotek & Klinik';
      case PlaceCategory.worship:
        return 'Tempat Ibadah';
      case PlaceCategory.food:
        return 'Warung & Makan';
      case PlaceCategory.custom:
        return 'Pencarian Lainnya';
    }
  }

  IconData get icon {
    switch (this) {
      case PlaceCategory.transport:
        return Icons.directions_bus_rounded;
      case PlaceCategory.convenience:
        return Icons.storefront_rounded;
      case PlaceCategory.health:
        return Icons.local_hospital_rounded;
      case PlaceCategory.worship:
        return Icons.mosque_rounded;
      case PlaceCategory.food:
        return Icons.restaurant_rounded;
      case PlaceCategory.custom:
        return Icons.search_rounded;
    }
  }
}

/// Model tempat penting terdekat (POI)
class NearbyPlaceModel {
  const NearbyPlaceModel({
    required this.id,
    required this.name,
    required this.category,
    required this.point,
    required this.distanceMeters,
    required this.relativeBearing,
    required this.clockDirection,
    this.address = '',
  });

  final String id;
  final String name;
  final PlaceCategory category;
  final LatLng point;
  final double distanceMeters;
  final double relativeBearing;
  final String clockDirection;
  final String address;

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} meter';
    } else {
      final km = distanceMeters / 1000;
      return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
    }
  }

  /// Teks ramah suara untuk pembacaan daftar
  String get speechAnnouncement {
    return '$name, berjarak $formattedDistance, di $clockDirection Anda.';
  }
}

/// Tipe manuver belokan navigasi
enum TurnType {
  depart,
  continueStraight,
  slightRight,
  right,
  sharpRight,
  slightLeft,
  left,
  sharpLeft,
  uTurn,
  arrive,
}

extension TurnTypeExtension on TurnType {
  IconData get icon {
    switch (this) {
      case TurnType.depart:
      case TurnType.continueStraight:
        return Icons.arrow_upward_rounded;
      case TurnType.slightRight:
        return Icons.turn_slight_right_rounded;
      case TurnType.right:
      case TurnType.sharpRight:
        return Icons.turn_right_rounded;
      case TurnType.slightLeft:
        return Icons.turn_slight_left_rounded;
      case TurnType.left:
      case TurnType.sharpLeft:
        return Icons.turn_left_rounded;
      case TurnType.uTurn:
        return Icons.u_turn_left_rounded;
      case TurnType.arrive:
        return Icons.place_rounded;
    }
  }
}

/// Satu langkah instruksi rute pejalan kaki
class NavigationStep {
  const NavigationStep({
    required this.instruction,
    required this.streetName,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.turnType,
    required this.targetPoint,
    required this.clockFace,
  });

  final String instruction;
  final String streetName;
  final double distanceMeters;
  final double durationSeconds;
  final TurnType turnType;
  final LatLng targetPoint;
  final String clockFace;

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    } else {
      final km = distanceMeters / 1000;
      return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
    }
  }
}

/// Model rute lengkap pejalan kaki
class NavigationRoute {
  const NavigationRoute({
    required this.totalDistanceMeters,
    required this.estimatedDurationSeconds,
    required this.polylinePoints,
    required this.steps,
    required this.destinationName,
  });

  final double totalDistanceMeters;
  final double estimatedDurationSeconds;
  final List<LatLng> polylinePoints;
  final List<NavigationStep> steps;
  final String destinationName;

  String get formattedTotalDistance {
    if (totalDistanceMeters < 1000) {
      return '${totalDistanceMeters.round()} meter';
    } else {
      final km = totalDistanceMeters / 1000;
      return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
    }
  }

  String get formattedEstimatedTime {
    final minutes = (estimatedDurationSeconds / 60).round();
    if (minutes <= 1) return 'sekitar 1 menit';
    return 'sekitar $minutes menit';
  }
}
