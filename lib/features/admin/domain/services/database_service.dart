import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Collection Constants ---
  static const String colUniversities = 'universities';
  static const String colColleges = 'colleges';
  static const String colDepartments = 'departments';
  static const String colYears = 'academic_years';
  static const String colSemesters = 'semesters';
  static const String colSubjects = 'subjects';
  static const String colSections = 'sections';
  static const String colQuestions = 'questions';
  static const String colTopics = 'topics';
  static const String colExams = 'exams';

  // --- Generic Helpers ---
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data) => 
      _db.collection(collection).doc(id).update(data);
  
  Future<void> deleteDoc(String collection, String id) => 
      _db.collection(collection).doc(id).delete();

  Future<void> updateOrder(String collection, List<String> ids) async {
    final batch = _db.batch();
    for (int i = 0; i < ids.length; i++) {
      batch.update(_db.collection(collection).doc(ids[i]), {'order': i});
    }
    await batch.commit();
  }

  // --- Hierarchical Queries (Flat Structure) ---
  
  // Universities (No parent)
  Stream<QuerySnapshot> getUniversities() => 
      _db.collection(colUniversities).orderBy('order').snapshots();

  Future<DocumentReference> addUniversity(Map<String, dynamic> data) async {
    final count = await _db.collection(colUniversities).count().get();
    return _db.collection(colUniversities).add({
      ...data, 
      'order': count.count,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Generic child query
  Stream<QuerySnapshot> getChildren(String collection, String parentId) => 
      _db.collection(collection)
          .where('parentId', isEqualTo: parentId)
          .orderBy('order')
          .snapshots();

  Future<DocumentReference> addChild(String collection, String parentId, Map<String, dynamic> data) async {
    final count = await _db.collection(collection)
        .where('parentId', isEqualTo: parentId)
        .count().get();
    return _db.collection(collection).add({
      ...data, 
      'parentId': parentId,
      'order': count.count,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // --- Specialized Adders (Wrappers for clarity) ---
  Future<DocumentReference> addCollege(String uniId, Map<String, dynamic> data) => addChild(colColleges, uniId, data);
  Future<DocumentReference> addDepartment(String collegeId, Map<String, dynamic> data) => addChild(colDepartments, collegeId, data);
  Future<DocumentReference> addYear(String deptId, Map<String, dynamic> data) => addChild(colYears, deptId, data);
  Future<DocumentReference> addSemester(String yearId, Map<String, dynamic> data) => addChild(colSemesters, yearId, data);
  Future<DocumentReference> addSubject(String semesterId, Map<String, dynamic> data) => addChild(colSubjects, semesterId, data);
  Future<DocumentReference> addSection(String subjectId, Map<String, dynamic> data) => addChild(colSections, subjectId, data);
  Future<DocumentReference> addQuestion(String sectionId, Map<String, dynamic> data) => addChild(colQuestions, sectionId, data);

  // --- Topics (Nested Structure) ---
  Stream<QuerySnapshot> getTopics(String subjectId, {String? sectionId, String? parentId, String? type}) {
    var query = _db.collection(colTopics)
        .where('subjectId', isEqualTo: subjectId)
        .where('parentId', isEqualTo: parentId);
    
    if (sectionId != null) {
      query = query.where('sectionId', isEqualTo: sectionId);
    }
    
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }
    
    return query.snapshots();
  }

  Stream<QuerySnapshot> getAllTopicsForSubject(String subjectId, {String? sectionId}) {
    var query = _db.collection(colTopics)
        .where('subjectId', isEqualTo: subjectId);
        
    if (sectionId != null) {
      query = query.where('sectionId', isEqualTo: sectionId);
    }
    
    return query.snapshots();
  }

  Future<void> addTopic(String subjectId, String? sectionId, String? parentId, Map<String, dynamic> data) async {
    var query = _db.collection(colTopics)
        .where('subjectId', isEqualTo: subjectId)
        .where('parentId', isEqualTo: parentId);
    
    if (sectionId != null) {
      query = query.where('sectionId', isEqualTo: sectionId);
    }

    final count = await query.count().get();

    List<String> ancestors = [];
    if (parentId != null) {
      final parentDoc = await _db.collection(colTopics).doc(parentId).get();
      if (parentDoc.exists) {
        final parentData = parentDoc.data() as Map<String, dynamic>;
        ancestors = List<String>.from(parentData['ancestors'] ?? []);
        ancestors.add(parentId);
      }
    }

    await _db.collection(colTopics).add({
      ...data,
      'subjectId': subjectId,
      'sectionId': sectionId,
      'parentId': parentId,
      'ancestors': ancestors,
      'order': count.count,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> moveTopic(String topicId, String? newParentId, String newType) async {
    List<String> ancestors = [];
    if (newParentId != null) {
      final parentDoc = await _db.collection(colTopics).doc(newParentId).get();
      if (parentDoc.exists) {
        final parentData = parentDoc.data() as Map<String, dynamic>;
        ancestors = List<String>.from(parentData['ancestors'] ?? []);
        ancestors.add(newParentId);
      }
    }

    // Get count for new order
    final count = await _db.collection(colTopics)
        .where('parentId', isEqualTo: newParentId)
        .count().get();

    await _db.collection(colTopics).doc(topicId).update({
      'parentId': newParentId,
      'type': newType,
      'ancestors': ancestors,
      'order': count.count,
    });
  }

  // --- Specialized Getters ---
  Stream<QuerySnapshot> getColleges(String uniId) => getChildren(colColleges, uniId);
  Stream<QuerySnapshot> getDepartments(String collegeId) => getChildren(colDepartments, collegeId);
  Stream<QuerySnapshot> getYears(String deptId) => getChildren(colYears, deptId);
  Stream<QuerySnapshot> getSemesters(String yearId) => getChildren(colSemesters, yearId);
  Stream<QuerySnapshot> getSubjects(String semesterId) => getChildren(colSubjects, semesterId);
  Stream<QuerySnapshot> getSections(String subjectId) => getChildren(colSections, subjectId);
  Stream<QuerySnapshot> getQuestions(String sectionId) => getChildren(colQuestions, sectionId);

  // --- Exams ---
  Stream<QuerySnapshot> getExams(String subjectId, {required String sectionId}) {
    return _db.collection(colExams)
        .where('subjectId', isEqualTo: subjectId)
        .where('sectionId', isEqualTo: sectionId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<DocumentReference> addExam(Map<String, dynamic> data) async {
    return _db.collection(colExams).add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // --- Analytics Tracking ---
  Future<void> submitQuizAttempt(String userId, String quizId, List<Map<String, dynamic>> answers) async {
    // 1. Save the attempt record
    final attemptRef = _db.collection('quiz_attempts').doc();
    final batch = _db.batch();

    batch.set(attemptRef, {
      'userId': userId,
      'quizId': quizId,
      'timestamp': FieldValue.serverTimestamp(),
      'answers': answers,
    });

    // 2. Aggregate analytics for each question
    for (var answer in answers) {
      final questionId = answer['questionId'] as String;
      final isCorrect = answer['isCorrect'] as bool;
      final timeSpent = answer['timeSpent'] as int;

      final questionRef = _db.collection(colQuestions).doc(questionId);
      batch.set(
        questionRef,
        {
          'analytics': {
            'timesAnswered': FieldValue.increment(1),
            'correctAnswers': FieldValue.increment(isCorrect ? 1 : 0),
            'totalTimeSpent': FieldValue.increment(timeSpent),
          }
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> updateUserHistory(String userId, List<Map<String, dynamic>> answers) async {
    final historyRef = _db.collection('user_history').doc(userId);
    final batch = _db.batch();

    for (var answer in answers) {
      final qId = answer['questionId'] as String;
      final isCorrect = answer['isCorrect'] as bool;
      
      batch.set(historyRef, {
        'questionStats': {
          qId: {
            'attempts': FieldValue.increment(1),
            'correct': FieldValue.increment(isCorrect ? 1 : 0),
            'lastAttemptAt': FieldValue.serverTimestamp(),
          }
        },
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // Still keep seen/wrong for easy querying
    List<String> seenIds = [];
    List<String> wrongIds = [];
    for (var answer in answers) {
      seenIds.add(answer['questionId'] as String);
      if (!(answer['isCorrect'] as bool)) wrongIds.add(answer['questionId'] as String);
    }

    batch.update(historyRef, {
      'seenQuestions': FieldValue.arrayUnion(seenIds),
      'wrongAnswers': FieldValue.arrayUnion(wrongIds),
    });

    await batch.commit();
  }

  // ─── Activation Codes ──────────────────────────────────

  String _generateRandomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Avoid confusing O,0,I,1
    final rnd = math.Random();
    return List.generate(8, (index) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> generateBulkCodes({
    required List<String> subjectIds,
    required String batchName,
    required int quantity,
    required int durationDays,
  }) async {
    final batch = _db.batch();
    final now = DateTime.now();

    for (int i = 0; i < quantity; i++) {
      final code = _generateRandomCode();
      final ref = _db.collection('activation_codes').doc(code);

      batch.set(ref, {
        'code': code,
        'subjectIds': subjectIds,
        'durationDays': durationDays,
        'isUsed': false,
        'usedBy': null,
        'usedAt': null,
        'createdAt': now,
        'batchName': batchName,
      });
    }

    // Also create a batch record for easier listing
    final batchRef = _db.collection('activation_batches').doc(batchName);
    batch.set(batchRef, {
      'name': batchName,
      'subjectIds': subjectIds,
      'quantity': quantity,
      'durationDays': durationDays,
      'createdAt': now,
    });

    await batch.commit();
  }

  Stream<QuerySnapshot> getBatches() {
    return _db.collection('activation_batches')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> getActivationCodesByBatch(String batchName) async {
    final snap = await _db.collection('activation_codes')
        .where('batchName', isEqualTo: batchName)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Stream<QuerySnapshot> streamActivationCodesByBatch(String batchName) {
    return _db.collection('activation_codes')
        .where('batchName', isEqualTo: batchName)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Toggle a single code between active (isUsed=false) and used (isUsed=true)
  Future<void> toggleCodeActivation(String codeId, {required bool markAsUsed}) {
    return _db.collection('activation_codes').doc(codeId).update({
      'isUsed': markAsUsed,
      'usedAt': markAsUsed ? FieldValue.serverTimestamp() : null,
      'usedBy': markAsUsed ? 'admin' : null,
    });
  }

  /// Update the duration of a single code
  Future<void> updateCodeDuration(String codeId, int newDurationDays) {
    return _db.collection('activation_codes').doc(codeId).update({
      'durationDays': newDurationDays,
    });
  }

  /// Delete a single activation code
  Future<void> deleteCode(String codeId) {
    return _db.collection('activation_codes').doc(codeId).delete();
  }

  Future<void> deleteActivationBatch(String batchName) async {
    final snap = await _db.collection('activation_codes')
        .where('batchName', isEqualTo: batchName)
        .get();
    
    final batch = _db.batch();
    for (var doc in snap.docs) {
      batch.delete(doc.reference);
    }

    // Delete batch record too
    batch.delete(_db.collection('activation_batches').doc(batchName));

    await batch.commit();
  }
}
