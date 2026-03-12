import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cityquest/models/quest_node.dart';
import 'package:cityquest/models/user_profile.dart';

class FirebaseService {
  /// Whether Firebase has been successfully initialized.
  static bool get isInitialized {
    try {
      Firebase.app();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Current Firebase user (may be null).
  User? get currentUser {
    if (!isInitialized) return null;
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Sign in anonymously. Returns the [User] on success.
  Future<User?> signInAnonymously() async {
    if (!isInitialized) return null;
    try {
      final credential = await FirebaseAuth.instance.signInAnonymously();
      return credential.user;
    } catch (e) {
      return null;
    }
  }

  /// Fetch all quest nodes from Firestore.
  Future<List<QuestNode>> fetchQuestNodes() async {
    if (!isInitialized) return [];
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('quest_nodes').get();
      return snapshot.docs.map((d) => QuestNode.fromFirestore(d)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Call the backend's `generateQuest` Cloud Function with the user's
  /// current GPS coordinates. Returns a [QuestNode] built from the AI
  /// response, or `null` if Firebase is unavailable / the call fails.
  Future<QuestNode?> generateQuest(double lat, double lng) async {
    if (!isInitialized) return null;
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('generateQuest')
          .call({'latitude': lat, 'longitude': lng});

      final data = result.data as Map<String, dynamic>;

      return QuestNode(
        id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: data['title'] ?? 'Mystery Quest',
        latitude: (data['latitude'] ?? lat).toDouble(),
        longitude: (data['longitude'] ?? lng).toDouble(),
        question: data['question'] ?? '',
        options: List<String>.from(data['options'] ?? []),
        correctAnswer: data['correctAnswer'] ?? '',
        xpReward: data['xpReward'] ?? 50,
      );
    } on FirebaseFunctionsException catch (_) {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetch user profile from Firestore.
  Future<UserProfile?> fetchUserProfile(String uid) async {
    if (!isInitialized) return null;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserProfile.fromFirestore(doc);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
