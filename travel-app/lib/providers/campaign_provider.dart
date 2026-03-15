import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cityquest/models/campaign.dart';
import 'package:cityquest/models/quest_node.dart';
import 'package:cityquest/services/firebase_service.dart';

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

  // ─── Forge Progress State ───
  bool _isForging = false;
  int _forgeProgress = 0;
  int _forgeTotal = 0;
  String _forgeStatusMessage = '';

  bool get isForging => _isForging;
  int get forgeProgress => _forgeProgress;
  int get forgeTotal => _forgeTotal;
  String get forgeStatusMessage => _forgeStatusMessage;

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

  // ─── Level Helpers ───

  /// Get the last destination from a given level (null if level is empty or invalid).
  QuestNode? getLastDestinationOfLevel(int levelIndex) {
    if (_activeCampaign == null) return null;
    if (levelIndex < 0 || levelIndex >= _activeCampaign!.levels.length) return null;
    final dests = _activeCampaign!.levels[levelIndex].destinations;
    return dests.isNotEmpty ? dests.last : null;
  }

  /// Get the last destination from the previous level (Level N-1).
  /// Returns null for Level 0 or if previous level has no stops.
  QuestNode? getPreviousLevelLastStop(int currentLevelIndex) {
    if (currentLevelIndex <= 0) return null;
    return getLastDestinationOfLevel(currentLevelIndex - 1);
  }

  /// Returns the lowest incomplete level number (1-indexed).
  /// If all levels are complete, returns the last level number + 1.
  int getActiveLevel() {
    if (_activeCampaign == null) return 1;
    for (final level in _activeCampaign!.levels) {
      if (!level.isCompleted) return level.levelNumber;
    }
    // All complete — return next level
    return (_activeCampaign!.levels.isEmpty)
        ? 1
        : _activeCampaign!.levels.last.levelNumber + 1;
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

  /// Create a new campaign with a single empty Level 1.
  void createCampaign(String title, DateTime startDate, DateTime endDate) {
    _activeCampaign = Campaign(
      id: '',
      userId: '',
      title: title,
      startDate: startDate,
      endDate: endDate,
      levels: [CampaignLevel(levelNumber: 1)],
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

  /// Update campaign dates (levels are NOT rebuilt — they're independent of dates).
  void updateDates(DateTime startDate, DateTime endDate) {
    if (_activeCampaign == null) return;
    _activeCampaign = _activeCampaign!.copyWith(
      startDate: startDate,
      endDate: endDate,
    );
    saveDraft();
    notifyListeners();
  }

  /// Add a new empty level to the campaign.
  void addLevel() {
    if (_activeCampaign == null) return;
    final levels = _activeCampaign!.levels.map((l) => l.copyWith()).toList();
    final nextNumber = levels.isEmpty ? 1 : levels.last.levelNumber + 1;
    levels.add(CampaignLevel(levelNumber: nextNumber));
    _activeCampaign = _activeCampaign!.copyWith(levels: levels);
    saveDraft();
    notifyListeners();
  }

  /// Add a destination to a specific level.
  void addDestination(int levelIndex, QuestNode quest) {
    if (_activeCampaign == null || levelIndex >= _activeCampaign!.levels.length) return;

    // Calculate global order index
    int globalOrder = 0;
    for (int i = 0; i < levelIndex; i++) {
      globalOrder += _activeCampaign!.levels[i].destinations.length;
    }
    globalOrder += _activeCampaign!.levels[levelIndex].destinations.length;

    // Alternate between discovery and exploration for main quests
    final isEven = globalOrder % 2 == 0;
    
    final taggedQuest = quest.copyWith(
      isMainQuest: true,
      questType: isEven ? 'discovery' : 'exploration',
      orderIndex: globalOrder,
    );

    final levels = _activeCampaign!.levels.map((l) => l.copyWith()).toList();
    levels[levelIndex].destinations.add(taggedQuest);
    _activeCampaign = _activeCampaign!.copyWith(levels: levels);
    _recalculateOrderIndices();
    saveDraft();
    notifyListeners();
  }

  /// Remove a destination from a specific level.
  void removeDestination(int levelIndex, int questIndex) {
    if (_activeCampaign == null) return;
    final levels = _activeCampaign!.levels.map((l) => l.copyWith()).toList();
    if (levelIndex < levels.length && questIndex < levels[levelIndex].destinations.length) {
      levels[levelIndex].destinations.removeAt(questIndex);
      _activeCampaign = _activeCampaign!.copyWith(levels: levels);
      _recalculateOrderIndices();
      saveDraft();
      notifyListeners();
    }
  }

  /// Remove an entire level from the campaign and re-number remaining levels.
  void removeLevel(int levelIndex) {
    if (_activeCampaign == null) return;
    final levels = _activeCampaign!.levels.map((l) => l.copyWith()).toList();
    if (levelIndex < levels.length) {
      levels.removeAt(levelIndex);
      // Re-number
      for (int i = 0; i < levels.length; i++) {
        levels[i] = CampaignLevel(
          levelNumber: i + 1,
          destinations: levels[i].destinations,
        );
      }
      _activeCampaign = _activeCampaign!.copyWith(levels: levels);
      _recalculateOrderIndices();
      saveDraft();
      notifyListeners();
    }
  }

  /// Replace a destination at a specific index within a level.
  void replaceDestination(int levelIndex, int questIndex, QuestNode newQuest) {
    if (_activeCampaign == null) return;
    final levels = _activeCampaign!.levels.map((l) => l.copyWith()).toList();
    if (levelIndex < levels.length && questIndex < levels[levelIndex].destinations.length) {
      final isEven = levels[levelIndex].destinations[questIndex].orderIndex % 2 == 0;
      final tagged = newQuest.copyWith(
        isMainQuest: true,
        questType: isEven ? 'discovery' : 'exploration',
        orderIndex: levels[levelIndex].destinations[questIndex].orderIndex,
      );
      levels[levelIndex].destinations[questIndex] = tagged;
      _activeCampaign = _activeCampaign!.copyWith(levels: levels);
      saveDraft();
      notifyListeners();
    }
  }

  /// Delete the active campaign entirely.
  void deleteActiveCampaign() {
    _activeCampaign = null;
    clearDraft();
    notifyListeners();
  }

  /// Reorder a destination within a level.
  void reorderDestination(int levelIndex, int oldIdx, int newIdx) {
    if (_activeCampaign == null) return;
    final levels = _activeCampaign!.levels.map((l) => l.copyWith()).toList();
    if (levelIndex < levels.length) {
      final dests = levels[levelIndex].destinations;
      if (oldIdx < dests.length) {
        final item = dests.removeAt(oldIdx);
        if (newIdx > oldIdx) newIdx--;
        dests.insert(newIdx.clamp(0, dests.length), item);
        _activeCampaign = _activeCampaign!.copyWith(levels: levels);
        _recalculateOrderIndices();
        saveDraft();
        notifyListeners();
      }
    }
  }

  /// Mark a quest as completed within a level.
  void completeQuest(int levelIndex, int questIndex) {
    if (_activeCampaign == null) return;
    final levels = _activeCampaign!.levels.map((l) => l.copyWith()).toList();
    if (levelIndex < levels.length && questIndex < levels[levelIndex].destinations.length) {
      levels[levelIndex].destinations[questIndex] =
          levels[levelIndex].destinations[questIndex].copyWith(isCompleted: true);
      _activeCampaign = _activeCampaign!.copyWith(levels: levels);
      saveDraft();
      notifyListeners();
    }
  }

  /// Recalculate sequential orderIndex across all levels.
  void _recalculateOrderIndices() {
    if (_activeCampaign == null) return;
    int idx = 0;
    final levels = _activeCampaign!.levels;
    for (int l = 0; l < levels.length; l++) {
      for (int q = 0; q < levels[l].destinations.length; q++) {
        levels[l].destinations[q] = levels[l].destinations[q].copyWith(orderIndex: idx);
        idx++;
      }
    }
  }

  // ─── AI Co-Pilot (Mock) ───

  /// Generate campaign quests for a level using 3-tier AI fallback.
  /// Calls the generateCampaignQuests Cloud Function (Gemini → OpenRouter → Hardcoded).
  Future<void> generateLevelPlan(String classType, int levelIndex, double lat, double lng, {String targetArea = ''}) async {
    _isLoading = true;
    notifyListeners();

    final area = targetArea.isNotEmpty ? targetArea : 'the area';

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'generateCampaignQuests',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );

      final result = await callable.call({
        'classType': classType,
        'latitude': lat,
        'longitude': lng,
        'targetArea': area,
      });

      final data = result.data as Map<String, dynamic>;
      final questList = data['quests'] as List<dynamic>;

      for (final q in questList) {
        final quest = QuestNode(
          id: '${classType}_${DateTime.now().millisecondsSinceEpoch}_${questList.indexOf(q)}',
          title: q['title'] ?? 'Unknown Quest',
          description: q['description'] ?? '',
          latitude: (q['latitude'] as num).toDouble(),
          longitude: (q['longitude'] as num).toDouble(),
          questType: q['questType'] ?? 'exploration',
          xpReward: (q['xpReward'] as num?)?.toInt() ?? 100,
          isMainQuest: true,
          googlePlaceId: q['googlePlaceId'] ?? '',
        );
        addDestination(levelIndex, quest);
      }

      print('[Oracle] ✅ Cloud Function returned ${questList.length} quests.');

    } catch (e) {
      print('[Oracle] ⚠️ Cloud Function failed, using Dart-side hardcoded fallback: $e');
      // Dart-side hardcoded fallback
      final ts = DateTime.now().millisecondsSinceEpoch;
      final List<QuestNode> fallbackQuests;
      switch (classType) {
        case 'adventurer':
          fallbackQuests = [
            QuestNode(id: 'adv_${ts}_1', title: 'Trail near $area', latitude: lat + 0.005, longitude: lng + 0.003, questType: 'exploration', description: 'Hike a scenic trail near $area.', xpReward: 120, isMainQuest: true),
            QuestNode(id: 'adv_${ts}_2', title: 'Hidden Falls of $area', latitude: lat + 0.008, longitude: lng - 0.002, questType: 'discovery', description: 'Discover a secluded waterfall near $area.', xpReward: 150, isMainQuest: true),
            QuestNode(id: 'adv_${ts}_3', title: 'Campsite beyond $area', latitude: lat - 0.003, longitude: lng + 0.006, questType: 'exploration', description: 'Set up camp at a lakeside spot past $area.', xpReward: 100, isMainQuest: true),
          ];
          break;
        case 'scholar':
          fallbackQuests = [
            QuestNode(id: 'sch_${ts}_1', title: 'Ruins near $area', latitude: lat + 0.004, longitude: lng + 0.002, questType: 'discovery', description: 'Explore ancient ruins close to $area.', xpReward: 130, isMainQuest: true),
            QuestNode(id: 'sch_${ts}_2', title: '$area Heritage Museum', latitude: lat - 0.002, longitude: lng + 0.005, questType: 'trivia', description: 'Visit the museum and learn about $area history.', xpReward: 100, isMainQuest: true),
            QuestNode(id: 'sch_${ts}_3', title: 'War Memorial of $area', latitude: lat + 0.006, longitude: lng - 0.004, questType: 'discovery', description: 'Unlock lore at the historic memorial near $area.', xpReward: 110, isMainQuest: true),
          ];
          break;
        case 'tavern_hunter':
          fallbackQuests = [
            QuestNode(id: 'tav_${ts}_1', title: 'Best Dhaba near $area', latitude: lat + 0.002, longitude: lng + 0.001, questType: 'exploration', description: 'Try legendary street food near $area.', xpReward: 90, isMainQuest: true),
            QuestNode(id: 'tav_${ts}_2', title: 'Coffee House of $area', latitude: lat - 0.001, longitude: lng + 0.004, questType: 'discovery', description: 'Sample local brews near $area.', xpReward: 80, isMainQuest: true),
            QuestNode(id: 'tav_${ts}_3', title: '$area Night Market', latitude: lat + 0.003, longitude: lng - 0.003, questType: 'exploration', description: 'Explore the vibrant night market of $area.', xpReward: 100, isMainQuest: true),
          ];
          break;
        default:
          fallbackQuests = [];
      }
      for (final quest in fallbackQuests) {
        addDestination(levelIndex, quest);
      }
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

  /// Forge campaign AND save campaign quests to Firestore in batches.
  /// [onQuestsGenerated] is called as each batch of quests is saved
  /// so they can be injected into the map immediately.
  static const int _batchSize = 3;

  Future<void> forgeCampaignWithQuests({
    required void Function(List<QuestNode> quests) onQuestsGenerated,
  }) async {
    if (_activeCampaign == null) return;

    // 1. Save campaign metadata to Firestore
    await forgeCampaign();
    if (_error != null) return;

    // 2. Collect all destinations
    final allDests = _activeCampaign!.allMainQuests;
    if (allDests.isEmpty) return;

    _isForging = true;
    _forgeProgress = 0;
    _forgeTotal = allDests.length;
    _forgeStatusMessage = 'Forging quests... (0/${allDests.length})';
    notifyListeners();

    final firebaseService = FirebaseService();

    // 3. Save in batches directly to Firestore active_quests
    for (int i = 0; i < allDests.length; i += _batchSize) {
      final batchEnd = (i + _batchSize).clamp(0, allDests.length);
      final batch = allDests.sublist(i, batchEnd);

      // Ensure each quest has a proper non-trivia type and isMainQuest
      final taggedBatch = batch.map((dest) {
        final type = dest.questType == 'trivia' ? 'discovery' : dest.questType;
        return dest.copyWith(
          isMainQuest: true,
          questType: type,
          description: dest.description.isNotEmpty
              ? dest.description
              : 'Explore this legendary location and uncover its secrets.',
        );
      }).toList();

      try {
        // Save directly to Firestore (no destructive clear)
        await firebaseService.saveCampaignQuestsToFirestore(taggedBatch);
      } catch (e) {
        debugPrint('[Forge] Failed to save batch to Firestore: $e');
      }

      // Update progress
      _forgeProgress = batchEnd;
      _forgeStatusMessage = 'Forging quests... ($batchEnd/${allDests.length})';
      notifyListeners();

      // Inject this batch into the map immediately
      onQuestsGenerated(taggedBatch);
    }

    _isForging = false;
    _forgeStatusMessage = 'All quests forged!';
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));
    _forgeStatusMessage = '';
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
