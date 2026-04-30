import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectStatsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream of total exams count for a subject
  Stream<int> streamExamsCount(String subjectId) {
    return _db
        .collection('exams')
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Stream of total topics/classifications count for a subject
  Stream<int> streamTopicsCount(String subjectId) {
    return _db
        .collection('topics')
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Stream of wrong answers count for a specific subject
  /// Note: Currently this is a global count in user_history. 
  /// In a real app, we'd filter these by subjectId if the schema supports it.
  Stream<int> streamWrongAnswersCount(String userId, String subjectId) {
    // For now, we fetch from user_history.
    // Optimization: In a production app, we would store wrong_answers per subject.
    return _db
        .collection('user_history')
        .doc(userId)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return 0;
          final data = snap.data() as Map<String, dynamic>;
          final List<dynamic> wrong = data['wrongAnswers'] ?? [];
          return wrong.length; // This is global, but we show it as a starting point
        });
  }

  /// Stream of favorites count for a subject
  Stream<int> streamFavoritesCount(String userId, String subjectId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .where('questionData.subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Stream of questions due for review based on Spaced Repetition (SRS)
  Stream<int> streamDueQuestionsCount(String userId, String subjectId) {
    final now = DateTime.now().toIso8601String();
    return _db
        .collection('users')
        .doc(userId)
        .collection('mastery')
        .where('subjectId', isEqualTo: subjectId)
        .where('nextReview', isLessThanOrEqualTo: now)
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Stream of total questions count for a subject (Search counter)
  Stream<int> streamQuestionsCount(String subjectId) {
    return _db
        .collection('questions')
        .where('subjectId', isEqualTo: subjectId)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Stream of custom practice sessions created by the user
  Stream<int> streamPracticeCount(String userId, String subjectId) {
    return _db
        .collection('practice_sessions')
        .where('userId', isEqualTo: userId)
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snap) => snap.size);
  }
}
