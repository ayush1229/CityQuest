import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _is3DMode = true;
  bool _showBuildingsLayer = true;
  bool _showTraffic = false;
  bool _devMode = false;
  String _mapStyle = 'normal'; // normal, satellite, terrain, hybrid
  String _trafficDensity = 'medium'; // low, medium, high

  SettingsProvider() {
    _loadSettings();
  }

  bool get is3DMode => _is3DMode;
  bool get showBuildingsLayer => _showBuildingsLayer;
  bool get showTraffic => _showTraffic;
  bool get devMode => _devMode;
  String get mapStyle => _mapStyle;
  String get trafficDensity => _trafficDensity;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _is3DMode = prefs.getBool('is3DMode') ?? true;
    _showBuildingsLayer = prefs.getBool('showBuildingsLayer') ?? true;
    _showTraffic = prefs.getBool('showTraffic') ?? false;
    _trafficDensity = prefs.getString('trafficDensity') ?? 'medium';
    _mapStyle = prefs.getString('mapStyle') ?? 'normal';
    notifyListeners();
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  void toggle3DMode(bool value) {
    _is3DMode = value;
    _saveSetting('is3DMode', value);
    notifyListeners();
  }

  void toggleBuildings(bool value) {
    _showBuildingsLayer = value;
    _saveSetting('showBuildingsLayer', value);
    notifyListeners();
  }

  void toggleTraffic(bool value) {
    _showTraffic = value;
    _saveSetting('showTraffic', value);
    notifyListeners();
  }

  void setMapStyle(String style) {
    _mapStyle = style;
    _saveSetting('mapStyle', style);
    notifyListeners();
  }

  void toggleDevMode(bool value) {
    _devMode = value;
    notifyListeners();
  }

  void setTrafficDensity(String density) {
    _trafficDensity = density;
    _saveSetting('trafficDensity', density);
    notifyListeners();
  }
}
