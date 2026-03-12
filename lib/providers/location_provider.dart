import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cityquest/services/location_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();

  double _latitude = 28.6129; // Default: India Gate area
  double _longitude = 77.2295;
  bool _isTracking = false;
  bool _hasPermission = false;
  String? _error;
  StreamSubscription<Position>? _positionSub;

  double get latitude => _latitude;
  double get longitude => _longitude;
  bool get isTracking => _isTracking;
  bool get hasPermission => _hasPermission;
  String? get error => _error;

  /// Request permission and start streaming GPS updates.
  Future<void> startTracking() async {
    _error = null;
    try {
      _hasPermission = await _locationService.requestPermission();
      if (!_hasPermission) {
        _error = 'Location permission denied';
        notifyListeners();
        return;
      }

      // Initial position
      final pos = await _locationService.getCurrentLocation();
      _latitude = pos.latitude;
      _longitude = pos.longitude;
      _isTracking = true;
      notifyListeners();

      // Stream updates
      _positionSub = _locationService.getLocationStream().listen((pos) {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        notifyListeners();
      });
    } catch (e) {
      _error = 'Could not get location';
      _isTracking = false;
      notifyListeners();
    }
  }

  /// Stop streaming GPS.
  void stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
    _isTracking = false;
    notifyListeners();
  }

  /// Calculate distance to a point, in meters.
  double distanceTo(double lat, double lng) {
    return _locationService.distanceBetween(_latitude, _longitude, lat, lng);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }
}
