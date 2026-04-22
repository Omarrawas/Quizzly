import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/features/gamification/data/models/gamification_profile.dart';
import 'package:quizzly/features/gamification/data/models/game_mode_models.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';

class GamificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<GamificationProfile> getProfile(String userId) async {
    final doc = await _db.collection('user_gamification').doc(userId).get();
    return GamificationProfile.fromFirestore(doc);
  }

  /// يحسب ويضيف نقاط الخبرة بناءً على الإجابات
  Future<XpResult> processQuizAttempt(String userId, List<Map<String, dynamic>> answers, List<QuizQuestion> questions) async {
    int totalXpGained = 0;

    // 1. Calculate XP for each question
    for (var answer in answers) {
      final qId = answer['questionId'] as String;
      final isCorrect = answer['isCorrect'] as bool;
      final timeSpent = answer['timeSpent'] as int;

      // Find the question to get difficulty and estimatedTime
      final question = questions.firstWhere((q) => q.id == qId || q.text.hashCode.toString() == qId, orElse: () => _defaultQuestion());
      
      totalXpGained += _calculateQuestionXP(question, isCorrect, timeSpent);
    }

    // 2. Fetch current profile
    final profileRef = _db.collection('user_gamification').doc(userId);
    
    return await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(profileRef);
      GamificationProfile currentProfile = GamificationProfile.fromFirestore(snapshot);

      // 3. Process Streak and daily login bonus
      final now = DateTime.now();
      int currentStreak = currentProfile.currentStreak;
      int longestStreak = currentProfile.longestStreak;
      
      if (currentProfile.lastActiveDate != null) {
        final difference = now.difference(currentProfile.lastActiveDate!).inDays;
        
        if (difference == 1) {
          // Continuous day
          currentStreak++;
        } else if (difference > 1) {
          // Streak broken
          currentStreak = 1;
        }
        // if difference == 0, same day, streak doesn't change
      } else {
        currentStreak = 1;
      }

      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }

      // Add streak bonus to total XP
      if (currentStreak > 0) {
        // +5 XP per streak day, max 50
        totalXpGained += min(currentStreak * 5, 50);
      }

      // 4. Calculate new Level
      final int newTotalXp = currentProfile.xp + totalXpGained;
      final int calculatedLevel = GamificationProfile.calculateLevel(newTotalXp);
      final bool hasLeveledUp = calculatedLevel > currentProfile.level;
      final int finalLevel = hasLeveledUp ? calculatedLevel : currentProfile.level;

      // 5. Save updated profile
      final updatedProfile = GamificationProfile(
        userId: userId,
        xp: newTotalXp,
        level: finalLevel,
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        lastActiveDate: now,
        earnedBadges: currentProfile.earnedBadges,
      );

      transaction.set(profileRef, updatedProfile.toMap(), SetOptions(merge: true));

      return XpResult(
        xpGained: totalXpGained,
        newLevel: finalLevel,
        levelUp: hasLeveledUp,
      );
    });
  }

  int _calculateQuestionXP(QuizQuestion q, bool isCorrect, int timeSpent) {
    int xp = 0;
    
    // Base XP
    if (isCorrect) {
      xp += 10;
    } else {
      xp += 2; // Effort points
    }

    // Difficulty Multiplier
    if (isCorrect) {
      if (q.difficulty == Difficulty.medium) xp = (xp * 1.5).toInt();
      if (q.difficulty == Difficulty.hard) xp = (xp * 2.0).toInt();
    }

    // Speed Bonus (answered in less than half the estimated time)
    if (isCorrect && timeSpent < (q.estimatedTime ?? 60) / 2) {
      xp += 5;
    }
    
    return xp;
  }

  /// جلب أنماط اللعب المتاحة للطلاب
  Stream<List<GameModeConfig>> getActiveGameModes() {
    return _db.collection('game_modes')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => GameModeConfig.fromFirestore(d)).toList());
  }

  QuizQuestion _defaultQuestion() {
    return const QuizQuestion(number: 0, text: '', type: QuestionType.mcq, difficulty: Difficulty.easy, estimatedTime: 60);
  }
}
