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
    return streamFavoriteQuestions(userId, subjectId).map((list) => list.length);
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
        .where('isArchived', isNotEqualTo: true) // Filter out archived
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Stream of archived question IDs for a user and subject
  Stream<Set<String>> streamArchivedQuestionIds(String userId, String subjectId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('mastery')
        .where('subjectId', isEqualTo: subjectId)
        .where('isArchived', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toSet());
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
    // 1. Stream the question IDs for this subject
    final subjectQuestionsStream = _db
        .collection('questions')
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toSet());

    // 2. Stream all favorites
    final favoritesStream = _db
        .collection('users')
        .doc(userId)
        .collection('user_lists')
        .doc('favorites')
        .collection('questions')
        .snapshots()
        .map((snap) {
          return snap.docs.map((doc) {
            final data = doc.data();
            final qData = data['questionData'] as Map<String, dynamic>;
            return QuizQuestion.fromMap(qData, doc.id);
          }).toList();
        });

    // 3. Combine and filter
    return Rx.combineLatest3(
      favoritesStream,
      subjectQuestionsStream,
      streamArchivedQuestionIds(userId, subjectId),
      (List<QuizQuestion> favorites, Set<String> subjectQuestionIds, Set<String> archivedIds) {
        return favorites.where((q) {
          if (q.id == null) return false;
          if (archivedIds.contains(q.id)) return false; // Filter archived
          return q.subjectId == subjectId || subjectQuestionIds.contains(q.id);
        }).toList();
      },
    );
  }

  /// Stream of questions answered incorrectly
  Stream<List<QuizQuestion>> streamWrongQuestions(String userId, String subjectId) {
    return Rx.combineLatest2(
      _db.collection('user_history').doc(userId).snapshots(),
      streamArchivedQuestionIds(userId, subjectId),
      (DocumentSnapshot userSnap, Set<String> archivedIds) {
        if (!userSnap.exists) return <String>[];
        final data = userSnap.data() as Map<String, dynamic>;
        final List<dynamic> wrongIds = data['wrongAnswers_$subjectId'] ?? [];
        return wrongIds.where((id) => !archivedIds.contains(id)).toList();
      },
    ).switchMap((wrongIds) {
      if (wrongIds.isEmpty) return Stream.value([]);

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

  /// Stream of archived questions for a subject
  Stream<List<QuizQuestion>> streamArchivedQuestions(String userId, String subjectId) {
    return streamArchivedQuestionIds(userId, subjectId).switchMap((archivedIds) {
      if (archivedIds.isEmpty) return Stream.value([]);
      
      return _db
          .collection('questions')
          .where('subjectId', isEqualTo: subjectId)
          .snapshots()
          .map((qSnap) {
            return qSnap.docs
                .map((doc) => QuizQuestion.fromFirestore(doc))
                .where((q) => archivedIds.contains(q.id))
                .toList();
          });
    });
  }
}
