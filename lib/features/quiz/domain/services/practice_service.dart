import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';

class PracticeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetch topics for a subject
  Future<List<Map<String, dynamic>>> getTopicsForSubject(String subjectId) async {
    final snap = await _db
        .collection('topics')
        .where('subjectId', isEqualTo: subjectId)
        .orderBy('order')
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Fetch approved questions for given topic IDs (or all topics in subject)
  Future<List<QuizQuestion>> fetchPracticeQuestions({
    required String subjectId,
    List<String>? topicIds,
    Difficulty? difficulty,
    int limit = 20,
  }) async {
    final snap = await _db
        .collection('questions')
        .where('subjectId', isEqualTo: subjectId)
        .where('status', isEqualTo: QuestionStatus.approved.name)
        .get();

    List<QuizQuestion> questions = snap.docs.map((d) => QuizQuestion.fromFirestore(d)).toList();

    if (topicIds != null && topicIds.isNotEmpty) {
      questions = questions.where((q) {
        if (q.topicIds == null) return false;
        return q.topicIds!.any((id) => topicIds.contains(id));
      }).toList();
    }

    if (difficulty != null) {
      questions = questions.where((q) => q.difficulty == difficulty).toList();
    }

    questions.shuffle();
    if (questions.length > limit) {
      questions = questions.sublist(0, limit);
    }
    return questions;
  }

  /// Fetch a "similar" question: same topic + same difficulty, different ID
  Future<QuizQuestion?> fetchSimilarQuestion({
    required String subjectId,
    required String currentQuestionId,
    required List<String> topicIds,
    required Difficulty difficulty,
  }) async {
    if (topicIds.isEmpty) return null;

    final snap = await _db
        .collection('questions')
        .where('subjectId', isEqualTo: subjectId)
        .where('status', isEqualTo: QuestionStatus.approved.name)
        .where('difficulty', isEqualTo: difficulty.name)
        .get();

    final filtered = snap.docs
        .map((d) => QuizQuestion.fromFirestore(d))
        .where((q) => q.id != currentQuestionId)
        .where((q) {
          if (q.topicIds == null) return false;
          return q.topicIds!.any((id) => topicIds.contains(id));
        })
        .toList();

    if (filtered.isEmpty) return null;
    filtered.shuffle();
    return filtered.first;
  }

  /// Record a practice answer for analytics
  Future<void> recordAnswer({
    required String questionId,
    required bool isCorrect,
    required int timeSpentSeconds,
  }) async {
    final ref = _db.collection('questions').doc(questionId);
    await ref.update({
      'analytics.timesAnswered': FieldValue.increment(1),
      if (isCorrect) 'analytics.correctAnswers': FieldValue.increment(1),
      'analytics.totalTimeSpent': FieldValue.increment(timeSpentSeconds),
    });
  }
}
