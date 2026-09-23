import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/reaction_models.dart';
import 'reaction_repository.dart';

class FirestoreReactionRepository implements ReactionRepository {
  // Getters rather than fields: this repository is constructed in `main()` before
  // the app boots, and touching `FirebaseFirestore.instance` at construction
  // throws `[core/no-app]` whenever `Firebase.initializeApp` has not finished.
  // See `FirebaseAuthService` for the same reasoning.
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  @override
  Future<String> createReaction(Map<String, dynamic> reactionData) async {
    final userId = reactionData['user_id'] ?? _uid;
    if (userId == null || userId.toString().isEmpty) {
      throw Exception('User ID is required to create a reaction in Firestore.');
    }
    reactionData['user_id'] = userId;

    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('reactions')
        .doc(reactionData['reaction_id']);

    final docData = {
      ...reactionData,
      'created_at': FieldValue.serverTimestamp(),
      'state': ReactionState.pending.name,
    };

    await docRef.set(docData);
    return docRef.id;
  }

  @override
  Future<ReactionStatusResponse?> getReaction(String reactionId) async {
    if (_uid == null) return null;
    final docSnap = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('reactions')
        .doc(reactionId)
        .get();

    if (!docSnap.exists) return null;
    return _fromMap(docSnap.data()!, docSnap.id);
  }

  @override
  Future<ReactionStatusResponse?> findCachedTemplateReaction(String templateId, Map<String, dynamic> settingsMap) async {
    // Look only inside the current user's own reactions. The previous
    // implementation used a collection-group query across every user, which the
    // per-user security rules correctly reject (cross-user reads are denied).
    // A single-field equality filter also avoids needing a composite index.
    final uid = _uid;
    if (uid == null) return null;

    final query = await _firestore
        .collection('users')
        .doc(uid)
        .collection('reactions')
        .where('template_id', isEqualTo: templateId)
        .get();

    for (var doc in query.docs) {
      final data = doc.data();
      if (data['state'] != ReactionState.completed.name) continue;
      bool settingsMatch = true;
      for (var key in settingsMap.keys) {
        if (data[key] != settingsMap[key]) {
          settingsMatch = false;
          break;
        }
      }
      if (settingsMatch) {
        return _fromMap(data, doc.id);
      }
    }
    return null;
  }

  @override
  Future<void> updateReaction(String reactionId, Map<String, dynamic> fields) async {
    if (_uid == null) return;
    final docRef = _firestore
        .collection('users')
        .doc(_uid)
        .collection('reactions')
        .doc(reactionId);

    final updateData = {
      ...fields,
      'updated_at': FieldValue.serverTimestamp(),
    };
    await docRef.update(updateData);
  }

  @override
  Stream<ReactionStatusResponse> watchReaction(String reactionId) {
    if (_uid == null) return const Stream.empty();
    
    final docRef = _firestore
        .collection('users')
        .doc(_uid)
        .collection('reactions')
        .doc(reactionId);

    return docRef.snapshots().map((snap) {
      if (snap.exists && snap.data() != null) {
        return _fromMap(snap.data()!, snap.id);
      }
      throw Exception('Reaction not found');
    });
  }

  @override
  Future<List<ReactionStatusResponse>> listReactions(String userId) async {
    final query = await _firestore
        .collection('users')
        .doc(userId)
        .collection('reactions')
        .orderBy('created_at', descending: true)
        .get();

    return query.docs.map((doc) => _fromMap(doc.data(), doc.id)).toList();
  }

  @override
  Future<void> deleteReaction(String reactionId) async {
    if (_uid == null) return;
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('reactions')
        .doc(reactionId)
        .delete();
  }

  static ReactionStatusResponse _fromMap(Map<String, dynamic> data, String docId) {
    final reactionStateStr = data['state'] as String? ?? ReactionState.pending.name;
    final stateEnum = ReactionState.values.firstWhere(
      (e) => e.name == reactionStateStr,
      orElse: () => ReactionState.error,
    );
    final energyRaw = data['energy_profile'] as List<dynamic>?;
    final framesRaw = data['trajectory_frames'] as List<dynamic>?;

    DateTime? createdAt;
    if (data['created_at'] is Timestamp) {
      createdAt = (data['created_at'] as Timestamp).toDate();
    } else if (data['created_at'] != null) {
      createdAt = DateTime.tryParse(data['created_at'].toString());
    }

    return ReactionStatusResponse(
      reactionId: data['reaction_id'] as String? ?? docId,
      state: stateEnum,
      progress: (data['progress'] as num?)?.toDouble() ?? 0.0,
      message: data['message'] as String?,
      energyProfile: energyRaw?.map((e) => (e as num).toDouble()).toList(),
      trajectoryFrames: framesRaw?.map((e) => e.toString()).toList(),
      createdAt: createdAt,
    );
  }
}
