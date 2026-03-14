import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cityquest/models/quest_node.dart';

/// Represents a single level in a campaign progression.
/// Level N is locked until all quests in Level N-1 are completed.
class CampaignLevel {
  final int levelNumber;
  final List<QuestNode> destinations;

  CampaignLevel({
    required this.levelNumber,
    List<QuestNode>? destinations,
  }) : destinations = destinations ?? [];

  /// True only if every quest in this level has isCompleted == true
  /// and the level has at least one quest.
  bool get isCompleted =>
      destinations.isNotEmpty && destinations.every((q) => q.isCompleted);

  Map<String, dynamic> toMap() {
    return {
      'level_number': levelNumber,
      'destinations': destinations.map((d) => d.toMap()).toList(),
    };
  }

  factory CampaignLevel.fromMap(Map<String, dynamic> data) {
    final destList = data['destinations'] as List<dynamic>? ?? [];
    return CampaignLevel(
      levelNumber: data['level_number'] ?? 1,
      destinations: destList
          .map((d) => QuestNode.fromJson(Map<String, dynamic>.from(d)))
          .toList(),
    );
  }

  CampaignLevel copyWith({int? levelNumber, List<QuestNode>? destinations}) {
    return CampaignLevel(
      levelNumber: levelNumber ?? this.levelNumber,
      destinations: destinations ?? List.from(this.destinations),
    );
  }
}

/// Represents a full multi-level campaign (trip itinerary).
class Campaign {
  final String id;
  final String userId;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final List<CampaignLevel> levels;
  final DateTime createdAt;

  Campaign({
    required this.id,
    required this.userId,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.levels,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Total number of destinations across all levels.
  int get totalDestinations =>
      levels.fold(0, (sum, level) => sum + level.destinations.length);

  /// All main quest nodes flattened, sorted by orderIndex.
  List<QuestNode> get allMainQuests {
    final quests = <QuestNode>[];
    for (final level in levels) {
      quests.addAll(level.destinations);
    }
    quests.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return quests;
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'title': title,
      'start_date': Timestamp.fromDate(startDate),
      'end_date': Timestamp.fromDate(endDate),
      'levels': levels.map((l) => l.toMap()).toList(),
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  factory Campaign.fromMap(String docId, Map<String, dynamic> data) {
    final levelsList = data['levels'] as List<dynamic>? ?? [];
    return Campaign(
      id: docId,
      userId: data['user_id'] ?? '',
      title: data['title'] ?? 'Untitled Campaign',
      startDate: (data['start_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['end_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      levels: levelsList
          .map((l) => CampaignLevel.fromMap(Map<String, dynamic>.from(l)))
          .toList(),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Campaign copyWith({
    String? id,
    String? userId,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    List<CampaignLevel>? levels,
  }) {
    return Campaign(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      levels: levels ?? this.levels.map((l) => l.copyWith()).toList(),
      createdAt: createdAt,
    );
  }

  /// JSON-safe serialization (for SharedPreferences draft).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'levels': levels.map((l) => l.toMap()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Campaign.fromJson(Map<String, dynamic> data) {
    final levelsList = data['levels'] as List<dynamic>? ?? [];
    return Campaign(
      id: data['id'] ?? '',
      userId: data['user_id'] ?? '',
      title: data['title'] ?? 'Untitled Campaign',
      startDate: DateTime.tryParse(data['start_date'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(data['end_date'] ?? '') ?? DateTime.now(),
      levels: levelsList
          .map((l) => CampaignLevel.fromMap(Map<String, dynamic>.from(l)))
          .toList(),
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
