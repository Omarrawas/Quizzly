import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';

class ExamService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetch all exams (static and generated) for a subject
  Stream<List<ExamConfig>> streamExams(String subjectId) {
    return _db
        .collection(DatabaseService.colExams)
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snap) {
          final exams = snap.docs.map((doc) => ExamConfig.fromFirestore(doc)).toList();
          exams.sort((a, b) {
            // Group by section first
            if (a.sectionId != b.sectionId) {
              return a.sectionId.compareTo(b.sectionId);
            }
            // Sort by order ascending within each section
            if (a.order != b.order) {
              return a.order.compareTo(b.order);
            }
            // Secondary sort by createdAt descending
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            return b.createdAt!.compareTo(a.createdAt!);
          });
          return exams;
        });
  }

  /// Record exam attempt result
  Future<void> recordExamAttempt({
    required String userId,
    required String examId,
    required double score,
    required int timeSpentSeconds,
    required List<Map<String, dynamic>> answers,
    String? subjectId,
    String? examTitle,
    int? totalQuestions,
    int? correctCount,
  }) async {
    final data = {
      'userId': userId,
      'examId': examId,
      'score': score,
      'timeSpent': timeSpentSeconds,
      'answers': answers,
      'completedAt': FieldValue.serverTimestamp(),
    };
    if (subjectId != null) data['subjectId'] = subjectId;
    if (examTitle != null) data['examTitle'] = examTitle;
    if (totalQuestions != null) data['totalQuestions'] = totalQuestions;
    if (correctCount != null) data['correctCount'] = correctCount;

    await _db.collection('exam_attempts').add(data);
  }

  /// Stream the most recent exam attempts for a user, across all subjects
  Stream<List<Map<String, dynamic>>> streamRecentAttempts(
    String userId, {
    int limit = 5,
  }) {
    return _db
        .collection('exam_attempts')
        .where('userId', isEqualTo: userId)
        .orderBy('completedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  /// Stream the most recent exam attempts for a user filtered by subjectId
  Stream<List<Map<String, dynamic>>> streamRecentAttemptsBySubject(
    String userId,
    String subjectId, {
    int limit = 10,
  }) {
    return _db
        .collection('exam_attempts')
        .where('userId', isEqualTo: userId)
        .where('subjectId', isEqualTo: subjectId)
        .orderBy('completedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }
}
