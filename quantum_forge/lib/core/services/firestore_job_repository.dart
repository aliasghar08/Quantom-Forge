import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quantum_forge/features/job_runner/data/models/job_models.dart';
import 'job_repository.dart';

class FirestoreJobRepository implements JobRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<String> createJob(Map<String, dynamic> jobData) async {
    final userId = jobData['user_id'];
    if (userId == null || userId.toString().isEmpty) {
      throw Exception('User ID is required to create a job in Firestore.');
    }

    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('jobs')
        .doc(jobData['job_id']);

    final docData = {
      ...jobData,
      'created_at': FieldValue.serverTimestamp(),
      'state': JobState.pending.name,
    };

    await docRef.set(docData);
    return docRef.id;
  }

  @override
  Future<JobStatusResponse?> getJob(String jobId) async {
    // We cannot get a job without a userId unless we use a collection group query.
    // In our architecture, the job might be requested without user context directly if not careful,
    // but typically we can query across all jobs if necessary. 
    // Assuming the user is signed in, we can query by collectionGroup or require userId.
    // For simplicity, let's use a collectionGroup query to find the job by ID.
    final query = await _firestore
        .collectionGroup('jobs')
        .where('job_id', isEqualTo: jobId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return _fromMap(query.docs.first.data(), query.docs.first.id);
  }

  @override
  Future<void> updateJob(String jobId, Map<String, dynamic> fields) async {
    final query = await _firestore
        .collectionGroup('jobs')
        .where('job_id', isEqualTo: jobId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return;

    final docRef = query.docs.first.reference;
    final updateData = {
      ...fields,
      'updated_at': FieldValue.serverTimestamp(),
    };
    await docRef.update(updateData);
  }

  @override
  Stream<JobStatusResponse> watchJob(String jobId) {
    // Firestore streams on a collection group require an index if querying by fields,
    // but just mapping a snapshot is easier if we find the doc first.
    // To keep it simple and real-time without an index, we fetch the doc ref first.
    
    // We create a controller to manage the stream because we need to asynchronously find the doc first.
    final controller = StreamController<JobStatusResponse>();
    
    _firestore
        .collectionGroup('jobs')
        .where('job_id', isEqualTo: jobId)
        .limit(1)
        .get()
        .then((query) {
      if (query.docs.isEmpty) {
        controller.close();
        return;
      }
      final docRef = query.docs.first.reference;
      final sub = docRef.snapshots().listen((snap) {
        if (snap.exists && snap.data() != null) {
          controller.add(_fromMap(snap.data()!, snap.id));
        }
      });
      controller.onCancel = () => sub.cancel();
    });

    return controller.stream;
  }

  @override
  Future<List<JobStatusResponse>> listJobs(String userId) async {
    final query = await _firestore
        .collection('users')
        .doc(userId)
        .collection('jobs')
        .orderBy('created_at', descending: true)
        .get();

    return query.docs.map((doc) => _fromMap(doc.data(), doc.id)).toList();
  }

  @override
  Future<void> deleteJob(String jobId) async {
    final query = await _firestore
        .collectionGroup('jobs')
        .where('job_id', isEqualTo: jobId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.delete();
    }
  }

  static JobStatusResponse _fromMap(Map<String, dynamic> data, String docId) {
    final jobStateStr = data['state'] as String? ?? JobState.pending.name;
    final stateEnum = JobState.values.firstWhere(
      (e) => e.name == jobStateStr,
      orElse: () => JobState.error,
    );
    final energyRaw = data['energy_profile'] as List<dynamic>?;
    final framesRaw = data['trajectory_frames'] as List<dynamic>?;

    DateTime? createdAt;
    if (data['created_at'] is Timestamp) {
      createdAt = (data['created_at'] as Timestamp).toDate();
    } else if (data['created_at'] != null) {
      createdAt = DateTime.tryParse(data['created_at'].toString());
    }

    return JobStatusResponse(
      jobId: data['job_id'] as String? ?? docId,
      state: stateEnum,
      progress: (data['progress'] as num?)?.toDouble() ?? 0.0,
      message: data['message'] as String?,
      energyProfile: energyRaw?.map((e) => (e as num).toDouble()).toList(),
      trajectoryFrames: framesRaw?.map((e) => e.toString()).toList(),
      createdAt: createdAt,
    );
  }
}
