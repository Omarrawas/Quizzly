import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';

class ExamGeneratorService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<QuizQuestion>> generateExam(ExamConfig config, {String? userId}) async {
    if (config.type == ExamType.static) {
      return _generateStaticExam(config);
    } else {
      return _generateDynamicExam(config, userId: userId);
    }
  }

  Future<List<QuizQuestion>> _generateStaticExam(ExamConfig config) async {
    if (config.staticQuestionIds.isEmpty) return [];

    // Note: Firestore 'whereIn' limits to 10 items.
    // If an exam has more than 10 questions, we need to batch the requests.
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
    final unseenPool = allQuestions.where((q) => !seenIds.contains(q.id)).toList();
    final wrongPool = allQuestions.where((q) => wrongIds.contains(q.id)).toList();
    final seenPool = allQuestions.where((q) => seenIds.contains(q.id) && !wrongIds.contains(q.id)).toList();

    // 4. Calculate target counts
    final int total = config.totalQuestions;
    int easyCount = (total * (rules.difficultyDistribution[Difficulty.easy] ?? 0) / 100).round();
    int mediumCount = (total * (rules.difficultyDistribution[Difficulty.medium] ?? 0) / 100).round();
    int hardCount = total - (easyCount + mediumCount);

    List<QuizQuestion> finalExam = [];

    // Helper to pull questions across priority buckets
    List<QuizQuestion> pullQuestions(Difficulty diff, int requiredCount) {
      List<QuizQuestion> selected = [];
      
      // Pull from unseen
      var unseenDiff = unseenPool.where((q) => q.difficulty == diff).toList()..shuffle();
      selected.addAll(unseenDiff.take(requiredCount));
      
      // If we need more, pull from wrong
      if (selected.length < requiredCount) {
        var wrongDiff = wrongPool.where((q) => q.difficulty == diff).toList()..shuffle();
        selected.addAll(wrongDiff.take(requiredCount - selected.length));
      }

      // If we STILL need more, pull from seen
      if (selected.length < requiredCount) {
        var seenDiff = seenPool.where((q) => q.difficulty == diff).toList()..shuffle();
        selected.addAll(seenDiff.take(requiredCount - selected.length));
      }

      return selected;
    }

    finalExam.addAll(pullQuestions(Difficulty.easy, easyCount));
    finalExam.addAll(pullQuestions(Difficulty.medium, mediumCount));
    finalExam.addAll(pullQuestions(Difficulty.hard, hardCount));

    // 5. If we fall short due to a specific difficulty missing entirely, borrow from ANY difficulty
    if (finalExam.length < total) {
      final selectedIds = finalExam.map((e) => e.id).toSet();
      
      // Borrow from unseen
      var remainingUnseen = unseenPool.where((q) => !selectedIds.contains(q.id)).toList()..shuffle();
      finalExam.addAll(remainingUnseen.take(total - finalExam.length));

      // Borrow from wrong
      if (finalExam.length < total) {
        var remainingWrong = wrongPool.where((q) => !selectedIds.contains(q.id)).toList()..shuffle();
        finalExam.addAll(remainingWrong.take(total - finalExam.length));
      }

      // Borrow from seen
      if (finalExam.length < total) {
        var remainingSeen = seenPool.where((q) => !selectedIds.contains(q.id)).toList()..shuffle();
        finalExam.addAll(remainingSeen.take(total - finalExam.length));
      }
    }

    // 6. Final shuffle
    finalExam.shuffle();
    return finalExam;
  }


  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    List<List<T>> chunks = [];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return chunks;
  }
}
