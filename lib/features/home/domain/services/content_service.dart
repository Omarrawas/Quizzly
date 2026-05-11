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
  Future<void> addUserSubject(String userId, String subjectId, {String? activationCode}) async {
    final batch = _db.batch();
    
    // 1. Per-user record for fast home screen loading (Keep it minimal as requested)
    final userRef = _db.collection('users').doc(userId).collection('active_subjects').doc(subjectId);
    batch.set(userRef, {
      'subjectId': subjectId,
      'addedAt': FieldValue.serverTimestamp(),
    });

    // 2. Global record for admin visibility (Store detailed activation info here)
    // Using auto-generated ID to avoid potential path issues
    final globalRef = _db.collection('user_subjects').doc(); 
    batch.set(globalRef, {
      'activationId': globalRef.id, // Store ID for easy deletion
      'userId': userId,
      'subjectId': subjectId,
      'activatedAt': FieldValue.serverTimestamp(),
      'activationType': activationCode != null ? 'code' : 'free',
      'activationCode': activationCode, 
    });

    await batch.commit();
  }

  /// Adds an entire semester (all subjects in it) to the user's home screen
  Future<void> addUserSemester(String userId, String semesterId, {String? activationCode}) async {
    final subjectsSnapshot = await _db.collection('subjects')
        .where('parentId', isEqualTo: semesterId)
        .get();

    final batch = _db.batch();
    for (var doc in subjectsSnapshot.docs) {
      // 1. Per-user records (Minimal)
      final userRef = _db.collection('users').doc(userId).collection('active_subjects').doc(doc.id);
      batch.set(userRef, {
        'subjectId': doc.id,
        'addedAt': FieldValue.serverTimestamp(),
      });

      // 2. Global records for admin visibility
      final globalRef = _db.collection('user_subjects').doc();
      batch.set(globalRef, {
        'activationId': globalRef.id,
        'userId': userId,
        'subjectId': doc.id,
        'activatedAt': FieldValue.serverTimestamp(),
        'activationType': activationCode != null ? 'code' : 'free',
        'activationCode': activationCode,
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

  final Map<String, Map<String, String>> _hierarchyCache = {};

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
              final subjectData = subjectDoc.data()!;
              final semesterId = subjectData['parentId'];
              
              Map<String, String> hierarchy = {};
              if (semesterId != null) {
                if (_hierarchyCache.containsKey(semesterId)) {
                  hierarchy = _hierarchyCache[semesterId]!;
                } else {
                  try {
                    final semDoc = await _db.collection('semesters').doc(semesterId).get();
                    final semName = semDoc.data()?['name'] ?? 'فصل غير محدد';
                    final yearId = semDoc.data()?['parentId'];

                    final yearDoc = await _db.collection('academic_years').doc(yearId).get();
                    final yearName = yearDoc.data()?['name'] ?? 'سنة غير محددة';
                    final depId = yearDoc.data()?['parentId'];

                    final depDoc = await _db.collection('departments').doc(depId).get();
                    final depName = depDoc.data()?['name'] ?? 'قسم غير محدد';
                    final colId = depDoc.data()?['parentId'];

                    final colDoc = await _db.collection('colleges').doc(colId).get();
                    final colName = colDoc.data()?['name'] ?? 'كلية غير محددة';
                    final uniId = colDoc.data()?['parentId'];

                    final uniDoc = await _db.collection('universities').doc(uniId).get();
                    final uniName = uniDoc.data()?['name'] ?? 'جامعة غير محددة';

                    hierarchy = {
                      'semesterName': semName,
                      'yearName': yearName,
                      'departmentName': depName,
                      'collegeName': colName,
                      'universityName': uniName,
                    };
                    _hierarchyCache[semesterId] = hierarchy;
                  } catch (e) {
                    // Ignore errors, will use fallback
                  }
                }
              }

              subjects.add({
                ...subjectData,
                'id': subjectDoc.id,
                'addedAt': doc.get('addedAt'),
                ...hierarchy,
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

  // --- Content Codes ---

  /// Resolves a code to a specific subject or semester
  Future<Map<String, dynamic>?> resolveContentCode(String code) async {
    final snapshot = await _db.collection('content_codes')
        .where('code', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    
    final data = snapshot.docs.first.data();
    return {
      'type': data['type'], // 'subject' or 'semester'
      'targetId': data['targetId'],
      'name': data['name'],
    };
  }

  // --- Offline Sync ---
  /// Downloads and caches active subjects, their topics, and questions for offline usage.
  Future<void> syncOfflineData(String userId) async {
    // 1. Fetch active subjects directly from server to update cache
    final snapshot = await _db.collection('users').doc(userId).collection('active_subjects')
        .get(const GetOptions(source: Source.server));
    
    for (var doc in snapshot.docs) {
      final subjectId = doc.get('subjectId') as String;
      
      // 2. Fetch subject details
      await _db.collection('subjects').doc(subjectId).get(const GetOptions(source: Source.server));
      
      // 3. Fetch topics for this subject
      await _db.collection('topics')
          .where('subjectId', isEqualTo: subjectId)
          .get(const GetOptions(source: Source.server));
          
      // 4. Fetch all approved questions for this subject
      await _db.collection('questions')
          .where('subjectId', isEqualTo: subjectId)
          .where('status', isEqualTo: 'approved')
          .get(const GetOptions(source: Source.server));
    }
  }
}
