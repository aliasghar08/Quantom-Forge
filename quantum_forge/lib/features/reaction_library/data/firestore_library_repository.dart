import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';

/// Result page returned by paginated queries.
class LibraryPage {
  final List<ReactionTemplate> items;

  /// Firestore cursor for the next page. Null when this is the last page.
  final DocumentSnapshot? nextCursor;

  const LibraryPage({required this.items, this.nextCursor});

  bool get hasMore => nextCursor != null;
}

class FirestoreLibraryRepository {
  /// An explicitly supplied client, or null to resolve the default lazily.
  final FirebaseFirestore? _injected;

  FirestoreLibraryRepository({FirebaseFirestore? firestore})
      : _injected = firestore;

  FirebaseFirestore get _firestore => _injected ?? FirebaseFirestore.instance;

  CollectionReference get _col => _firestore.collection('library');

  // ── Page size ──────────────────────────────────────────────────────────────

  /// Number of cards loaded per page. Small enough for fast first-paint,
  /// large enough that the user rarely needs to scroll before the next load.
  static const int pageSize = 24;

  // ── Pagination ─────────────────────────────────────────────────────────────

  /// First page of templates, optionally filtered by [category].
  ///
  /// Firestore index required:
  ///   Collection: library
  ///   Fields: category ASC, name ASC    (composite, for category-filtered pages)
  ///           name ASC                  (single-field, for unfiltered pages)
  Future<LibraryPage> getPage({
    ReactionCategory? category,
    DocumentSnapshot? after,
  }) async {
    try {
      Query<Object?> q = _col.orderBy('name').limit(pageSize);
      if (category != null) {
        q = _col
            .where('category', isEqualTo: category.name)
            .orderBy('name')
            .limit(pageSize);
      }
      if (after != null) q = q.startAfterDocument(after);

      final snap = await q.get();
      final items = snap.docs
          .map((d) =>
              ReactionTemplate.fromJson(d.data() as Map<String, dynamic>, d.id))
          .toList();

      final cursor = snap.docs.length == pageSize ? snap.docs.last : null;
      return LibraryPage(items: items, nextCursor: cursor);
    } catch (e) {
      debugPrint('FirestoreLibraryRepository.getPage error: $e');
      return const LibraryPage(items: []);
    }
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  /// Name-prefix search against Firestore indexes.
  ///
  /// Firestore index required:
  ///   Collection: library
  ///   Fields: category ASC, name ASC    (for category + query)
  ///           name ASC                  (for query only)
  ///
  /// NOTE: Firestore does NOT support full-text search. This is a prefix match
  /// on the `name` field, which covers the vast majority of use cases (e.g.
  /// "Diels" → "Diels-Alder Reaction"). For tag search we use the `tags` array
  /// contains query as a separate fallback.
  Future<List<ReactionTemplate>> search(
    String query, {
    ReactionCategory? category,
    int limit = pageSize,
  }) async {
    if (query.trim().isEmpty) {
      final page = await getPage(category: category);
      return page.items;
    }
    final q = query.trim();
    try {
      final results = <ReactionTemplate>[];
      final seen = <String>{};

      // 1. Prefix match on name
      Query<Object?> nameQ = _col
          .where('name', isGreaterThanOrEqualTo: q)
          .where('name', isLessThanOrEqualTo: '$q\uf8ff')
          .limit(limit);
      if (category != null) {
        nameQ = nameQ.where('category', isEqualTo: category.name);
      }
      final nameSnap = await nameQ.get();
      for (final d in nameSnap.docs) {
        if (seen.add(d.id)) {
          results.add(ReactionTemplate.fromJson(
              d.data() as Map<String, dynamic>, d.id));
        }
      }

      // 2. Tag array-contains (runs in parallel conceptually, but sequentially
      //    here to avoid blowing the Firestore read quota on every keystroke)
      if (results.length < limit) {
        Query<Object?> tagQ =
            _col.where('tags', arrayContains: q.toLowerCase()).limit(limit);
        if (category != null) {
          tagQ = tagQ.where('category', isEqualTo: category.name);
        }
        final tagSnap = await tagQ.get();
        for (final d in tagSnap.docs) {
          if (seen.add(d.id)) {
            results.add(ReactionTemplate.fromJson(
                d.data() as Map<String, dynamic>, d.id));
          }
        }
      }

      return results;
    } catch (e) {
      debugPrint('FirestoreLibraryRepository.search error: $e');
      return [];
    }
  }

  // ── Count ──────────────────────────────────────────────────────────────────

  /// Total documents in the library collection via Firestore aggregation.
  /// One read, zero documents downloaded.
  Future<int> getTotalCount() async {
    try {
      final result = await _col.count().get();
      return result.count ?? 0;
    } catch (e) {
      debugPrint('FirestoreLibraryRepository.getTotalCount error: $e');
      return -1;
    }
  }

  // ── Seeding (admin / first-run only) ──────────────────────────────────────

  /// Writes [templates] to Firestore in 500-document batches.
  ///
  /// This should only be called once (first run / admin tool) and only for the
  /// 41 *curated* templates, NOT the 200 000 generated variants. The generated
  /// variants exist only as in-memory previews on the detail screen and are
  /// never persisted.
  Future<int> seedLibrary(List<ReactionTemplate> templates) async {
    try {
      for (var i = 0; i < templates.length; i += 500) {
        final end = (i + 500).clamp(0, templates.length);
        final chunk = templates.sublist(i, end);
        final batch = _firestore.batch();
        for (final t in chunk) {
          batch.set(_col.doc(t.id), t.toJson());
        }
        await batch.commit();
      }
      debugPrint('Seeded ${templates.length} templates to Firestore.');
      return templates.length;
    } catch (e) {
      debugPrint('FirestoreLibraryRepository.seedLibrary error: $e');
      return 0;
    }
  }

  // ── Legacy compat (kept so existing call sites compile) ───────────────────

  @Deprecated('Use getPage() for paginated access')
  Future<List<ReactionTemplate>> getLibraryTemplates({
    ReactionCategory? category,
    int limit = 50,
  }) async {
    final page = await getPage(category: category);
    return page.items;
  }

  @Deprecated('Use search() instead')
  Future<List<ReactionTemplate>> searchLibraryTemplates(
    String query, {
    ReactionCategory? category,
    int limit = 50,
  }) =>
      search(query, category: category, limit: limit);
}
