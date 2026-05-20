import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SubjectLeagueService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const List<String> leagues = ['bronze', 'silver', 'gold', 'diamond'];

  DateTime _getStartOfWeek(DateTime date) {
    // Find the Sunday of the current week
    int daysToSubtract = date.weekday % 7;
    final start = date.subtract(Duration(days: daysToSubtract));
    return DateTime(start.year, start.month, start.day);
  }

  String getCurrentWeekId() {
    final start = _getStartOfWeek(DateTime.now());
    return '${start.year}_${start.month.toString().padLeft(2, '0')}_${start.day.toString().padLeft(2, '0')}';
  }

  String getPreviousWeekId() {
    final lastSunday = _getStartOfWeek(DateTime.now().subtract(const Duration(days: 7)));
    return '${lastSunday.year}_${lastSunday.month.toString().padLeft(2, '0')}_${lastSunday.day.toString().padLeft(2, '0')}';
  }

  /// يضيف نقاط XP للمستخدم في مادة محددة للأسبوع الحالي
  Future<void> addSubjectXp({
    required String userId,
    required String subjectId,
    required int xpGained,
    required String userName,
    String? userAvatar,
  }) async {
    if (xpGained <= 0) return;

    final currentWeekId = getCurrentWeekId();
    final activeDocRef = _db.collection('user_subject_leagues').doc('${userId}_$subjectId');

    // 1. تحقق أولاً من انتهاء الأسبوع المنصرم وإعادة التهيئة
    await checkAndApplyWeeklyReset(
      userId: userId,
      subjectId: subjectId,
      userName: userName,
      userAvatar: userAvatar,
    );

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(activeDocRef);

      if (!snap.exists) {
        // إنشاء مستند جديد
        final data = {
          'userId': userId,
          'userName': userName,
          'userAvatar': userAvatar,
          'subjectId': subjectId,
          'weeklyXp': xpGained,
          'weekIdentifier': currentWeekId,
          'league': 'bronze',
          'lastUpdated': FieldValue.serverTimestamp(),
        };
        transaction.set(activeDocRef, data);

        // حفظ مستند التاريخ الأرشيفي
        final historyRef = _db.collection('subject_leagues_history').doc('${userId}_${subjectId}_$currentWeekId');
        transaction.set(historyRef, data);
      } else {
        final data = snap.data() as Map<String, dynamic>;
        final String storedWeekId = data['weekIdentifier'] ?? '';

        int newWeeklyXp = xpGained;
        String league = data['league'] ?? 'bronze';

        if (storedWeekId == currentWeekId) {
          newWeeklyXp = (data['weeklyXp'] ?? 0) + xpGained;
        }

        final updates = {
          'userName': userName,
          'userAvatar': userAvatar,
          'weeklyXp': newWeeklyXp,
          'weekIdentifier': currentWeekId,
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        transaction.update(activeDocRef, updates);

        // تحديث مستند التاريخ الأرشيفي
        final historyRef = _db.collection('subject_leagues_history').doc('${userId}_${subjectId}_$currentWeekId');
        transaction.set(historyRef, {
          'userId': userId,
          'userName': userName,
          'userAvatar': userAvatar,
          'subjectId': subjectId,
          'weeklyXp': newWeeklyXp,
          'weekIdentifier': currentWeekId,
          'league': league,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  /// يتحقق مما إذا كان الأسبوع قد انتهى ويقوم بترقية/تخفيض المستخدم وتصفير نقاطه
  Future<Map<String, dynamic>?> checkAndApplyWeeklyReset({
    required String userId,
    required String subjectId,
    required String userName,
    String? userAvatar,
  }) async {
    final currentWeekId = getCurrentWeekId();
    final activeDocRef = _db.collection('user_subject_leagues').doc('${userId}_$subjectId');

    final snap = await activeDocRef.get();
    if (!snap.exists) return null;

    final data = snap.data() as Map<String, dynamic>;
    final String oldWeekId = data['weekIdentifier'] ?? '';

    // إذا كان الأسبوع المخزن هو نفس الأسبوع الحالي، لا داعي للترسيت
    if (oldWeekId == currentWeekId || oldWeekId.isEmpty) return null;

    final String currentLeague = data['league'] ?? 'bronze';
    String newLeague = currentLeague;
    String status = 'retained'; // 'promoted', 'demoted', 'retained'

    try {
      // 1. جلب تاريخ نتائج الأسبوع الماضي لمعرفة الترتيب
      final historySnap = await _db
          .collection('subject_leagues_history')
          .where('subjectId', isEqualTo: subjectId)
          .where('weekIdentifier', isEqualTo: oldWeekId)
          .where('league', isEqualTo: currentLeague)
          .orderBy('weeklyXp', descending: true)
          .get();

      final docs = historySnap.docs;
      final total = docs.length;
      int rankIndex = -1;

      for (int i = 0; i < total; i++) {
        if (docs[i].id == '${userId}_${subjectId}_$oldWeekId') {
          rankIndex = i;
          break;
        }
      }

      if (rankIndex != -1) {
        final rank = rankIndex + 1;
        final weeklyXp = docs[rankIndex].data()['weeklyXp'] as int? ?? 0;

        if (weeklyXp > 0) {
          // قواعد الترقية
          final isTopRank = rank <= 3 || rank <= (total * 0.25).ceil();
          if (isTopRank) {
            final currentIndex = leagues.indexOf(currentLeague);
            if (currentIndex < leagues.length - 1) {
              newLeague = leagues[currentIndex + 1];
              status = 'promoted';
            }
          } 
          // قواعد الهبوط (فقط إذا كان هناك عدد كافٍ من اللاعبين)
          else if (total > 5) {
            final isBottomRank = rank > (total * 0.8).floor();
            if (isBottomRank) {
              final currentIndex = leagues.indexOf(currentLeague);
              if (currentIndex > 0) {
                newLeague = leagues[currentIndex - 1];
                status = 'demoted';
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error calculating weekly league promotion: $e');
    }

    // 2. تحديث مستند الدوري النشط بالأسبوع الجديد وتصفير الـ XP الأسبوعي
    final resetData = {
      'userName': userName,
      'userAvatar': userAvatar,
      'weeklyXp': 0,
      'weekIdentifier': currentWeekId,
      'league': newLeague,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    await activeDocRef.set(resetData, SetOptions(merge: true));

    // 3. كتابة مستند أرشيفي جديد للأسبوع الجديد بنقاط 0
    final newHistoryRef = _db.collection('subject_leagues_history').doc('${userId}_${subjectId}_$currentWeekId');
    await newHistoryRef.set({
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'subjectId': subjectId,
      'weeklyXp': 0,
      'weekIdentifier': currentWeekId,
      'league': newLeague,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    return {
      'reset': true,
      'oldLeague': currentLeague,
      'newLeague': newLeague,
      'status': status,
    };
  }

  /// البث المباشر للوحة الصدارة الخاصة بمادة ودوري محددين
  Stream<List<Map<String, dynamic>>> getLeaderboardStream(String subjectId, String league) {
    final currentWeekId = getCurrentWeekId();
    return _db
        .collection('user_subject_leagues')
        .where('subjectId', isEqualTo: subjectId)
        .where('weekIdentifier', isEqualTo: currentWeekId)
        .where('league', isEqualTo: league)
        .orderBy('weeklyXp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              return {
                'userId': d['userId'] ?? '',
                'userName': d['userName'] ?? 'طالب مجهول',
                'userAvatar': d['userAvatar'],
                'weeklyXp': d['weeklyXp'] ?? 0,
                'league': d['league'] ?? 'bronze',
              };
            }).toList());
  }

  /// استرجاع معلومات الدوري الحالية لمستخدم في مادة محددة
  Stream<Map<String, dynamic>?> getUserLeagueInfoStream(String userId, String subjectId) {
    return _db
        .collection('user_subject_leagues')
        .doc('${userId}_$subjectId')
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }
}
