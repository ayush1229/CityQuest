import 'package:flutter/material.dart';
import 'package:cityquest/models/quest_node.dart';
import 'package:cityquest/services/firebase_service.dart';

class QuestProvider extends ChangeNotifier {
  List<QuestNode> _quests = [];
  QuestNode? _activeQuest;
  bool _isLoading = false;
  String? _error;

  List<QuestNode> get quests => _quests;
  QuestNode? get activeQuest => _activeQuest;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load quest nodes from Firestore; falls back to mock data.
  Future<void> loadQuests(double userLat, double userLng) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final firebaseService = FirebaseService();
      final fetched = await firebaseService.fetchQuestNodes();
      if (fetched.isNotEmpty) {
        _quests = fetched;
      } else {
        _quests = _mockQuests(userLat, userLng);
      }
    } catch (_) {
      _quests = _mockQuests(userLat, userLng);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Unlock a quest node by id.
  void unlockQuest(String id) {
    final idx = _quests.indexWhere((q) => q.id == id);
    if (idx != -1) {
      _quests[idx].isUnlocked = true;
      notifyListeners();
    }
  }

  /// Set the currently active quest (for the popup).
  void setActiveQuest(QuestNode? quest) {
    _activeQuest = quest;
    notifyListeners();
  }

  /// Call the backend AI to generate a new quest at the user's location.
  /// Adds the returned quest to the list, or does nothing on failure.
  Future<QuestNode?> fetchQuestFromAI(double lat, double lng) async {
    try {
      final firebaseService = FirebaseService();
      final quest = await firebaseService.generateQuest(lat, lng);
      if (quest != null) {
        _quests.add(quest);
        notifyListeners();
      }
      return quest;
    } catch (_) {
      return null;
    }
  }

  /// Generate mock quest nodes placed around the user's location.
  List<QuestNode> _mockQuests(double userLat, double userLng) {
    return [
      QuestNode(
        id: '1',
        title: 'India Gate',
        latitude: userLat + 0.0003,
        longitude: userLng + 0.0004,
        question: 'In which year was India Gate inaugurated?',
        options: ['1921', '1931', '1947', '1950'],
        correctAnswer: '1931',
        xpReward: 50,
      ),
      QuestNode(
        id: '2',
        title: 'Red Fort',
        latitude: userLat - 0.0004,
        longitude: userLng + 0.0002,
        question: 'Who built the Red Fort?',
        options: ['Akbar', 'Shah Jahan', 'Aurangzeb', 'Babur'],
        correctAnswer: 'Shah Jahan',
        xpReward: 60,
      ),
      QuestNode(
        id: '3',
        title: 'City Museum',
        latitude: userLat + 0.0002,
        longitude: userLng - 0.0003,
        question: 'What is the oldest artifact in the City Museum?',
        options: [
          'Bronze statue',
          'Clay pottery',
          'Stone tablet',
          'Iron sword',
        ],
        correctAnswer: 'Clay pottery',
        xpReward: 40,
      ),
      QuestNode(
        id: '4',
        title: 'Park Fountain',
        latitude: userLat - 0.0002,
        longitude: userLng - 0.0004,
        question: 'When was the Park Fountain renovated?',
        options: ['2005', '2010', '2015', '2020'],
        correctAnswer: '2015',
        xpReward: 30,
      ),
      QuestNode(
        id: '5',
        title: 'Heritage Library',
        latitude: userLat + 0.0005,
        longitude: userLng - 0.0001,
        question: 'How many books does the Heritage Library hold?',
        options: ['10,000', '50,000', '100,000', '200,000'],
        correctAnswer: '100,000',
        xpReward: 55,
      ),
    ];
  }
}
