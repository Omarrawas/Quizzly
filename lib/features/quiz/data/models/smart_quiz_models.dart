import 'package:cloud_firestore/cloud_firestore.dart';

class TopicPerformance {
  final int totalAttempts;
  final int correctAttempts;
  final DateTime lastAttemptDate;
  final double masteryLevel;

  const TopicPerformance({
    this.totalAttempts = 0,
    this.correctAttempts = 0,
    required this.lastAttemptDate,
    this.masteryLevel = 0.0,
  });

  factory TopicPerformance.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return TopicPerformance(lastAttemptDate: DateTime.now());
    }
    return TopicPerformance(
      totalAttempts: map['totalAttempts'] ?? 0,
      correctAttempts: map['correctAttempts'] ?? 0,
      lastAttemptDate: (map['lastAttemptDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      masteryLevel: (map['masteryLevel'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalAttempts': totalAttempts,
      'correctAttempts': correctAttempts,
      'lastAttemptDate': Timestamp.fromDate(lastAttemptDate),
      'masteryLevel': masteryLevel,
    };
  }

  TopicPerformance copyWithAttempt(bool isCorrect) {
    int newTotal = totalAttempts + 1;
    int newCorrect = correctAttempts + (isCorrect ? 1 : 0);
    // Exponential moving average or simple percentage
    // For adaptive behavior, a simple percentage over total is okay, 
    // but recent attempts should weigh more. Let's use simple percentage for now.
    double newMastery = newCorrect / newTotal;
    
    return TopicPerformance(
      totalAttempts: newTotal,
      correctAttempts: newCorrect,
      lastAttemptDate: DateTime.now(),
      masteryLevel: newMastery,
    );
  }
}

class UserSubjectPerformance {
  final String userId;
  final String subjectId;
  final Map<String, TopicPerformance> topicsStats;

  const UserSubjectPerformance({
    required this.userId,
    required this.subjectId,
    required this.topicsStats,
  });

  factory UserSubjectPerformance.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) {
      return UserSubjectPerformance(userId: doc.id, subjectId: '', topicsStats: {});
    }
    final data = doc.data() as Map<String, dynamic>;
    final topicsData = data['topicsData'] as Map<String, dynamic>? ?? {};
    
    Map<String, TopicPerformance> parsedStats = {};
    topicsData.forEach((key, value) {
      parsedStats[key] = TopicPerformance.fromMap(value as Map<String, dynamic>?);
    });

    return UserSubjectPerformance(
      userId: data['userId'] ?? doc.id,
      subjectId: data['subjectId'] ?? '',
      topicsStats: parsedStats,
    );
  }
}
