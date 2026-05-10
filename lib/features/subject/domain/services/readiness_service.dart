import 'package:cloud_firestore/cloud_firestore.dart';

class ReadinessService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream of subject readiness score (0.0 to 1.0)
  Stream<double> streamReadinessScore(String userId, String subjectId) {
    // Listen to mastery snapshots and fetch total approved questions count
    return _db
        .collection('users')
        .doc(userId)
        .collection('mastery')
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .asyncMap((masterySnap) async {
          try {
            final totalQuestionsSnap = await _db
                .collection('questions')
                .where('subjectId', isEqualTo: subjectId)
                .get();

            final totalQuestions = totalQuestionsSnap.size;
            if (totalQuestions == 0) return 0.0;

            final masteredDocs = masterySnap.docs;

            // 1. Coverage Component (40% weight)
            // How many questions has the student seen out of the total?
            double coverage = masteredDocs.length / totalQuestions;
            if (coverage > 1.0) coverage = 1.0;

            // 2. Mastery Component (60% weight)
            // Average performance of seen questions
            if (masteredDocs.isEmpty) return (coverage * 0.4);

            double totalMasteryFactor = 0;
            for (var doc in masteredDocs) {
              final data = doc.data();
              final consecutiveCorrect = (data['consecutiveCorrect'] ?? 0) as int;
              final interval = (data['interval'] ?? 0) as int;

              // Factor formula: 
              // 3+ consecutive correct = 0.5 points
              // 7+ days interval = 0.5 points
              double factor = ((consecutiveCorrect / 3) * 0.5 + (interval / 7) * 0.5).clamp(0.0, 1.0);
              totalMasteryFactor += factor;
            }
            double averageMastery = totalMasteryFactor / masteredDocs.length;

            // Final score combining both
            double score = (coverage * 0.4) + (averageMastery * 0.6);
            return score.clamp(0.0, 1.0);
          } catch (e) {
            return 0.0;
          }
        });
  }

  /// Get readiness breakdown by topic
  Future<Map<String, double>> getTopicReadiness(String userId, String subjectId) async {
    try {
      final masterySnap = await _db
          .collection('users')
          .doc(userId)
          .collection('mastery')
          .where('subjectId', isEqualTo: subjectId)
          .get();

      final questionsSnap = await _db
          .collection('questions')
          .where('subjectId', isEqualTo: subjectId)
          .get();

      Map<String, List<String>> topicToQuestions = {};
      for (var doc in questionsSnap.docs) {
        final data = doc.data();
        // Use topicNames or topicIds for grouping (topicNames is usually more human-readable for the UI)
        final List<String> topics = List<String>.from(data['topicNames'] ?? data['topicIds'] ?? []);
        for (var tId in topics) {
          topicToQuestions.putIfAbsent(tId, () => []).add(doc.id);
        }
      }

      Map<String, double> topicScores = {};
      final masteryMap = {for (var d in masterySnap.docs) d.id: d.data()};

      for (var entry in topicToQuestions.entries) {
        final topicId = entry.key;
        final qIds = entry.value;

        double totalTopicFactor = 0;
        int seenCount = 0;

        for (var qId in qIds) {
          if (masteryMap.containsKey(qId)) {
            seenCount++;
            final m = masteryMap[qId]!;
            final cc = (m['consecutiveCorrect'] ?? 0) as int;
            final inv = (m['interval'] ?? 0) as int;
            totalTopicFactor += ((cc / 3) * 0.5 + (inv / 7) * 0.5).clamp(0.0, 1.0);
          }
        }

        double coverage = seenCount / qIds.length;
        double mastery = seenCount > 0 ? totalTopicFactor / seenCount : 0.0;
        topicScores[topicId] = (coverage * 0.4 + mastery * 0.6).clamp(0.0, 1.0);
      }

      return topicScores;
    } catch (e) {
      return {};
    }
  }
}
