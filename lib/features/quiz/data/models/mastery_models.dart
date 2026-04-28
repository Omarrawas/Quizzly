class QuestionMastery {
  final String questionId;
  final String subjectId;
  final DateTime lastReview;
  final DateTime nextReview;
  final int interval; // in days
  final double easeFactor;
  final int consecutiveCorrect;

  QuestionMastery({
    required this.questionId,
    required this.subjectId,
    required this.lastReview,
    required this.nextReview,
    this.interval = 0,
    this.easeFactor = 2.5,
    this.consecutiveCorrect = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'subjectId': subjectId,
      'lastReview': lastReview.toIso8601String(),
      'nextReview': nextReview.toIso8601String(),
      'interval': interval,
      'easeFactor': easeFactor,
      'consecutiveCorrect': consecutiveCorrect,
    };
  }

  factory QuestionMastery.fromMap(Map<String, dynamic> map) {
    return QuestionMastery(
      questionId: map['questionId'],
      subjectId: map['subjectId'],
      lastReview: DateTime.parse(map['lastReview']),
      nextReview: DateTime.parse(map['nextReview']),
      interval: map['interval'] ?? 0,
      easeFactor: (map['easeFactor'] as num?)?.toDouble() ?? 2.5,
      consecutiveCorrect: map['consecutiveCorrect'] ?? 0,
    );
  }
}
