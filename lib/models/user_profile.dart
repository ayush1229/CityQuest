import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final int level;
  final int xp;
  final int completedQuests;
  final List<String> visitedLandmarks;

  const UserProfile({
    required this.uid,
    this.level = 1,
    this.xp = 0,
    this.completedQuests = 0,
    this.visitedLandmarks = const [],
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      level: data['level'] ?? 1,
      xp: data['xp'] ?? 0,
      completedQuests: data['completedQuests'] ?? 0,
      visitedLandmarks: List<String>.from(data['visitedLandmarks'] ?? []),
    );
  }

  /// XP required for the next level (100 per level).
  int get xpForNextLevel => level * 100;

  /// Progress fraction toward the next level [0.0 – 1.0].
  double get levelProgress {
    final xpInLevel = xp - _cumulativeXpForLevel(level - 1);
    return (xpInLevel / xpForNextLevel).clamp(0.0, 1.0);
  }

  int _cumulativeXpForLevel(int lvl) {
    // Sum of 100 + 200 + ... + lvl*100
    return (lvl * (lvl + 1) * 100) ~/ 2;
  }

  String get levelTitle {
    if (level <= 2) return 'Novice';
    if (level <= 5) return 'Explorer';
    if (level <= 10) return 'Adventurer';
    if (level <= 20) return 'Pathfinder';
    return 'Legend';
  }

  UserProfile copyWith({
    String? uid,
    int? level,
    int? xp,
    int? completedQuests,
    List<String>? visitedLandmarks,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      completedQuests: completedQuests ?? this.completedQuests,
      visitedLandmarks: visitedLandmarks ?? this.visitedLandmarks,
    );
  }
}
