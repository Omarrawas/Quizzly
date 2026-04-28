import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';

class ExamGeneratorService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<QuizQuestion>> generateExam(ExamConfig config, {String? userId}) async {
    if (config.type == ExamType.dora) {
      return _generateStaticExam(config);
    } else {
      return _generateDynamicExam(config, userId: userId);
    }
  }

  Future<List<QuizQuestion>> _generateStaticExam(ExamConfig config) async {
    if (config.staticQuestionIds.isEmpty) return [];

    List<QuizQuestion> questions = [];
    final chunks = _chunkList(config.staticQuestionIds, 10);

    for (var chunk in chunks) {
      final snap = await _db
          .collection(DatabaseService.colQuestions)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      
      questions.addAll(snap.docs.map((d) => QuizQuestion.fromFirestore(d)));
    }

    return questions;
  }

  Future<List<QuizQuestion>> _generateDynamicExam(ExamConfig config, {String? userId}) async {
    final rules = config.generationRules;
    if (rules == null) return [];

    // 1. Fetch user history if userId is provided
    Set<String> seenIds = {};
    Set<String> wrongIds = {};
    
    if (userId != null) {
      final historyDoc = await _db.collection('user_history').doc(userId).get();
      if (historyDoc.exists) {
        final data = historyDoc.data()!;
        seenIds = Set<String>.from(data['seenQuestions'] ?? []);
        wrongIds = Set<String>.from(data['wrongAnswers'] ?? []);
      }
    }

    // 2. Fetch all questions matching subject and topics
    Query query = _db.collection(DatabaseService.colQuestions)
        .where('subjectId', isEqualTo: config.subjectId);
    
    if (rules.topicIds.isNotEmpty) {
      query = query.where('topicIds', arrayContainsAny: rules.topicIds);
    }

    final snap = await query.get();
    final allQuestions = snap.docs.map((d) => QuizQuestion.fromFirestore(d)).toList();

    // 3. Separate questions into priority buckets (Unseen > Wrong > Seen)
    final unseenPool = allQuestions.where((q) => !seenIds.contains(q.id)).toList()..shuffle();
    final wrongPool = allQuestions.where((q) => wrongIds.contains(q.id)).toList()..shuffle();
    final seenPool = allQuestions.where((q) => seenIds.contains(q.id) && !wrongIds.contains(q.id)).toList()..shuffle();

    // 4. Fill final exam with priority
    final int total = config.totalQuestions;
    List<QuizQuestion> finalExam = [];

    finalExam.addAll(unseenPool.take(total));
    
    if (finalExam.length < total) {
      finalExam.addAll(wrongPool.take(total - finalExam.length));
    }

    if (finalExam.length < total) {
      finalExam.addAll(seenPool.take(total - finalExam.length));
    }

    // 5. Final shuffle
    finalExam.shuffle();
    return finalExam;
  }

  Future<List<QuizQuestion>> getQuestionsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    List<QuizQuestion> questions = [];
    final chunks = _chunkList(ids, 10);

    for (var chunk in chunks) {
      final snap = await _db
          .collection(DatabaseService.colQuestions)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      
      questions.addAll(snap.docs.map((d) => QuizQuestion.fromFirestore(d)));
    }

    return questions;
  }


  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    List<List<T>> chunks = [];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return chunks;
  }
}
