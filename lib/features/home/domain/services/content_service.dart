import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ContentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const Duration _subjectLookupTimeout = Duration(seconds: 2);
  static const Duration _hierarchyLookupTimeout = Duration(milliseconds: 1200);
  static const Duration _activeSubjectsTimeout = Duration(seconds: 8);

  Future<DocumentSnapshot<Map<String, dynamic>>?> _getDocWithCacheFallback(
    CollectionReference<Map<String, dynamic>> collection,
    String docId, {
    required Duration timeout,
  }) async {
    try {
      return await collection.doc(docId).get().timeout(timeout);
    } catch (_) {
      try {
        return await collection
            .doc(docId)
            .get(const GetOptions(source: Source.cache));
      } catch (_) {
        return null;
      }
    }
  }

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
    // 0. Ensure user document exists
    final userDocRef = _db.collection('users').doc(userId);
    await userDocRef.set({
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 1. Per-user record (Store activationType for easy display)
    await userDocRef.collection('active_subjects').doc(subjectId).set({
      'subjectId': subjectId,
      'addedAt': FieldValue.serverTimestamp(),
      'activationType': activationCode != null ? 'code' : 'free',
      'isActivated': activationCode != null,
    });

    // 2. Global record for admin
    final globalRef = _db.collection('user_subjects').doc('${userId}_$subjectId'); 
    await globalRef.set({
      'activationId': globalRef.id,
      'userId': userId,
      'subjectId': subjectId,
      'activatedAt': FieldValue.serverTimestamp(),
      'activationType': activationCode != null ? 'code' : 'free',
      'activationCode': activationCode, 
      'price': 0, // Add price field to satisfy firestore rules (price >= 0)
    });
  }

  /// Adds an entire semester (all subjects in it) to the user's home screen
  Future<void> addUserSemester(String userId, String semesterId, {String? activationCode}) async {
    final subjectsSnapshot = await _db.collection('subjects')
        .where('parentId', isEqualTo: semesterId)
        .get();

    // 0. Ensure user document exists
    final userDocRef = _db.collection('users').doc(userId);
    await userDocRef.set({
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    for (var doc in subjectsSnapshot.docs) {
      // 1. Per-user records
      await userDocRef.collection('active_subjects').doc(doc.id).set({
        'subjectId': doc.id,
        'addedAt': FieldValue.serverTimestamp(),
        'activationType': activationCode != null ? 'code' : 'free',
        'isActivated': activationCode != null,
      });

      // 2. Global records
      final globalRef = _db.collection('user_subjects').doc('${userId}_${doc.id}');
      await globalRef.set({
        'activationId': globalRef.id,
        'userId': userId,
        'subjectId': doc.id,
        'activatedAt': FieldValue.serverTimestamp(),
        'activationType': activationCode != null ? 'code' : 'free',
        'activationCode': activationCode,
      });
    }
    
    // Optionally track that the full semester was added
    await userDocRef.collection('active_semesters').doc(semesterId).set({
      'semesterId': semesterId,
      'addedAt': FieldValue.serverTimestamp(),
      'activationType': activationCode != null ? 'code' : 'free',
    });
  }

  final Map<String, Map<String, String>> _hierarchyCache = {};

  /// Fetches subjects added by the user
  Stream<List<Map<String, dynamic>>> getUserActiveSubjects(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('active_subjects')
        .snapshots()
        .asyncMap((snapshot) async {
      // Prepare a list of futures for each active subject document
      final List<Future<Map<String, dynamic>?>> futures = [];

      for (var doc in snapshot.docs) {
        futures.add(() async {
          final docData = doc.data();
          final subjectId = docData['subjectId'] as String?;
          if (subjectId == null) return null;

          // Fetch the subject document (try server first, then cache)
          final subjectDoc = await _getDocWithCacheFallback(
            _db.collection('subjects'),
            subjectId,
            timeout: _subjectLookupTimeout,
          );

          if (subjectDoc == null || !subjectDoc.exists) return null;
          final subjectData = subjectDoc.data()!;
          final semesterId = subjectData['parentId'];

          Map<String, String> hierarchy = {};
          if (semesterId != null) {
            if (_hierarchyCache.containsKey(semesterId)) {
              hierarchy = _hierarchyCache[semesterId]!;
            } else {
              try {
                // 1. Fetch semester
                final semDoc = await _getDocWithCacheFallback(
                  _db.collection('semesters'),
                  semesterId,
                  timeout: _hierarchyLookupTimeout,
                );
                final semData = semDoc?.data();
                final semName = semData?['name'] ?? 'فصل غير محدد';
                final yearId = semData?['parentId'];

                // 2. Fetch year
                final yearDoc = yearId != null
                    ? await _getDocWithCacheFallback(
                        _db.collection('academic_years'),
                        yearId,
                        timeout: _hierarchyLookupTimeout,
                      )
                    : null;
                final yearData = yearDoc?.data();
                final yearName = yearData?['name'] ?? 'سنة غير محددة';
                final depId = yearData?['parentId'];

                // 3. Fetch department
                final depDoc = depId != null
                    ? await _getDocWithCacheFallback(
                        _db.collection('departments'),
                        depId,
                        timeout: _hierarchyLookupTimeout,
                      )
                    : null;
                final depData = depDoc?.data();
                final depName = depData?['name'] ?? 'قسم غير محدد';
                final colId = depData?['parentId'];

                // 4. Fetch college
                final colDoc = colId != null
                    ? await _getDocWithCacheFallback(
                        _db.collection('colleges'),
                        colId,
                        timeout: _hierarchyLookupTimeout,
                      )
                    : null;
                final colData = colDoc?.data();
                final colName = colData?['name'] ?? 'كلية غير محددة';
                final uniId = colData?['parentId'];

                // 5. Fetch university
                final uniDoc = uniId != null
                    ? await _getDocWithCacheFallback(
                        _db.collection('universities'),
                        uniId,
                        timeout: _hierarchyLookupTimeout,
                      )
                    : null;
                final uniName = uniDoc?.data()?['name'] ?? 'جامعة غير محددة';

                hierarchy = {
                  'semesterName': semName,
                  'yearName': yearName,
                  'departmentName': depName,
                  'collegeName': colName,
                  'universityName': uniName,
                };
                _hierarchyCache[semesterId] = hierarchy;
              } catch (_) {
                hierarchy = {
                  'semesterName': 'فصل غير محدد',
                  'yearName': 'سنة غير محددة',
                  'departmentName': 'قسم غير محدد',
                  'collegeName': 'كلية غير محددة',
                  'universityName': 'جامعة غير محددة',
                };
              }
            }
          }

          return {
            ...subjectData,
            'id': subjectDoc.id,
            'addedAt': docData['addedAt'] ?? docData['activatedAt'],
            'activationType': docData['activationType'],
            'paidPrice': docData['price'],
            ...hierarchy,
          };
        }());
      }

      final results = await Future.wait(futures);
      return results.whereType<Map<String, dynamic>>().toList();
    }).timeout(
      _activeSubjectsTimeout,
      onTimeout: (sink) => sink.add(const <Map<String, dynamic>>[]),
    ).asBroadcastStream();
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
    final Map<String, dynamic> updates = {};
    defaults.forEach((key, value) {
      updates['defaults.$key'] = value;
    });
    await _db.collection('users').doc(userId).set(updates, SetOptions(merge: true));
  }

  // --- Content Codes ---

  /// Resolves a code from the new activation system
  Future<Map<String, dynamic>?> resolveContentCode(String code) async {
    final snapshot = await _db.collection('activation_codes')
        .doc(code.trim().toUpperCase())
        .get();

    if (!snapshot.exists) {
      // Fallback to searching by field if ID is not the code (for safety)
      final fallback = await _db.collection('activation_codes')
          .where('code', isEqualTo: code.trim().toUpperCase())
          .limit(1)
          .get();
      if (fallback.docs.isEmpty) return null;
      return _parseActivationCode(fallback.docs.first);
    }
    
    return _parseActivationCode(snapshot);
  }

  Map<String, dynamic> _parseActivationCode(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return {
      'code': doc.id,
      'subjectIds': data['subjectIds'] as List? ?? [],
      'isUsed': data['isUsed'] ?? false,
      'durationDays': data['durationDays'] ?? 0,
      'type': (data['subjectIds'] as List? ?? []).length > 1 ? 'package' : 'subject',
    };
  }

  /// Specialized method to activate a code and link it to the user
  Future<void> activateCode(String userId, String code, Map<String, dynamic> codeData) async {
    final List subjectIds = codeData['subjectIds'] as List? ?? [];
    final int durationDays = codeData['durationDays'] as int? ?? 180;
    
    final batch = _db.batch();
    
    // 1. Mark code as used
    batch.update(_db.collection('activation_codes').doc(code), {
      'isUsed': true,
      'usedBy': userId,
      'usedAt': FieldValue.serverTimestamp(),
      'expiresAt': DateTime.now().add(Duration(days: durationDays)),
    });

    // 2. Add each subject to user
    for (String subjectId in subjectIds) {
      // Per-user record
      final userSubRef = _db.collection('users').doc(userId).collection('active_subjects').doc(subjectId);
      batch.set(userSubRef, {
        'subjectId': subjectId,
        'addedAt': FieldValue.serverTimestamp(),
        'activationType': 'code',
        'activationCode': code,
        'isActivated': true,
        'expiresAt': DateTime.now().add(Duration(days: durationDays)),
      });

      // Global record for admin
      final globalRef = _db.collection('user_subjects').doc('${userId}_$subjectId');
      batch.set(globalRef, {
        'activationId': globalRef.id,
        'userId': userId,
        'subjectId': subjectId,
        'activatedAt': FieldValue.serverTimestamp(),
        'activationType': 'code',
        'activationCode': code,
        'expiresAt': DateTime.now().add(Duration(days: durationDays)),
      });
    }

    await batch.commit();
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
      final questionsSnapshot = await _db.collection('questions')
          .where('subjectId', isEqualTo: subjectId)
          .where('status', isEqualTo: 'approved')
          .get(const GetOptions(source: Source.server));

      // 5. Pre-download all explanation and question attachments in background
      final cacheManager = DefaultCacheManager();
      for (var qDoc in questionsSnapshot.docs) {
        final data = qDoc.data();
        
        final String? explanationImageUrl = data['explanationImageUrl'];
        final String? explanationAudioUrl = data['explanationAudioUrl'];
        final String? explanationPdfUrl = data['explanationPdfUrl'];
        final String? imageUrl = data['imageUrl'];

        if (explanationImageUrl != null && explanationImageUrl.isNotEmpty) {
          _downloadToCacheSilently(cacheManager, explanationImageUrl);
        }
        if (explanationAudioUrl != null && explanationAudioUrl.isNotEmpty) {
          _downloadToCacheSilently(cacheManager, explanationAudioUrl);
        }
        if (explanationPdfUrl != null && explanationPdfUrl.isNotEmpty) {
          _downloadToCacheSilently(cacheManager, explanationPdfUrl);
        }
        if (imageUrl != null && imageUrl.isNotEmpty) {
          _downloadToCacheSilently(cacheManager, imageUrl);
        }
      }
    }
  }

  Future<void> _downloadToCacheSilently(DefaultCacheManager cacheManager, String url) async {
    try {
      await cacheManager.downloadFile(url);
    } catch (_) {
      // Suppress background sync errors silently
    }
  }
}
