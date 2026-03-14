import 'package:flutter/material.dart';
import 'package:cityquest/models/user_profile.dart';
import 'package:cityquest/services/firebase_service.dart';

class UserProvider extends ChangeNotifier {
  UserProfile _profile = const UserProfile(uid: 'guest');
  bool _isLoading = false;
  String? _error;

  UserProfile get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load profile from Firestore, or use defaults.
  Future<void> loadProfile(String uid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final firebaseService = FirebaseService();
      final fetched = await firebaseService.fetchUserProfile(uid);
      _profile = fetched ?? UserProfile(uid: uid);
    } catch (_) {
      _profile = UserProfile(uid: uid);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Add XP and auto-level-up.
  void addXp(int amount) {
    int newXp = _profile.xp + amount;
    int newLevel = _profile.level;

    // Level up check
    while (newXp >= newLevel * 100) {
      newXp -= newLevel * 100;
      newLevel++;
    }

    _profile = _profile.copyWith(
      xp: newXp + _cumulativeXpForLevel(newLevel - 1),
      level: newLevel,
    );
    notifyListeners();
  }

  int _cumulativeXpForLevel(int lvl) {
    return (lvl * (lvl + 1) * 100) ~/ 2;
  }

  /// Mark a quest as completed and add the landmark.
  void completeQuest(String landmarkName) {
    final updated = List<String>.from(_profile.visitedLandmarks);
    if (!updated.contains(landmarkName)) {
      updated.add(landmarkName);
    }
    _profile = _profile.copyWith(
      completedQuests: _profile.completedQuests + 1,
      visitedLandmarks: updated,
    );
    notifyListeners();
  }
}
