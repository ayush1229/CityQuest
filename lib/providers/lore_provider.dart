import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cityquest/models/lore_entry.dart';

class LoreProvider extends ChangeNotifier {
  List<LoreEntry> _entries = [];
  bool _isLoading = false;

  List<LoreEntry> get entries => _entries;
  bool get isLoading => _isLoading;

  /// Hardcoded NIT Hamirpur lore entries — always visible as baseline content.
  static final List<LoreEntry> _hardcodedEntries = [
    LoreEntry(
      id: 'nit_main_gate',
      title: 'The Gateway to Knowledge',
      locationName: 'NIT Hamirpur Main Gate',
      description:
          'National Institute of Technology Hamirpur was established in 1986 as Regional Engineering College. '
          'Perched at an altitude of ~900m in the Shivalik range of the Himalayas, it is one of India\'s '
          '31 NITs. The main gate marks the entrance to a 320-acre campus surrounded by pine forests and '
          'panoramic views of the Dhauladhar range.',
      questType: 'discovery',
      exploredDate: 'Historic',
      latitude: 31.7080,
      longitude: 76.5270,
      isHardcoded: true,
    ),
    LoreEntry(
      id: 'nit_cse',
      title: 'Heart of Innovation',
      locationName: 'Computer Science Department',
      description:
          'The Computer Science & Engineering department at NIT Hamirpur has produced numerous startup '
          'founders, competitive programmers, and tech leaders. The department houses state-of-the-art '
          'labs including AI/ML research facilities, and its students have represented India at ICPC '
          'World Finals multiple times.',
      questType: 'discovery',
      exploredDate: 'Historic',
      latitude: 31.7065,
      longitude: 76.5269,
      isHardcoded: true,
    ),
    LoreEntry(
      id: 'nit_library',
      title: 'Library Lore',
      locationName: 'Central Library',
      description:
          'The Central Library of NIT Hamirpur houses over 1,00,000 books, journals, and digital '
          'resources. It was among the first NIT libraries to adopt a fully automated library management '
          'system. Students often gather here during exam seasons, and the reading hall offers stunning '
          'views of the surrounding mountains.',
      questType: 'trivia',
      exploredDate: 'Historic',
      latitude: 31.7088,
      longitude: 76.5271,
      isHardcoded: true,
    ),
    LoreEntry(
      id: 'nit_sac',
      title: 'The Hidden Hub',
      locationName: 'Student Activity Centre (SAC)',
      description:
          'The Student Activity Centre is the beating heart of campus culture. Home to robotics clubs, '
          'debating societies, music rooms, and the famous annual tech festival "Nimbus". Every major '
          'cultural and technical event at NIT Hamirpur traces its roots back to SAC.',
      questType: 'exploration',
      exploredDate: 'Historic',
      latitude: 31.7095,
      longitude: 76.5280,
      isHardcoded: true,
    ),
    LoreEntry(
      id: 'nit_aryabhatta',
      title: 'Aryabhatta House',
      locationName: 'Aryabhatta Hostel',
      description:
          'Named after the legendary Indian mathematician, Aryabhatta Hostel is one of the oldest '
          'hostels on campus. It has hosted generations of engineers who went on to work at companies '
          'like Google, Microsoft, and Amazon. The hostel is famous for its night canteen and rooftop views.',
      questType: 'discovery',
      exploredDate: 'Historic',
      latitude: 31.7072,
      longitude: 76.5265,
      isHardcoded: true,
    ),
  ];

  /// Load lore entries — hardcoded first, then merge with Firestore completed_quests.
  Future<void> loadLoreEntries() async {
    _isLoading = true;
    notifyListeners();

    // Start with hardcoded entries
    _entries = List.from(_hardcodedEntries);

    // Fetch from Firestore
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('completed_quests')
            .where('userId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final entry = LoreEntry.fromFirestore(data);

          // Avoid duplicating hardcoded entries
          if (!_entries.any((e) => e.id == entry.id)) {
            _entries.add(entry);
          }
        }
      }
    } catch (e) {
      debugPrint('LoreProvider.loadLoreEntries error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Add a lore entry in real-time after quest completion (no re-fetch needed).
  void addLoreEntry(LoreEntry entry) {
    if (!_entries.any((e) => e.id == entry.id)) {
      _entries.insert(0, entry);
      notifyListeners();
    }
  }
}
