import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/domain/services/exam_generator_service.dart';

class CramModeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ExamGeneratorService _generatorService = ExamGeneratorService();

  /// Generates a "Cram Session" of the most critical questions
  Future<List<QuizQuestion>> generateCramSession(String userId, String subjectId) async {
    // 1. Get Wrong Answer IDs
    final historyDoc = await _db.collection('user_history').doc(userId).get();
    Set<String> criticalIds = {};
    
    if (historyDoc.exists) {
      final data = historyDoc.data()!;
      final wrongField = 'wrongAnswers_$subjectId';
      criticalIds.addAll(List<String>.from(data[wrongField] ?? []));
    }

    // 2. Get Favorite Question IDs for this subject
    final favoritesSnap = await _db
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .where('questionData.subjectId', isEqualTo: subjectId)
        .get();
    criticalIds.addAll(favoritesSnap.docs.map((d) => d.id));

    // 3. Get low mastery questions (those with consecutiveCorrect < 2)
    // We filter in memory to avoid needing a composite index in Firestore
    final masterySnap = await _db
        .collection('users')
        .doc(userId)
        .collection('mastery')
        .where('subjectId', isEqualTo: subjectId)
        .get();
    
    final lowMasteryIds = masterySnap.docs
        .where((doc) {
          final data = doc.data();
          final consecutiveCorrect = data['consecutiveCorrect'] as num? ?? 0;
          return consecutiveCorrect < 2;
        })
        .map((doc) => doc.id)
        .take(20);
        
    criticalIds.addAll(lowMasteryIds);

    if (criticalIds.isEmpty) {
      // Fallback: If no critical questions, just get some random ones from the bank
      return _generatorService.generateExam(
        ExamConfig(
          title: 'مراجعة عامة',
          subjectId: subjectId,
          totalQuestions: 15,
          type: ExamType.bank,
          durationSeconds: 900,
          passingScore: 60,
          sectionId: 'cram_fallback',
          generationRules: const GenerationRules(topicIds: []),
        ),
        userId: userId,
      );
    }

    // 4. Fetch the actual question objects
    final questions = await _generatorService.getQuestionsByIds(criticalIds.toList());
    questions.shuffle();
    return questions.take(30).toList(); // Limit cram session size for focus
  }
}
