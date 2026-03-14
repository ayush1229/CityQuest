import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cityquest/models/quest_node.dart';

/// Represents a single day in a campaign itinerary.
class DayPlan {
  final int dayNumber;
  final List<QuestNode> destinations;

  DayPlan({
    required this.dayNumber,
    List<QuestNode>? destinations,
  }) : destinations = destinations ?? [];

  Map<String, dynamic> toMap() {
    return {
      'day_number': dayNumber,
      'destinations': destinations.map((d) => d.toMap()).toList(),
    };
  }

  factory DayPlan.fromMap(Map<String, dynamic> data) {
    final destList = data['destinations'] as List<dynamic>? ?? [];
    return DayPlan(
      dayNumber: data['day_number'] ?? 1,
      destinations: destList
          .map((d) => QuestNode.fromJson(Map<String, dynamic>.from(d)))
          .toList(),
    );
  }

  DayPlan copyWith({int? dayNumber, List<QuestNode>? destinations}) {
    return DayPlan(
      dayNumber: dayNumber ?? this.dayNumber,
      destinations: destinations ?? List.from(this.destinations),
    );
  }
}

/// Represents a full multi-day campaign (trip itinerary).
class Campaign {
  final String id;
  final String userId;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final List<DayPlan> days;
  final DateTime createdAt;

  Campaign({
    required this.id,
    required this.userId,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.days,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Total number of destinations across all days.
  int get totalDestinations =>
      days.fold(0, (sum, day) => sum + day.destinations.length);

  /// All main quest nodes flattened, sorted by orderIndex.
  List<QuestNode> get allMainQuests {
    final quests = <QuestNode>[];
    for (final day in days) {
      quests.addAll(day.destinations);
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
      'days': days.map((d) => d.toMap()).toList(),
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  factory Campaign.fromMap(String docId, Map<String, dynamic> data) {
    final daysList = data['days'] as List<dynamic>? ?? [];
    return Campaign(
      id: docId,
      userId: data['user_id'] ?? '',
      title: data['title'] ?? 'Untitled Campaign',
      startDate: (data['start_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['end_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      days: daysList
          .map((d) => DayPlan.fromMap(Map<String, dynamic>.from(d)))
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
    List<DayPlan>? days,
  }) {
    return Campaign(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      days: days ?? this.days.map((d) => d.copyWith()).toList(),
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
      'days': days.map((d) => d.toMap()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Campaign.fromJson(Map<String, dynamic> data) {
    final daysList = data['days'] as List<dynamic>? ?? [];
    return Campaign(
      id: data['id'] ?? '',
      userId: data['user_id'] ?? '',
      title: data['title'] ?? 'Untitled Campaign',
      startDate: DateTime.tryParse(data['start_date'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(data['end_date'] ?? '') ?? DateTime.now(),
      days: daysList
          .map((d) => DayPlan.fromMap(Map<String, dynamic>.from(d)))
          .toList(),
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
