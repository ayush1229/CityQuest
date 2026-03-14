class LoreEntry {
  final String id;
  final String title;
  final String locationName;
  final String description;
  final String questType;
  final String exploredDate;
  final double latitude;
  final double longitude;
  final bool isHardcoded;

  LoreEntry({
    required this.id,
    required this.title,
    required this.locationName,
    this.description = '',
    this.questType = 'discovery',
    this.exploredDate = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.isHardcoded = false,
  });

  factory LoreEntry.fromFirestore(Map<String, dynamic> data) {
    return LoreEntry(
      id: data['location_id'] ?? data['id'] ?? '',
      title: data['title'] ?? 'Unknown Place',
      locationName: data['location_name'] ?? data['title'] ?? '',
      description: data['description'] ?? data['unlocked_lore'] ?? '',
      questType: data['quest_type'] ?? 'discovery',
      exploredDate: data['date'] ?? '',
      latitude: (data['location_lat'] ?? 0).toDouble(),
      longitude: (data['location_lng'] ?? 0).toDouble(),
      isHardcoded: false,
    );
  }
}
