import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';

class ExamService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetch all exams (static and generated) for a subject
  Stream<List<ExamConfig>> streamExams(String subjectId) {
    return _db.collection(DatabaseService.colExams)
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ExamConfig.fromFirestore(doc)).toList());
  }

  /// Record exam attempt result
  Future<void> recordExamAttempt({
    required String userId,
    required String examId,
    required double score,
    required int timeSpentSeconds,
    required List<Map<String, dynamic>> answers,
  }) async {
    await _db.collection('exam_attempts').add({
      'userId': userId,
      'examId': examId,
      'score': score,
      'timeSpent': timeSpentSeconds,
      'answers': answers,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }
}
