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
    Query query = _db
        .collection('questions')
        .where('subjectId', isEqualTo: subjectId)
        .where('status', isEqualTo: QuestionStatus.approved.name);

    if (topicIds != null && topicIds.isNotEmpty) {
      query = query.where('topicIds', arrayContainsAny: topicIds);
    }
    if (difficulty != null) {
      query = query.where('difficulty', isEqualTo: difficulty.name);
    }

    final snap = await query.limit(limit).get();
    final questions = snap.docs.map((d) => QuizQuestion.fromFirestore(d)).toList();
    questions.shuffle(); // Randomize order
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
        .where('topicIds', arrayContainsAny: topicIds)
        .where('difficulty', isEqualTo: difficulty.name)
        .limit(10)
        .get();

    final filtered = snap.docs
        .where((d) => d.id != currentQuestionId)
        .map((d) => QuizQuestion.fromFirestore(d))
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
