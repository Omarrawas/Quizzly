import 'package:cloud_firestore/cloud_firestore.dart';

class ActivationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Checks if a user has access to a specific exam
  Future<bool> hasExamAccess(String userId, String examId, String subjectId) async {
    // 1. Check if the subject itself is activated for this user
    final subjectDoc = await _db
        .collection('users')
        .doc(userId)
        .collection('active_subjects')
        .doc(subjectId)
        .get();
    
    if (subjectDoc.exists && (subjectDoc.data()?['isActivated'] ?? false)) {
      return true;
    }

    // 2. Check if this specific exam is activated for this user
    final examDoc = await _db
        .collection('users')
        .doc(userId)
        .collection('active_exams')
        .doc(examId)
        .get();

    return examDoc.exists;
  }

  /// Attempts to activate a resource using a code
  Future<Map<String, dynamic>> activateWithCode({
    required String userId,
    required String code,
    String? subjectId,
    String? examId,
  }) async {
    try {
      // 1. Find the code
      final codeSnap = await _db.collection('activation_codes')
          .where('code', isEqualTo: code.trim().toUpperCase())
          .limit(1)
          .get();

      if (codeSnap.docs.isEmpty) {
        return {'success': false, 'message': 'كود التفعيل غير صحيح'};
      }

      final codeDoc = codeSnap.docs.first;
      final codeData = codeDoc.data();

      // 2. Check if used
      if (codeData['isUsed'] == true) {
        return {'success': false, 'message': 'هذا الكود تم استخدامه مسبقاً'};
      }

      // 3. Check compatibility (optional: if code is specific to a subject)
      // For now, let's assume codes are generic or linked to what the user is trying to activate
      
      final batch = _db.batch();

      // Mark code as used
      batch.update(codeDoc.reference, {
        'isUsed': true,
        'usedAt': FieldValue.serverTimestamp(),
        'usedBy': userId,
      });

      // Grant access
      if (subjectId != null) {
        final ref = _db.collection('users').doc(userId).collection('active_subjects').doc(subjectId);
        batch.set(ref, {
          'subjectId': subjectId,
          'isActivated': true,
          'activatedAt': FieldValue.serverTimestamp(),
          'activationCode': code,
        }, SetOptions(merge: true));
      } else if (examId != null) {
        final ref = _db.collection('users').doc(userId).collection('active_exams').doc(examId);
        batch.set(ref, {
          'examId': examId,
          'activatedAt': FieldValue.serverTimestamp(),
          'activationCode': code,
        });
      }

      await batch.commit();
      return {'success': true, 'message': 'تم التفعيل بنجاح!'};

    } catch (e) {
      return {'success': false, 'message': 'حدث خطأ أثناء التفعيل: $e'};
    }
  }
}
