import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/data/models/smart_quiz_models.dart';

class SmartQuizService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Generate a smart quiz based on user's weak topics and spaced repetition
  Future<List<QuizQuestion>> generateSmartQuiz({
    required String userId,
    required String subjectId,
    int totalQuestions = 10,
  }) async {
    // 1. Fetch user performance for this subject
    final docId = '${userId}_$subjectId';
    final perfDoc = await _db.collection('user_topic_performance').doc(docId).get();
    
    UserSubjectPerformance performance;
    if (perfDoc.exists) {
      performance = UserSubjectPerformance.fromFirestore(perfDoc);
    } else {
      performance = UserSubjectPerformance(userId: userId, subjectId: subjectId, topicsStats: {});
    }

    // 2. Fetch all topics for the subject to ensure we cover unattempted ones
    final topicsSnap = await _db.collection(DatabaseService.colTopics)
        .where('subjectId', isEqualTo: subjectId)
        .get();
    
    final allTopicIds = topicsSnap.docs.map((d) => d.id).toList();

    // 3. Calculate weights for all topics
    Map<String, double> topicWeights = {};
    double totalWeight = 0.0;

    for (var topicId in allTopicIds) {
      double weight = 0.8; // Default weight for unattempted topics

      if (performance.topicsStats.containsKey(topicId)) {
        final stats = performance.topicsStats[topicId]!;
        weight = 1.0 - stats.masteryLevel;
        
        // Spaced Repetition multiplier
        int daysSinceLast = DateTime.now().difference(stats.lastAttemptDate).inDays;
        if (daysSinceLast > 7) {
          weight *= 1.5;
        } else if (daysSinceLast > 3) {
          weight *= 1.2;
        }
      }

      // Ensure minimum weight so it occasionally shows up
      if (weight <= 0.1) weight = 0.1;
      
      topicWeights[topicId] = weight;
      totalWeight += weight;
    }

    // 4. Determine how many questions per topic based on weight proportion
    Map<String, int> targetCounts = {};
    int remainingQuestions = totalQuestions;

    final sortedTopics = topicWeights.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    for (int i = 0; i < sortedTopics.length; i++) {
      final entry = sortedTopics[i];
      if (i == sortedTopics.length - 1) {
        // Last topic gets the remainder to ensure exact total
        targetCounts[entry.key] = remainingQuestions;
      } else {
        int count = ((entry.value / totalWeight) * totalQuestions).round();
        if (count > remainingQuestions) count = remainingQuestions;
        targetCounts[entry.key] = count;
        remainingQuestions -= count;
      }
    }

    // 5. Fetch questions and apply adaptive difficulty
    List<QuizQuestion> smartExam = [];

    for (var entry in targetCounts.entries) {
      if (entry.value <= 0) continue;

      final topicId = entry.key;
      final requiredCount = entry.value;
      
      final mastery = performance.topicsStats[topicId]?.masteryLevel ?? 0.0;
      Difficulty targetDifficulty = Difficulty.medium;
      if (mastery < 0.4) targetDifficulty = Difficulty.easy;
      if (mastery > 0.8) targetDifficulty = Difficulty.hard;

      // Fetch questions for this topic
      final qSnap = await _db.collection(DatabaseService.colQuestions)
          .where('subjectId', isEqualTo: subjectId)
          .where('topicIds', arrayContains: topicId)
          .get();
      
      var questions = qSnap.docs.map((d) => QuizQuestion.fromFirestore(d)).toList();
      questions.shuffle();

      // Prioritize the target difficulty
      var primaryPool = questions.where((q) => q.difficulty == targetDifficulty).toList();
      var secondaryPool = questions.where((q) => q.difficulty != targetDifficulty).toList();

      List<QuizQuestion> selectedForTopic = [];
      selectedForTopic.addAll(primaryPool.take(requiredCount));

      if (selectedForTopic.length < requiredCount) {
        selectedForTopic.addAll(secondaryPool.take(requiredCount - selectedForTopic.length));
      }

      smartExam.addAll(selectedForTopic);
    }

    // 6. Final shuffle and return
    smartExam.shuffle();
    // If we somehow got more or less (due to rounding or lack of questions), ensure hard limit
    if (smartExam.length > totalQuestions) {
      return smartExam.sublist(0, totalQuestions);
    }
    return smartExam;
  }

  /// Called after quiz submission to update topic mastery levels
  Future<void> updateTopicPerformance(String userId, String subjectId, List<Map<String, dynamic>> answers, List<QuizQuestion> questions) async {
    final docId = '${userId}_$subjectId';
    final docRef = _db.collection('user_topic_performance').doc(docId);

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      UserSubjectPerformance currentPerf;
      
      if (snap.exists) {
        currentPerf = UserSubjectPerformance.fromFirestore(snap);
      } else {
        currentPerf = UserSubjectPerformance(userId: userId, subjectId: subjectId, topicsStats: {});
      }

      Map<String, dynamic> updatedTopicsData = {};
      // Copy existing
      currentPerf.topicsStats.forEach((k, v) {
        updatedTopicsData[k] = v.toMap();
      });

      // Update with new answers
      for (var answer in answers) {
        final qId = answer['questionId'] as String;
        final isCorrect = answer['isCorrect'] as bool;

        final question = questions.firstWhere((q) => q.id == qId || q.text.hashCode.toString() == qId);
        
        // A question might belong to multiple topics
        final topicIds = question.topicIds ?? [];
        for (var tId in topicIds) {
          TopicPerformance tPerf = currentPerf.topicsStats[tId] ?? TopicPerformance(lastAttemptDate: DateTime.now());
          tPerf = tPerf.copyWithAttempt(isCorrect);
          updatedTopicsData[tId] = tPerf.toMap();
          
          // update local cache for loop iteration
          currentPerf.topicsStats[tId] = tPerf; 
        }
      }

      transaction.set(docRef, {
        'userId': userId,
        'subjectId': subjectId,
        'topicsData': updatedTopicsData,
      }, SetOptions(merge: true));
    });
  }
  /// Fetch a summary of performance for the UI
  Future<Map<String, dynamic>> getPerformanceSummary(String userId, String subjectId) async {
    final docId = '${userId}_$subjectId';
    final perfSnap = await _db.collection('user_topic_performance').doc(docId).get();
    
    if (!perfSnap.exists) return {'totalMastery': 0.0, 'weakTopics': [], 'strongTopics': []};

    final perf = UserSubjectPerformance.fromFirestore(perfSnap);
    
    // Get all topic names for mapping
    final topicsSnap = await _db.collection(DatabaseService.colTopics)
        .where('subjectId', isEqualTo: subjectId)
        .get();
    
    Map<String, String> topicNames = {
      for (var doc in topicsSnap.docs) doc.id: doc.data()['name'] ?? 'موضوع غير معروف'
    };

    List<Map<String, dynamic>> allStats = [];
    double totalMasterySum = 0;
    int count = 0;

    perf.topicsStats.forEach((topicId, stats) {
      final name = topicNames[topicId] ?? 'موضوع غير معروف';
      allStats.add({
        'id': topicId,
        'name': name,
        'mastery': stats.masteryLevel,
        'attempts': stats.totalAttempts,
      });
      totalMasterySum += stats.masteryLevel;
      count++;
    });

    final avgMastery = count > 0 ? totalMasterySum / count : 0.0;
    
    // Sort by mastery
    allStats.sort((a, b) => (a['mastery'] as double).compareTo(b['mastery'] as double));
    
    final weak = allStats.where((s) => s['mastery'] < 0.5).take(3).toList();
    final strong = allStats.where((s) => s['mastery'] >= 0.8).take(3).toList();

    return {
      'totalMastery': avgMastery,
      'allStats': allStats,
      'weakTopics': weak,
      'strongTopics': strong,
    };
  }
}
