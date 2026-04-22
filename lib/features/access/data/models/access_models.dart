import 'package:cloud_firestore/cloud_firestore.dart';

enum AccessMethod { qrCode, manualCode, subscription, adminGrant }

class ActivationCode {
  final String code;
  final String subjectId;
  final int durationDays;
  final bool isUsed;
  final String? usedBy;
  final DateTime? usedAt;
  final DateTime createdAt;

  const ActivationCode({
    required this.code,
    required this.subjectId,
    required this.durationDays,
    this.isUsed = false,
    this.usedBy,
    this.usedAt,
    required this.createdAt,
  });

  factory ActivationCode.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivationCode(
      code: doc.id,
      subjectId: data['subjectId'] ?? '',
      durationDays: data['durationDays'] ?? 0,
      isUsed: data['isUsed'] ?? false,
      usedBy: data['usedBy'],
      usedAt: (data['usedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subjectId': subjectId,
      'durationDays': durationDays,
      'isUsed': isUsed,
      'usedBy': usedBy,
      'usedAt': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class UserAccessGrant {
  final String userId;
  final String subjectId;
  final AccessMethod accessMethod;
  final DateTime grantedAt;
  final DateTime? expiresAt; // null means lifetime access
  final bool isActive;

  const UserAccessGrant({
    required this.userId,
    required this.subjectId,
    required this.accessMethod,
    required this.grantedAt,
    this.expiresAt,
    this.isActive = true,
  });

  factory UserAccessGrant.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    AccessMethod parseMethod(String? m) {
      if (m == 'manualCode') return AccessMethod.manualCode;
      if (m == 'qrCode') return AccessMethod.qrCode;
      if (m == 'subscription') return AccessMethod.subscription;
      return AccessMethod.adminGrant;
    }

    return UserAccessGrant(
      userId: data['userId'] ?? '',
      subjectId: data['subjectId'] ?? '',
      accessMethod: parseMethod(data['accessMethod']),
      grantedAt: (data['grantedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'subjectId': subjectId,
      'accessMethod': accessMethod.name,
      'grantedAt': Timestamp.fromDate(grantedAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isActive': isActive,
    };
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get hasValidAccess => isActive && !isExpired;
}
