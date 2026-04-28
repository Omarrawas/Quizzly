import 'package:cloud_firestore/cloud_firestore.dart';

class ContentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Hierarchy Fetchers ---

  Stream<QuerySnapshot> getUniversities() {
    return _db.collection('universities').orderBy('order').snapshots();
  }

  Stream<QuerySnapshot> getColleges(String universityId) {
    return _db.collection('colleges')
        .where('parentId', isEqualTo: universityId)
        .orderBy('order')
        .snapshots();
  }

  Stream<QuerySnapshot> getDepartments(String collegeId) {
    return _db.collection('departments')
        .where('parentId', isEqualTo: collegeId)
        .orderBy('order')
        .snapshots();
  }

  Stream<QuerySnapshot> getYears(String departmentId) {
    return _db.collection('academic_years')
        .where('parentId', isEqualTo: departmentId)
        .orderBy('order')
        .snapshots();
  }

  Stream<QuerySnapshot> getSemesters(String yearId) {
    return _db.collection('semesters')
        .where('parentId', isEqualTo: yearId)
        .orderBy('order')
        .snapshots();
  }

  Stream<QuerySnapshot> getSubjects(String semesterId) {
    return _db.collection('subjects')
        .where('parentId', isEqualTo: semesterId)
        .orderBy('order')
        .snapshots();
  }

  // --- User Content Management ---

  /// Adds a single subject to the user's home screen
  Future<void> addUserSubject(String userId, String subjectId) async {
    final ref = _db.collection('users').doc(userId).collection('active_subjects').doc(subjectId);
    await ref.set({
      'subjectId': subjectId,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Adds an entire semester (all subjects in it) to the user's home screen
  Future<void> addUserSemester(String userId, String semesterId) async {
    final subjectsSnapshot = await _db.collection('subjects')
        .where('parentId', isEqualTo: semesterId)
        .get();

    final batch = _db.batch();
    for (var doc in subjectsSnapshot.docs) {
      final ref = _db.collection('users').doc(userId).collection('active_subjects').doc(doc.id);
      batch.set(ref, {
        'subjectId': doc.id,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
    
    // Optionally track that the full semester was added
    final semRef = _db.collection('users').doc(userId).collection('active_semesters').doc(semesterId);
    batch.set(semRef, {
      'semesterId': semesterId,
      'addedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Fetches subjects added by the user
  Stream<List<Map<String, dynamic>>> getUserActiveSubjects(String userId) {
    return _db.collection('users').doc(userId).collection('active_subjects')
        .snapshots()
        .asyncMap((snapshot) async {
          List<Map<String, dynamic>> subjects = [];
          for (var doc in snapshot.docs) {
            final subjectId = doc.get('subjectId');
            final subjectDoc = await _db.collection('subjects').doc(subjectId).get();
            if (subjectDoc.exists) {
              subjects.add({
                ...subjectDoc.data()!,
                'id': subjectDoc.id,
                'addedAt': doc.get('addedAt'),
              });
            }
          }
          return subjects;
        });
  }

  /// Fetches only the IDs of subjects added by the user
  Stream<Set<String>> getUserActiveSubjectIds(String userId) {
    return _db.collection('users').doc(userId).collection('active_subjects')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.get('subjectId') as String).toSet());
  }

  // --- User Settings ---

  Future<Map<String, dynamic>?> getUserDefaults(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (doc.exists && doc.data()!.containsKey('defaults')) {
      return doc.data()!['defaults'] as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> setUserDefaults(String userId, Map<String, dynamic> defaults) async {
    await _db.collection('users').doc(userId).update({
      'defaults': defaults,
    });
  }
}
