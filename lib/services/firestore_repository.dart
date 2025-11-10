// Minimal FirestoreRepository shim
// This file provides a tiny compatibility layer that preserves the
// `FirestoreRepository.instance.getCollectionOnce` and
// `FirestoreRepository.instance.getDocumentOnce` APIs used throughout
// the app. It intentionally performs direct Firestore queries and
// returns the resulting futures. Keep this file small and dependency-free
// aside from `cloud_firestore` so the rest of the codebase continues to
// work without requiring a full repository implementation.

import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreRepository {
	FirestoreRepository._private();

	static final FirestoreRepository instance = FirestoreRepository._private();

	/// Run a query (or collection query) once and return the QuerySnapshot.
	///
	/// `cacheKey` is accepted for compatibility with previous API shapes but
	/// is currently unused. `queryBuilder` should return a ready-to-run
	/// `Query` (for example: `() => FirebaseFirestore.instance.collection('x').where(...)`).
	Future<QuerySnapshot> getCollectionOnce(String cacheKey, Query Function() queryBuilder) async {
		final q = queryBuilder();
		return await q.get();
	}

	/// Run a document fetch once and return the DocumentSnapshot.
	///
	/// `docBuilder` should return a `DocumentReference` (for example:
	/// `() => FirebaseFirestore.instance.collection('users').doc(uid)`).
	Future<DocumentSnapshot> getDocumentOnce(String cacheKey, DocumentReference Function() docBuilder) async {
		final d = docBuilder();
		return await d.get();
	}
}
