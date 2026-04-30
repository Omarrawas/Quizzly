import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';

class FavoriteService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference? get _favoritesCol {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('favorites');
  }

  /// Toggles favorite status in Firestore
  Future<void> toggleFavorite(QuizQuestion question) async {
    final col = _favoritesCol;
    final qId = question.id;
    if (col == null || qId == null) return;

    final docRef = col.doc(qId);
    final doc = await docRef.get();

    if (doc.exists) {
      await docRef.delete();
    } else {
      await docRef.set({
        'questionId': qId,
        'questionData': question.toMap(),
        'savedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Stream of all favorite question IDs for the current user
  Stream<Set<String>> streamFavoriteIds() {
    final col = _favoritesCol;
    if (col == null) return Stream.value({});
    
    return col.snapshots().map((snap) {
      return snap.docs.map((doc) => doc.id).toSet();
    });
  }

  /// Check if a specific question is favorited (once)
  Future<bool> isFavorited(String questionId) async {
    final col = _favoritesCol;
    if (col == null) return false;
    
    final doc = await col.doc(questionId).get();
    return doc.exists;
  }
}
