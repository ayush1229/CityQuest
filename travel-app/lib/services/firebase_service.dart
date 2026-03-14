import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  /// Sign in with Google. Links credentials to current anonymous account.
  Future<User?> signInWithGoogle() async {
    if (!isInitialized) return null;
    try {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final currentUser = FirebaseAuth.instance.currentUser;
      UserCredential result;

      if (currentUser != null && currentUser.isAnonymous) {
        // Link Google account to anonymous user to preserve data
        result = await currentUser.linkWithCredential(credential);
      } else {
        result = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      return result.user;
    } catch (e) {
      print('signInWithGoogle error: $e');
      // If linking fails (already linked), try signing in directly
      try {
        final googleSignIn = GoogleSignIn();
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) return null;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final result = await FirebaseAuth.instance.signInWithCredential(credential);
        return result.user;
      } catch (e2) {
        print('signInWithGoogle fallback error: $e2');
        return null;
      }
    }
  }

  /// Claim login bonus XP (200 XP)
  Future<Map<String, dynamic>> claimLoginBonus() async {
    if (!isInitialized) return {'success': false};
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('claimLoginBonus')
          .call({});
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      print('claimLoginBonus error: $e');
      return {'success': false, 'error': e.toString()};
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

  /// Retrieve all active quest documents assigned to the user.
  Future<List<QuestNode>> fetchActiveQuests() async {
    if (!isInitialized) return [];
    final user = currentUser;
    if (user == null) return [];

    try {
      // Check new subcollection first
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('active_quests')
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          if (data.containsKey('location_id')) {
             data['id'] = data['location_id'];
          }
          return QuestNode.fromJson(data);
        }).toList();
      }

      // Fallback for legacy test data if any
      final legacyDoc = await FirebaseFirestore.instance
          .collection('active_quests')
          .doc(user.uid)
          .get();

      if (legacyDoc.exists) {
        final data = legacyDoc.data()!;
        data['id'] = legacyDoc.id;
        if (data.containsKey('location_id')) {
           data['id'] = data['location_id'];
        }
        return [QuestNode.fromJson(data)];
      }

      return [];
    } catch (e) {
      print('fetchActiveQuests exception: $e');
      return [];
    }
  }

  /// Call the backend's `generateQuest` Cloud Function with the user's
  /// current GPS coordinates. Returns a list of [QuestNode]s built from the AI
  /// response, or empty list if Firebase is unavailable / the call fails.
  Future<List<QuestNode>> generateQuests(double lat, double lng, {double radius = 500}) async {
    if (!isInitialized) return [];
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('generateQuest')
          .call({'latitude': lat, 'longitude': lng, 'radius': radius});

      final data = Map<String, dynamic>.from(result.data as Map);
      
      if (data.containsKey('quests')) {
         final questsList = List<Map<dynamic, dynamic>>.from(data['quests']);
         return questsList.map((q) => QuestNode.fromJson(Map<String, dynamic>.from(q))).toList();
      }

      return [];
    } on FirebaseFunctionsException catch (e) {
      print('generateQuests error: ${e.code} - ${e.message}');
      return [];
    } catch (e) {
      print('generateQuests exception: $e');
      return [];
    }
  }

  /// Call the backend's `completeQuest` Cloud Function.
  /// Validates the GPS distance (Haversine 50m check) and the selected answer!
  Future<Map<String, dynamic>> completeQuest({
    required String locationId,
    required double lat,
    required double lng,
    String? selectedAnswer,
    bool devMode = false,
  }) async {
    if (!isInitialized) return {'success': false, 'error': 'Firebase not initialized'};
    
    try {
      final Map<String, dynamic> payload = {
        'location_id': locationId,
        'latitude': lat,
        'longitude': lng,
      };
      if (selectedAnswer != null) {
        payload['selected_answer'] = selectedAnswer;
      }
      if (devMode) {
        payload['dev_mode'] = true;
      }

      final result = await FirebaseFunctions.instance
          .httpsCallable('completeQuest')
          .call(payload);

      return {
        'success': true,
        'data': Map<String, dynamic>.from(result.data as Map),
      };
    } on FirebaseFunctionsException catch (e) {
      return {'success': false, 'error': e.message ?? 'Unknown Error'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  /// Call the backend's `getDirections` Cloud Function.
  /// Fetches an encoded polyline route from the origin to the destination.
  Future<String?> fetchRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    if (!isInitialized) return null;

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getDirections')
          .call({
        'originLat': originLat,
        'originLng': originLng,
        'destLat': destLat,
        'destLng': destLng,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      return data['polyline'] as String?;
    } catch (e) {
      print('fetchRoute exception: $e');
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
