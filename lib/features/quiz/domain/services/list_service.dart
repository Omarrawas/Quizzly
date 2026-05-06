import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';

class UserList {
  final String id;
  final String name;
  final int iconCodePoint;
  final bool isSystem;

  UserList({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    this.isSystem = false,
  });

  factory UserList.fromMap(String id, Map<String, dynamic> data) {
    return UserList(
      id: id,
      name: data['name'] ?? '',
      iconCodePoint: data['iconCodePoint'] ?? Icons.list_rounded.codePoint,
      isSystem: data['isSystem'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'iconCodePoint': iconCodePoint,
    'isSystem': isSystem,
  };
}

class ListService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference? get _listsCol {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('user_lists');
  }

  CollectionReference? _questionsCol(String listId) {
    return _listsCol?.doc(listId).collection('questions');
  }

  DocumentReference? get _metaDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('meta').doc('lists_meta');
  }

  /// Initializes default lists if they don't exist
  Future<void> initializeDefaultLists() async {
    final col = _listsCol;
    if (col == null) return;

    final snap = await col.limit(1).get();
    if (snap.docs.isEmpty) {
      final batch = _db.batch();
      batch.set(col.doc('favorites'), {
        'name': 'المفضلة',
        'iconCodePoint': Icons.favorite_rounded.codePoint,
        'isSystem': true,
      });
      batch.set(col.doc('important'), {
        'name': 'مهم',
        'iconCodePoint': Icons.star_rounded.codePoint,
        'isSystem': true,
      });
      await batch.commit();
      await setPrimaryListId('favorites');
    }
  }

  /// Stream all lists for the user
  Stream<List<UserList>> streamLists() {
    final col = _listsCol;
    if (col == null) return Stream.value([]);
    return col.snapshots().map((snap) => snap.docs.map((doc) => UserList.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList());
  }

  /// Stream primary list ID
  Stream<String> streamPrimaryListId() {
    final meta = _metaDoc;
    if (meta == null) return Stream.value('favorites');
    return meta.snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return (doc.data() as Map<String, dynamic>)['primaryListId'] as String? ?? 'favorites';
      }
      return 'favorites';
    });
  }

  /// Set primary list ID
  Future<void> setPrimaryListId(String listId) async {
    final meta = _metaDoc;
    if (meta == null) return;
    await meta.set({'primaryListId': listId}, SetOptions(merge: true));
  }

  /// Add a custom list
  Future<void> createList(String name, int iconCodePoint) async {
    final col = _listsCol;
    if (col == null) return;
    await col.add({
      'name': name,
      'iconCodePoint': iconCodePoint,
      'isSystem': false,
    });
  }

  /// Update a list
  Future<void> updateList(String id, String name, int iconCodePoint) async {
    final col = _listsCol;
    if (col == null) return;
    await col.doc(id).update({
      'name': name,
      'iconCodePoint': iconCodePoint,
    });
  }

  /// Delete a list
  Future<void> deleteList(String id) async {
    final col = _listsCol;
    if (col == null) return;
    // We should also delete questions inside it theoretically, but for now just delete the list doc
    await col.doc(id).delete();
  }

  /// Toggles question in a specific list
  Future<void> toggleQuestionInList(String listId, QuizQuestion question) async {
    final qCol = _questionsCol(listId);
    final qId = question.id;
    if (qCol == null || qId == null) return;

    final docRef = qCol.doc(qId);
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

  /// Stream of question IDs in a specific list
  Stream<Set<String>> streamListQuestionIds(String listId) {
    final qCol = _questionsCol(listId);
    if (qCol == null) return Stream.value({});
    return qCol.snapshots().map((snap) => snap.docs.map((doc) => doc.id).toSet());
  }

  /// Check if a specific question is in a list
  Future<bool> isQuestionInList(String listId, String questionId) async {
    final qCol = _questionsCol(listId);
    if (qCol == null) return false;
    final doc = await qCol.doc(questionId).get();
    return doc.exists;
  }
}
