import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class QuestNode {
  final String id;
  final String title;
  final double latitude;
  final double longitude;
  bool isUnlocked;
  bool isCompleted;
  
  // New Dynamic Quest Fields
  final String questType;
  final String description;
  final String unlockedLore;
  
  // Trivia specific fields
  final String question;
  final List<String> options;
  
  final int xpReward;

  // Campaign Builder fields
  final bool isMainQuest;  // true = campaign destination, false = scanned side quest
  final int orderIndex;     // sequential order for polyline connection
  final String googlePlaceId; // Google Places API ID for place info lookup
  
  // Helpers
  LatLng get coordinates => LatLng(latitude, longitude);
  String get locationName => title;

  QuestNode({
    required this.id,
    required this.title,
    required this.latitude,
    required this.longitude,
    this.isUnlocked = false,
    this.isCompleted = false,
    this.questType = 'trivia',
    this.description = '',
    this.unlockedLore = '',
    this.question = '',
    this.options = const [],
    this.xpReward = 50,
    this.isMainQuest = false,
    this.orderIndex = 0,
    this.googlePlaceId = '',
  });

  factory QuestNode.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuestNode(
      id: doc.id,
      title: data['title'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      isUnlocked: data['isUnlocked'] ?? false,
      isCompleted: data['is_completed'] ?? false,
      questType: data['quest_type'] ?? 'trivia',
      description: data['description'] ?? '',
      unlockedLore: data['unlocked_lore'] ?? '',
      question: data['question'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      xpReward: data['xp_reward'] ?? 50,
      isMainQuest: data['is_main_quest'] ?? false,
      orderIndex: data['order_index'] ?? 0,
      googlePlaceId: data['google_place_id'] ?? '',
    );
  }

  factory QuestNode.fromJson(Map<String, dynamic> data) {
    // Support both nested coordinates (API response) and flat fields (Firestore docs)
    double lat = 0;
    double lng = 0;
    if (data['coordinates'] != null) {
      lat = (data['coordinates']['lat'] ?? 0).toDouble();
      lng = (data['coordinates']['lng'] ?? 0).toDouble();
    } else {
      lat = (data['location_lat'] ?? data['latitude'] ?? 0).toDouble();
      lng = (data['location_lng'] ?? data['longitude'] ?? 0).toDouble();
    }

    return QuestNode(
      id: data['location_id'] ?? data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: data['title'] ?? data['location_name'] ?? 'Mystery Quest',
      latitude: lat,
      longitude: lng,
      isCompleted: data['is_completed'] ?? false,
      questType: data['quest_type'] ?? 'trivia',
      description: data['description'] ?? '',
      unlockedLore: data['unlocked_lore'] ?? '',
      question: data['question'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      xpReward: data['xp_reward'] ?? 50,
      isMainQuest: data['is_main_quest'] ?? false,
      orderIndex: data['order_index'] ?? 0,
      googlePlaceId: data['google_place_id'] ?? data['googlePlaceId'] ?? '',
    );
  }

  QuestNode copyWith({
    String? id,
    String? title,
    double? latitude,
    double? longitude,
    bool? isUnlocked,
    bool? isCompleted,
    String? questType,
    String? description,
    String? unlockedLore,
    String? question,
    List<String>? options,
    int? xpReward,
    bool? isMainQuest,
    int? orderIndex,
    String? googlePlaceId,
  }) {
    return QuestNode(
      id: id ?? this.id,
      title: title ?? this.title,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isCompleted: isCompleted ?? this.isCompleted,
      questType: questType ?? this.questType,
      description: description ?? this.description,
      unlockedLore: unlockedLore ?? this.unlockedLore,
      question: question ?? this.question,
      options: options ?? this.options,
      xpReward: xpReward ?? this.xpReward,
      isMainQuest: isMainQuest ?? this.isMainQuest,
      orderIndex: orderIndex ?? this.orderIndex,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
    );
  }

  /// Serialize to Firestore-compatible map
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'latitude': latitude,
      'longitude': longitude,
      'isUnlocked': isUnlocked,
      'is_completed': isCompleted,
      'quest_type': questType,
      'description': description,
      'unlocked_lore': unlockedLore,
      'question': question,
      'options': options,
      'xp_reward': xpReward,
      'is_main_quest': isMainQuest,
      'order_index': orderIndex,
      'google_place_id': googlePlaceId,
    };
  }
}
