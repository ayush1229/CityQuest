import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Represents a simulated vehicle moving along a local route.
/// All movement is calculated 100% offline using interpolation.
class MovingVehicle {
  final String id;
  final BitmapDescriptor icon;
  final List<LatLng> localRoute;
  int currentRouteIndex;
  LatLng currentPosition;
  double currentHeading;

  MovingVehicle({
    required this.id,
    required this.icon,
    required this.localRoute,
    this.currentRouteIndex = 0,
    required this.currentPosition,
    this.currentHeading = 0.0,
  });
}
