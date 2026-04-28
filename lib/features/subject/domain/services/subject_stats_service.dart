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
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snap) => snap.size);
  }
}
