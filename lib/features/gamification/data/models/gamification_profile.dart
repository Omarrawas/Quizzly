import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class GamificationProfile {
  final String userId;
  final int xp;
  final int level;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActiveDate;
  final List<String> earnedBadges;

  const GamificationProfile({
    required this.userId,
    this.xp = 0,
    this.level = 1,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActiveDate,
    this.earnedBadges = const [],
  });

  factory GamificationProfile.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) {
      return GamificationProfile(userId: doc.id);
    }
    final data = doc.data() as Map<String, dynamic>;
    return GamificationProfile(
      userId: doc.id,
      xp: data['xp'] ?? 0,
      level: data['level'] ?? 1,
      currentStreak: data['currentStreak'] ?? 0,
      longestStreak: data['longestStreak'] ?? 0,
      lastActiveDate: (data['lastActiveDate'] as Timestamp?)?.toDate(),
      earnedBadges: List<String>.from(data['earnedBadges'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'xp': xp,
      'level': level,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastActiveDate': lastActiveDate != null ? Timestamp.fromDate(lastActiveDate!) : FieldValue.serverTimestamp(),
      'earnedBadges': earnedBadges,
    };
  }

  /// يحسب المستوى بناءً على XP
  static int calculateLevel(int currentXp) {
    return (sqrt(currentXp / 100)).floor() + 1;
  }
}

class XpResult {
  final int xpGained;
  final int newLevel;
  final bool levelUp;

  const XpResult({
    required this.xpGained,
    required this.newLevel,
    required this.levelUp,
  });
}
