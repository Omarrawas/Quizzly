import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:rxdart/rxdart.dart';

class SubjectStatsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream of total exams count for a subject
  Stream<int> streamExamsCount(String subjectId) {
    return _db
        .collection('exams')
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Stream of total unique topics/tags found in questions
  Stream<int> streamTopicsCount(String subjectId) {
    return _db
        .collection('questions')
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snap) {
          final Set<String> tags = {};
          for (var doc in snap.docs) {
            final data = doc.data();
            final List<dynamic>? names = data['topicNames'];
            if (names != null) {
              for (var name in names) {
                final tag = name.toString().trim();
                if (tag.isNotEmpty) tags.add(tag);
              }
            }
          }
          return tags.length;
        });
  }

  /// Stream of wrong answers count for a specific subject
  /// Note: Currently this is a global count in user_history. 
  /// In a real app, we'd filter these by subjectId if the schema supports it.
  Stream<int> streamWrongAnswersCount(String userId, String subjectId) {
    return _db
        .collection('user_history')
        .doc(userId)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return 0;
          final data = snap.data() as Map<String, dynamic>;
          final List<dynamic> wrong = data['wrongAnswers_$subjectId'] ?? [];
          return wrong.length;
        });
  }

  /// Stream of favorites count for a subject
  Stream<int> streamFavoritesCount(String userId, String subjectId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('user_lists')
        .doc('favorites')
        .collection('questions')
        .where('questionData.subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Stream of questions due for review based on Spaced Repetition (SRS)
  Stream<int> streamDueQuestionsCount(String userId, String subjectId) {
    final now = DateTime.now().toIso8601String();
    return _db
        .collection('users')
        .doc(userId)
        .collection('mastery')
        .where('subjectId', isEqualTo: subjectId)
        .where('nextReview', isLessThanOrEqualTo: now)
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Stream of total questions count for a subject (Search counter)
  Stream<int> streamQuestionsCount(String subjectId) {
    return _db
        .collection('questions')
        .where('subjectId', isEqualTo: subjectId)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Stream of custom practice sessions created by the user
  Stream<int> streamPracticeCount(String userId, String subjectId) {
    return _db
        .collection('practice_sessions')
        .where('userId', isEqualTo: userId)
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Stream of practical topics count for a subject
  Stream<int> streamPracticalTopicsCount(String subjectId) {
    return _db
        .collection('topics')
        .where('subjectId', isEqualTo: subjectId)
        .where('type', isEqualTo: 'practical')
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Stream of favorite questions for a subject
  Stream<List<QuizQuestion>> streamFavoriteQuestions(String userId, String subjectId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('user_lists')
        .doc('favorites')
        .collection('questions')
        .where('questionData.subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snap) {
          return snap.docs.map((doc) {
            final data = doc.data();
            final qData = data['questionData'] as Map<String, dynamic>;
            return QuizQuestion.fromMap(qData, doc.id);
          }).toList();
        });
  }

  /// Stream of questions answered incorrectly
  Stream<List<QuizQuestion>> streamWrongQuestions(String userId, String subjectId) {
    return _db
        .collection('user_history')
        .doc(userId)
        .snapshots()
        .switchMap((userSnap) {
          if (!userSnap.exists) return Stream.value([]);
          final data = userSnap.data() as Map<String, dynamic>;
          final List<dynamic> wrongIds = data['wrongAnswers_$subjectId'] ?? [];
          if (wrongIds.isEmpty) return Stream.value([]);

          // Firestore has a limit of 10-30 in 'whereIn'. For simplicity, fetch all subject questions and filter.
          // In a high-scale app, we would fetch by individual IDs or chunks.
          return _db
              .collection('questions')
              .where('subjectId', isEqualTo: subjectId)
              .snapshots()
              .map((qSnap) {
                return qSnap.docs
                    .map((doc) => QuizQuestion.fromFirestore(doc))
                    .where((q) => wrongIds.contains(q.id))
                    .toList();
              });
        });
  }

  /// Combined stream of favorites and wrong answers
  Stream<List<QuizQuestion>> streamAllProblematicQuestions(String userId, String subjectId) {
    return Rx.combineLatest2(
      streamFavoriteQuestions(userId, subjectId),
      streamWrongQuestions(userId, subjectId),
      (List<QuizQuestion> favs, List<QuizQuestion> wrongs) {
        // Merge and remove duplicates
        final Map<String, QuizQuestion> all = {};
        for (var q in favs) {
          if (q.id != null) all[q.id!] = q;
        }
        for (var q in wrongs) {
          if (q.id != null) all[q.id!] = q;
        }
        return all.values.toList();
      },
    );
  }
}
