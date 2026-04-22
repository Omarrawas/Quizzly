import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';

class ContentModerationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Submit a new question (draft -> pendingReview)
  Future<void> submitQuestionForReview(QuizQuestion question, String authorId) async {
    final docRef = _db.collection('questions').doc(question.id); // Assuming ID is generated
    
    // Convert to map and ensure status is pendingReview
    final data = question.toMap();
    data['status'] = QuestionStatus.pendingReview.name;
    data['authorId'] = authorId;
    data['createdAt'] = FieldValue.serverTimestamp();

    await docRef.set(data, SetOptions(merge: true));
  }

  /// Review a question (approve or reject)
  Future<void> reviewQuestion(String questionId, bool approve, String reviewerId, {String? feedback}) async {
    final docRef = _db.collection('questions').doc(questionId);
    
    final status = approve ? QuestionStatus.approved : QuestionStatus.rejected;
    
    await docRef.update({
      'status': status.name,
      'reviewerId': reviewerId,
      'reviewFeedback': feedback ?? FieldValue.delete(),
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Edit an existing question, saving previous version to history
  Future<void> editQuestion(QuizQuestion newQuestion, String authorId) async {
    if (newQuestion.id == null) return;
    
    final docRef = _db.collection('questions').doc(newQuestion.id);
    
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      
      if (snapshot.exists) {
        // 1. Save previous data to history
        final previousData = snapshot.data();
        final historyRef = _db.collection('question_history').doc();
        
        transaction.set(historyRef, {
          'questionId': newQuestion.id,
          'previousData': previousData,
          'modifiedBy': authorId,
          'modifiedAt': FieldValue.serverTimestamp(),
        });
      }

      // 2. Update the question and reset status to pendingReview
      final newData = newQuestion.toMap();
      newData['status'] = QuestionStatus.pendingReview.name;
      newData['authorId'] = authorId;
      // Clear old review fields
      newData['reviewFeedback'] = FieldValue.delete();
      newData['reviewerId'] = FieldValue.delete();

      transaction.set(docRef, newData, SetOptions(merge: true));
    });
  }

  /// Fetch pending questions for reviewers
  Stream<List<QuizQuestion>> getPendingQuestions() {
    return _db.collection('questions')
        .where('status', isEqualTo: QuestionStatus.pendingReview.name)
        .snapshots()
        .map((snap) => snap.docs.map((d) => QuizQuestion.fromFirestore(d)).toList());
  }
}
