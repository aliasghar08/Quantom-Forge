import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';

class FirestoreLibraryRepository {
  final FirebaseFirestore _firestore;
  
  FirestoreLibraryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _libraryCollection => _firestore.collection('library');

  Future<List<ReactionTemplate>> getLibraryTemplates() async {
    try {
      final snapshot = await _libraryCollection.get();
      return snapshot.docs.map((doc) {
        return ReactionTemplate.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching library templates: $e');
      return [];
    }
  }

  /// Uploads [kReactionTemplates] to Firestore.
  ///
  /// Returns the number of documents written, or 0 when the write failed. The
  /// caller can therefore report a truthful result instead of assuming success.
  Future<int> seedLibrary(List<ReactionTemplate> templates) async {
    try {
      final batch = _firestore.batch();
      for (final template in templates) {
        final docRef = _libraryCollection.doc(template.id);
        batch.set(docRef, template.toJson());
      }
      await batch.commit();
      debugPrint('Seeded ${templates.length} templates to Firestore.');
      return templates.length;
    } catch (e) {
      debugPrint('Error seeding library: $e');
      return 0;
    }
  }
}
