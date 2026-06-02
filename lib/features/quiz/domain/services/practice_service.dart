import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';

class PracticeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetch topics for a subject
  Future<List<Map<String, dynamic>>> getTopicsForSubject(String subjectId) async {
    final snap = await _db
        .collection('topics')
        .where('subjectId', isEqualTo: subjectId)
        .get();
        
    final List<Map<String, dynamic>> topics = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    
    // Sort in memory to avoid Firestore multi-field index requirement
    topics.sort((a, b) {
      final int orderA = (a['order'] as num?)?.toInt() ?? 999999;
      final int orderB = (b['order'] as num?)?.toInt() ?? 999999;
      
      if (orderA != orderB) {
        return orderA.compareTo(orderB);
      }
      
      final Timestamp? timeA = a['createdAt'] as Timestamp?;
      final Timestamp? timeB = b['createdAt'] as Timestamp?;
      if (timeA == null || timeB == null) return 0;
      return timeA.compareTo(timeB);
    });
    
    return topics;
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
        .get();

    List<QuizQuestion> questions = snap.docs.map((d) => QuizQuestion.fromFirestore(d)).toList();

    if (topicIds != null && topicIds.isNotEmpty) {
      questions = questions.where((q) {
        bool matchesArray = q.topicIds != null && q.topicIds!.any((id) => topicIds.contains(id));
        bool matchesPrimary = q.primaryTopicId != null && topicIds.contains(q.primaryTopicId);
        return matchesArray || matchesPrimary;
      }).toList();
    }

    if (difficulty != null) {
      questions = questions.where((q) => q.difficulty == difficulty).toList();
    }

    questions.shuffle();
    
    // Also shuffle options for each question to ensure variety
    for (int i = 0; i < questions.length; i++) {
      if (questions[i].options != null && questions[i].options!.isNotEmpty) {
        final shuffledOptions = List<QuizOption>.from(questions[i].options!)..shuffle();
        questions[i] = questions[i].copyWith(options: shuffledOptions);
      }
    }

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
        .where('difficulty', isEqualTo: difficulty.name)
        .get();

    final filtered = snap.docs
        .map((d) => QuizQuestion.fromFirestore(d))
        .where((q) => q.id != currentQuestionId)
        .where((q) {
          bool matchesArray = q.topicIds != null && q.topicIds!.any((id) => topicIds.contains(id));
          bool matchesPrimary = q.primaryTopicId != null && topicIds.contains(q.primaryTopicId);
          return matchesArray || matchesPrimary;
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
