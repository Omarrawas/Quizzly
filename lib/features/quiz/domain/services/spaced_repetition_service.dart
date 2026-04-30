import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/features/quiz/data/models/mastery_models.dart';

class SpacedRepetitionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Update mastery for a question based on user performance
  /// [quality] rating 0-5 (0=blackout, 5=perfect)
  Future<void> updateMastery({
    required String userId,
    required String questionId,
    required String subjectId,
    required int quality,
  }) async {
    final docRef = _db
        .collection('users')
        .doc(userId)
        .collection('mastery')
        .doc(questionId);

    final snap = await docRef.get();
    QuestionMastery mastery;

    if (snap.exists) {
      mastery = QuestionMastery.fromMap(snap.data()!);
    } else {
      mastery = QuestionMastery(
        questionId: questionId,
        subjectId: subjectId,
        lastReview: DateTime.now(),
        nextReview: DateTime.now(),
      );
    }

    // SM-2 Algorithm Calculation
    int nextInterval;
    double nextEaseFactor = mastery.easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (nextEaseFactor < 1.3) nextEaseFactor = 1.3;

    int nextConsecutiveCorrect = quality >= 3 ? mastery.consecutiveCorrect + 1 : 0;

    if (quality < 3) {
      nextInterval = 1; // Repeat tomorrow if failed
    } else {
      if (nextConsecutiveCorrect == 1) {
        nextInterval = 1;
      } else if (nextConsecutiveCorrect == 2) {
        nextInterval = 4;
      } else {
        nextInterval = (mastery.interval * nextEaseFactor).round();
      }
    }

    final now = DateTime.now();
    final updatedMastery = QuestionMastery(
      questionId: questionId,
      subjectId: subjectId,
      lastReview: now,
      nextReview: now.add(Duration(days: nextInterval)),
      interval: nextInterval,
      easeFactor: nextEaseFactor,
      consecutiveCorrect: nextConsecutiveCorrect,
    );

    await docRef.set(updatedMastery.toMap());

    // Update global user history for Wrong Answers screen
    final historyRef = _db.collection('user_history').doc(userId);
    final isCorrect = quality >= 3;
    
    await _db.runTransaction((transaction) async {
      transaction.set(historyRef, {
        'seenQuestions': FieldValue.arrayUnion([questionId]),
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (isCorrect) {
        transaction.update(historyRef, {
          'wrongAnswers_$subjectId': FieldValue.arrayRemove([questionId]),
        });
      } else {
        transaction.set(historyRef, {
          'wrongAnswers_$subjectId': FieldValue.arrayUnion([questionId]),
        }, SetOptions(merge: true));
      }
    });
  }

  /// Get questions due for review today
  Future<List<String>> getDueQuestionIds(String userId, String subjectId, {int limit = 10}) async {
    final now = DateTime.now().toIso8601String();
    final snap = await _db
        .collection('users')
        .doc(userId)
        .collection('mastery')
        .where('subjectId', isEqualTo: subjectId)
        .where('nextReview', isLessThanOrEqualTo: now)
        .limit(limit)
        .get();

    return snap.docs.map((d) => d.id).toList();
  }
}
