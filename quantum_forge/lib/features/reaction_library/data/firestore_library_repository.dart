import 'package:cloud_firestore/cloud_firestore.dart';
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
      print('Error fetching library templates: $e');
      return [];
    }
  }

  Future<void> seedLibrary(List<ReactionTemplate> templates) async {
    try {
      final batch = _firestore.batch();
      for (final template in templates) {
        final docRef = _libraryCollection.doc(template.id);
        batch.set(docRef, template.toJson());
      }
      await batch.commit();
      print('Successfully seeded \${templates.length} templates to Firestore.');
    } catch (e) {
      print('Error seeding library: $e');
    }
  }
}
