import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cityquest/models/campaign.dart';
import 'package:cityquest/models/quest_node.dart';

class CampaignProvider extends ChangeNotifier {
  Campaign? _activeCampaign;
  List<Campaign> _campaigns = [];
  bool _isLoading = false;
  String? _error;

  /// Callback registered by MapScreen to focus on a specific quest.
  void Function(QuestNode quest)? focusQuestCallback;

  Campaign? get activeCampaign => _activeCampaign;
  List<Campaign> get campaigns => _campaigns;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ─── Draft Auto-Save ───

  static const String _draftKey = 'campaign_draft';

  /// Save current active campaign as draft to SharedPreferences.
  Future<void> saveDraft() async {
    if (_activeCampaign == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = json.encode(_activeCampaign!.toJson());
      await prefs.setString(_draftKey, jsonStr);
    } catch (e) {
      print('⚠️ Draft save error: $e');
    }
  }

  /// Load a previously saved draft campaign.
  Future<Campaign?> loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_draftKey);
      if (jsonStr == null) return null;
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      return Campaign.fromJson(data);
    } catch (e) {
      print('⚠️ Draft load error: $e');
      return null;
    }
  }

  /// Clear the saved draft (after successful forge).
  Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (e) {
      print('⚠️ Draft clear error: $e');
    }
  }

  /// All main quest nodes from the active campaign, sorted by orderIndex.
  List<QuestNode> get mainQuests =>
      _activeCampaign?.allMainQuests ?? [];

  // ─── Context Helpers ───

  /// Get the last destination from a given day (null if day is empty or invalid).
  QuestNode? getLastDestinationOfDay(int dayIndex) {
    if (_activeCampaign == null) return null;
    if (dayIndex < 0 || dayIndex >= _activeCampaign!.days.length) return null;
    final dests = _activeCampaign!.days[dayIndex].destinations;
    return dests.isNotEmpty ? dests.last : null;
  }

  /// Get the last destination from the previous day (Day N-1).
  /// Returns null for Day 0 or if previous day has no stops.
  QuestNode? getPreviousDayLastStop(int currentDayIndex) {
    if (currentDayIndex <= 0) return null;
    return getLastDestinationOfDay(currentDayIndex - 1);
  }

  /// Mock: generate 5 nearby QuestNode suggestions around a given point.
  List<QuestNode> fetchNearbySuggestions(double lat, double lng) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return [
      QuestNode(id: 'nearby_${ts}_1', title: 'Lakeside Promenade', latitude: lat + 0.002, longitude: lng + 0.001, questType: 'exploration', description: 'A scenic walk along the lake shore.', xpReward: 60, isMainQuest: true),
      QuestNode(id: 'nearby_${ts}_2', title: 'Hilltop Garden', latitude: lat - 0.001, longitude: lng + 0.003, questType: 'discovery', description: 'Explore terraced gardens with panoramic views.', xpReward: 70, isMainQuest: true),
      QuestNode(id: 'nearby_${ts}_3', title: 'Old Market Square', latitude: lat + 0.003, longitude: lng - 0.001, questType: 'exploration', description: 'Browse local handicrafts and street food.', xpReward: 55, isMainQuest: true),
      QuestNode(id: 'nearby_${ts}_4', title: 'Riverside Chai Point', latitude: lat - 0.002, longitude: lng - 0.002, questType: 'exploration', description: 'Sip chai with a view of the river bridge.', xpReward: 45, isMainQuest: true),
      QuestNode(id: 'nearby_${ts}_5', title: 'Heritage Clock Tower', latitude: lat + 0.001, longitude: lng + 0.004, questType: 'discovery', description: 'A 19th-century tower in the town center.', xpReward: 80, isMainQuest: true),
    ];
  }

  // ─── Campaign CRUD ───

  /// Create a new empty campaign with day slots.
  void createCampaign(String title, DateTime startDate, DateTime endDate) {
    final dayCount = endDate.difference(startDate).inDays + 1;
    final days = List.generate(
      dayCount,
      (i) => DayPlan(dayNumber: i + 1),
    );

    _activeCampaign = Campaign(
      id: '', // Will be set on Firestore save
      userId: '',
      title: title,
      startDate: startDate,
      endDate: endDate,
      days: days,
    );
    saveDraft();
    notifyListeners();
  }

  /// Update campaign title.
  void updateTitle(String title) {
    if (_activeCampaign == null) return;
    _activeCampaign = _activeCampaign!.copyWith(title: title);
    saveDraft();
    notifyListeners();
  }

  /// Update campaign dates (rebuilds day slots).
  void updateDates(DateTime startDate, DateTime endDate) {
    if (_activeCampaign == null) return;
    final dayCount = endDate.difference(startDate).inDays + 1;
    final existingDays = _activeCampaign!.days;

    final newDays = List.generate(dayCount, (i) {
      if (i < existingDays.length) {
        return existingDays[i].copyWith(dayNumber: i + 1);
      }
      return DayPlan(dayNumber: i + 1);
    });

    _activeCampaign = _activeCampaign!.copyWith(
      startDate: startDate,
      endDate: endDate,
      days: newDays,
    );
    saveDraft();
    notifyListeners();
  }

  /// Add a destination to a specific day.
  void addDestination(int dayIndex, QuestNode quest) {
    if (_activeCampaign == null || dayIndex >= _activeCampaign!.days.length) return;

    // Calculate global order index
    int globalOrder = 0;
    for (int i = 0; i < dayIndex; i++) {
      globalOrder += _activeCampaign!.days[i].destinations.length;
    }
    globalOrder += _activeCampaign!.days[dayIndex].destinations.length;

    // Calculate activation date from campaign start + dayIndex
    final activationDate = _activeCampaign!.startDate.add(Duration(days: dayIndex));

    final taggedQuest = quest.copyWith(
      isMainQuest: true,
      orderIndex: globalOrder,
      activationDate: activationDate,
    );

    final days = _activeCampaign!.days.map((d) => d.copyWith()).toList();
    days[dayIndex].destinations.add(taggedQuest);
    _activeCampaign = _activeCampaign!.copyWith(days: days);
    _recalculateOrderIndices();
    saveDraft();
    notifyListeners();
  }

  /// Remove a destination from a specific day.
  void removeDestination(int dayIndex, int questIndex) {
    if (_activeCampaign == null) return;
    final days = _activeCampaign!.days.map((d) => d.copyWith()).toList();
    if (dayIndex < days.length && questIndex < days[dayIndex].destinations.length) {
      days[dayIndex].destinations.removeAt(questIndex);
      _activeCampaign = _activeCampaign!.copyWith(days: days);
      _recalculateOrderIndices();
      saveDraft();
      notifyListeners();
    }
  }

  /// Reorder a destination within a day.
  void reorderDestination(int dayIndex, int oldIdx, int newIdx) {
    if (_activeCampaign == null) return;
    final days = _activeCampaign!.days.map((d) => d.copyWith()).toList();
    if (dayIndex < days.length) {
      final dests = days[dayIndex].destinations;
      if (oldIdx < dests.length) {
        final item = dests.removeAt(oldIdx);
        if (newIdx > oldIdx) newIdx--;
        dests.insert(newIdx.clamp(0, dests.length), item);
        _activeCampaign = _activeCampaign!.copyWith(days: days);
        _recalculateOrderIndices();
        saveDraft();
        notifyListeners();
      }
    }
  }

  /// Recalculate sequential orderIndex across all days.
  void _recalculateOrderIndices() {
    if (_activeCampaign == null) return;
    int idx = 0;
    final days = _activeCampaign!.days;
    for (int d = 0; d < days.length; d++) {
      for (int q = 0; q < days[d].destinations.length; q++) {
        days[d].destinations[q] = days[d].destinations[q].copyWith(orderIndex: idx);
        idx++;
      }
    }
  }

  // ─── AI Co-Pilot (Mock) ───

  /// Mock AI: generates 3 themed destinations for a day after 3s delay.
  /// [targetArea] is the name of the area the user wants to explore.
  /// [lat]/[lng] is the starting point (from previous day's last stop or user GPS).
  Future<void> generateDayPlan(String classType, int dayIndex, double lat, double lng, {String targetArea = ''}) async {
    _isLoading = true;
    notifyListeners();

    // Simulate "Consulting the Oracle..."
    await Future.delayed(const Duration(seconds: 3));

    final area = targetArea.isNotEmpty ? targetArea : 'the area';
    final List<QuestNode> generatedQuests;
    switch (classType) {
      case 'adventurer':
        generatedQuests = [
          QuestNode(id: 'adv_${DateTime.now().millisecondsSinceEpoch}_1', title: 'Trail near $area', latitude: lat + 0.005, longitude: lng + 0.003, questType: 'exploration', description: 'Hike a scenic trail near $area.', xpReward: 120, isMainQuest: true),
          QuestNode(id: 'adv_${DateTime.now().millisecondsSinceEpoch}_2', title: 'Hidden Falls of $area', latitude: lat + 0.008, longitude: lng - 0.002, questType: 'discovery', description: 'Discover a secluded waterfall near $area.', xpReward: 150, isMainQuest: true),
          QuestNode(id: 'adv_${DateTime.now().millisecondsSinceEpoch}_3', title: 'Campsite beyond $area', latitude: lat - 0.003, longitude: lng + 0.006, questType: 'exploration', description: 'Set up camp at a lakeside spot past $area.', xpReward: 100, isMainQuest: true),
        ];
        break;
      case 'scholar':
        generatedQuests = [
          QuestNode(id: 'sch_${DateTime.now().millisecondsSinceEpoch}_1', title: 'Ruins near $area', latitude: lat + 0.004, longitude: lng + 0.002, questType: 'discovery', description: 'Explore ancient ruins close to $area.', xpReward: 130, isMainQuest: true),
          QuestNode(id: 'sch_${DateTime.now().millisecondsSinceEpoch}_2', title: '$area Heritage Museum', latitude: lat - 0.002, longitude: lng + 0.005, questType: 'trivia', description: 'Visit the museum and learn about $area history.', xpReward: 100, isMainQuest: true),
          QuestNode(id: 'sch_${DateTime.now().millisecondsSinceEpoch}_3', title: 'War Memorial of $area', latitude: lat + 0.006, longitude: lng - 0.004, questType: 'discovery', description: 'Unlock lore at the historic memorial near $area.', xpReward: 110, isMainQuest: true),
        ];
        break;
      case 'tavern_hunter':
        generatedQuests = [
          QuestNode(id: 'tav_${DateTime.now().millisecondsSinceEpoch}_1', title: 'Best Dhaba near $area', latitude: lat + 0.002, longitude: lng + 0.001, questType: 'exploration', description: 'Try legendary street food near $area.', xpReward: 90, isMainQuest: true),
          QuestNode(id: 'tav_${DateTime.now().millisecondsSinceEpoch}_2', title: 'Coffee House of $area', latitude: lat - 0.001, longitude: lng + 0.004, questType: 'discovery', description: 'Sample local brews near $area.', xpReward: 80, isMainQuest: true),
          QuestNode(id: 'tav_${DateTime.now().millisecondsSinceEpoch}_3', title: '$area Night Market', latitude: lat + 0.003, longitude: lng - 0.003, questType: 'exploration', description: 'Explore the vibrant night market of $area.', xpReward: 100, isMainQuest: true),
        ];
        break;
      default:
        generatedQuests = [];
    }

    for (final quest in generatedQuests) {
      addDestination(dayIndex, quest);
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Firebase Integration ───

  /// Save the active campaign to Firestore.
  Future<void> forgeCampaign() async {
    if (_activeCampaign == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final campaign = _activeCampaign!.copyWith(userId: user.uid);
      final firestore = FirebaseFirestore.instance;

      if (campaign.id.isEmpty) {
        // Create new
        final docRef = await firestore.collection('campaigns').add(campaign.toMap());
        _activeCampaign = campaign.copyWith(id: docRef.id);
      } else {
        // Update existing
        await firestore.collection('campaigns').doc(campaign.id).set(campaign.toMap());
      }

      // Add to local list
      _campaigns.removeWhere((c) => c.id == _activeCampaign!.id);
      _campaigns.insert(0, _activeCampaign!);

      // Clear draft after successful save
      await clearDraft();
    } catch (e) {
      _error = 'Failed to save campaign: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fetch all campaigns for the current user.
  Future<void> loadCampaigns() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('campaigns')
          .where('user_id', isEqualTo: user.uid)
          .orderBy('created_at', descending: true)
          .get();

      _campaigns = snapshot.docs
          .map((doc) => Campaign.fromMap(doc.id, doc.data()))
          .toList();

      // Set most recent as active if none set
      if (_activeCampaign == null && _campaigns.isNotEmpty) {
        _activeCampaign = _campaigns.first;
      }
    } catch (e) {
      _error = 'Failed to load campaigns: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Delete a campaign from Firestore.
  Future<void> deleteCampaign(String campaignId) async {
    try {
      await FirebaseFirestore.instance.collection('campaigns').doc(campaignId).delete();
      _campaigns.removeWhere((c) => c.id == campaignId);
      if (_activeCampaign?.id == campaignId) {
        _activeCampaign = _campaigns.isNotEmpty ? _campaigns.first : null;
      }
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete campaign: $e';
    }
  }

  /// Set a campaign as the active one (for map rendering).
  void setActiveCampaign(Campaign? campaign) {
    _activeCampaign = campaign;
    notifyListeners();
  }

  /// Clear the active campaign (e.g., when starting a new one).
  void clearActiveCampaign() {
    _activeCampaign = null;
    notifyListeners();
  }
}
