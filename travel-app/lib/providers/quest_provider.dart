import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:cityquest/models/quest_node.dart';
import 'package:cityquest/services/firebase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuestProvider extends ChangeNotifier {
  List<QuestNode> _quests = [];
  QuestNode? _activeQuest;
  bool _isLoading = false;
  String? _error;
  double _searchRadius = 500; // Default 500m

  // Route drawing
  List<LatLng> _routePoints = [];

  QuestProvider() {
    _loadRadius();
  }

  List<QuestNode> get quests => _quests;
  QuestNode? get activeQuest => _activeQuest;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get searchRadius => _searchRadius;
  List<LatLng> get routePoints => _routePoints;

  Future<void> _loadRadius() async {
    final prefs = await SharedPreferences.getInstance();
    _searchRadius = prefs.getDouble('searchRadius') ?? 500;
    notifyListeners();
  }

  Future<void> _saveRadius(double radius) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('searchRadius', radius);
  }

  void setSearchRadius(double radius) {
    _searchRadius = radius;
    _saveRadius(radius);
    notifyListeners();
  }

  void clearRoute() {
    _routePoints = [];
    notifyListeners();
  }

  /// Load the user's active quests from Firestore.
  Future<void> loadQuests() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final firebaseService = FirebaseService();
      _quests = await firebaseService.fetchActiveQuests();
      _activeQuest = null;
      _routePoints = [];
    } catch (e) {
      _error = 'Failed to load active quests from server.';
      _quests = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Set the currently active quest (for the popup).
  void setActiveQuest(QuestNode? quest) {
    _activeQuest = quest;
    notifyListeners();
  }

  /// Remove a single completed quest from the local list (without re-fetching).
  void removeQuest(String questId) {
    _quests.removeWhere((q) => q.id == questId);
    if (_activeQuest?.id == questId) {
      _activeQuest = null;
    }
    _routePoints = []; // clear route if completing a quest
    notifyListeners();
  }

  /// Fetch and decode a route from the Directions API via the secure Cloud Function
  Future<void> constructRoute(double userLat, double userLng, QuestNode destination) async {
    _isLoading = true;
    notifyListeners();

    final firebaseService = FirebaseService();
    final polylineString = await firebaseService.fetchRoute(
      originLat: userLat,
      originLng: userLng,
      destLat: destination.coordinates.latitude,
      destLng: destination.coordinates.longitude,
    );

    if (polylineString != null && polylineString.isNotEmpty) {
      List<PointLatLng> result = PolylinePoints.decodePolyline(polylineString);

      if (result.isNotEmpty) {
        _routePoints = result.map((point) => LatLng(point.latitude, point.longitude)).toList();
      } else {
        _routePoints = [];
      }
    } else {
      _routePoints = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Call the backend AI to generate new quests at the user's location.
  /// Replaces the current active quests.
  Future<List<QuestNode>> fetchQuestsFromAI(double lat, double lng) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final firebaseService = FirebaseService();
      final quests = await firebaseService.generateQuests(lat, lng, radius: _searchRadius);
      if (quests.isNotEmpty) {
        _quests = quests;
        _activeQuest = null;
        _routePoints = [];
      }
      
      _isLoading = false;
      notifyListeners();
      return quests;
    } catch (_) {
      _isLoading = false;
      _error = 'Failed to generate new quests.';
      notifyListeners();
      return [];
    }
  }

  /// Inject campaign quests into the active map session.
  void loadCampaignQuests(List<QuestNode> campaignQuests) {
    // Optionally clear existing AI side-quests or just append
    // Here we append so users can still do side quests alongside the campaign
    final existingIds = _quests.map((q) => q.id).toSet();
    final newQuests = campaignQuests.where((q) => !existingIds.contains(q.id)).toList();
    
    _quests.addAll(newQuests);
    _activeQuest = null;
    _routePoints = [];
    notifyListeners();
  }
}
