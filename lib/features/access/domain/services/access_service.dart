import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/features/access/data/models/access_models.dart';

class AccessService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Check if the user has active access to a subject
  Future<bool> checkAccess(String userId, String subjectId) async {
    final grantId = '${userId}_$subjectId';
    final docSnap = await _db.collection('user_access_grants').doc(grantId).get();

    if (!docSnap.exists) return false;

    final grant = UserAccessGrant.fromFirestore(docSnap);
    return grant.hasValidAccess;
  }

  /// Check if a code is valid (format and basic DB check) before transaction
  Future<bool> isValidCodeFormat(String code) async {
    if (code.trim().isEmpty || code.length < 5) return false;
    // We can also check if it exists, but the transaction handles the robust check
    return true;
  }

  /// Activate a code for a user using a Firestore Transaction to prevent race conditions
  Future<void> activateCode(String inputCode, String userId, {bool isQr = false}) async {
    final code = inputCode.trim();
    if (!await isValidCodeFormat(code)) {
      throw Exception('تنسيق الكود غير صالح.');
    }

    final codeRef = _db.collection('activation_codes').doc(code);

    await _db.runTransaction((transaction) async {
      final codeDoc = await transaction.get(codeRef);

      if (!codeDoc.exists) {
        throw Exception('الكود غير صحيح أو غير موجود.');
      }

      final codeData = codeDoc.data()!;
      if (codeData['isUsed'] == true) {
        throw Exception('هذا الكود تم استخدامه مسبقاً.');
      }

      final subjectId = codeData['subjectId'] as String;
      final durationDays = codeData['durationDays'] as int;

      // 1. Mark code as used
      transaction.update(codeRef, {
        'isUsed': true,
        'usedBy': userId,
        'usedAt': FieldValue.serverTimestamp(),
      });

      // 2. Grant access to the user
      final grantId = '${userId}_$subjectId';
      final grantRef = _db.collection('user_access_grants').doc(grantId);
      
      // Calculate expiration
      DateTime? expiresAt;
      if (durationDays > 0) {
        expiresAt = DateTime.now().add(Duration(days: durationDays));
      }

      final grant = UserAccessGrant(
        userId: userId,
        subjectId: subjectId,
        accessMethod: isQr ? AccessMethod.qrCode : AccessMethod.manualCode,
        grantedAt: DateTime.now(),
        expiresAt: expiresAt,
        isActive: true,
      );

      transaction.set(grantRef, grant.toMap(), SetOptions(merge: true));
    });
  }

  /// Revoke access manually (Admin use)
  Future<void> revokeAccess(String userId, String subjectId) async {
    final grantId = '${userId}_$subjectId';
    await _db.collection('user_access_grants').doc(grantId).update({
      'isActive': false,
    });
  }
}
