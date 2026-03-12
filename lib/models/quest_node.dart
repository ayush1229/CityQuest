import 'package:cloud_firestore/cloud_firestore.dart';

class QuestNode {
  final String id;
  final String title;
  final double latitude;
  final double longitude;
  bool isUnlocked;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final int xpReward;

  QuestNode({
    required this.id,
    required this.title,
    required this.latitude,
    required this.longitude,
    this.isUnlocked = false,
    this.question = '',
    this.options = const [],
    this.correctAnswer = '',
    this.xpReward = 50,
  });

  factory QuestNode.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuestNode(
      id: doc.id,
      title: data['title'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      isUnlocked: data['isUnlocked'] ?? false,
      question: data['question'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctAnswer: data['correctAnswer'] ?? '',
      xpReward: data['xpReward'] ?? 50,
    );
  }

  QuestNode copyWith({
    String? id,
    String? title,
    double? latitude,
    double? longitude,
    bool? isUnlocked,
    String? question,
    List<String>? options,
    String? correctAnswer,
    int? xpReward,
  }) {
    return QuestNode(
      id: id ?? this.id,
      title: title ?? this.title,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      question: question ?? this.question,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      xpReward: xpReward ?? this.xpReward,
    );
  }
}
