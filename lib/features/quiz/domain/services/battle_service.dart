import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

enum BattleStatus { waiting, active, finished, cancelled }

class BattleChallenge {
  final String id;
  final String challengerId;
  final String challengerName;
  final String subjectId;
  final String subjectName;
  final List<String> questionIds;
  final BattleStatus status;
  final String? opponentId;
  final String? opponentName;
  final Map<String, int> scores;       // userId → score
  final Map<String, int> timeTaken;    // userId → seconds
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  const BattleChallenge({
    required this.id,
    required this.challengerId,
    required this.challengerName,
    required this.subjectId,
    required this.subjectName,
    required this.questionIds,
    required this.status,
    required this.scores,
    required this.timeTaken,
    required this.createdAt,
    this.opponentId,
    this.opponentName,
    this.startedAt,
    this.finishedAt,
  });

  factory BattleChallenge.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BattleChallenge(
      id: doc.id,
      challengerId: data['challengerId'] ?? '',
      challengerName: data['challengerName'] ?? 'مجهول',
      subjectId: data['subjectId'] ?? '',
      subjectName: data['subjectName'] ?? '',
      questionIds: (data['questionIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      status: _parseStatus(data['status']),
      opponentId: data['opponentId'],
      opponentName: data['opponentName'],
      scores: Map<String, int>.from(data['scores'] ?? {}),
      timeTaken: Map<String, int>.from(data['timeTaken'] ?? {}),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      startedAt: data['startedAt'] != null
          ? (data['startedAt'] as Timestamp).toDate()
          : null,
      finishedAt: data['finishedAt'] != null
          ? (data['finishedAt'] as Timestamp).toDate()
          : null,
    );
  }

  static BattleStatus _parseStatus(String? s) {
    switch (s) {
      case 'active':   return BattleStatus.active;
      case 'finished': return BattleStatus.finished;
      case 'cancelled': return BattleStatus.cancelled;
      default:         return BattleStatus.waiting;
    }
  }

  String get winnerId {
    if (scores.isEmpty) return '';
    return scores.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  bool get isDraw {
    if (scores.length < 2) return false;
    final values = scores.values.toList();
    return values.first == values.last;
  }
}

class BattleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const int _questionsPerBattle = 10;

  // ── Create a new challenge (challenger side) ───────────────────────────────
  Future<BattleChallenge> createChallenge({
    required String challengerId,
    required String challengerName,
    required String subjectId,
    required String subjectName,
  }) async {
    // Pick random questions for this subject
    final qSnap = await _db
        .collection('questions')
        .where('subjectId', isEqualTo: subjectId)
        .limit(50)
        .get();

    final allIds = qSnap.docs.map((d) => d.id).toList()..shuffle();
    final selected = allIds.take(_questionsPerBattle).toList();

    if (selected.isEmpty) {
      throw Exception('لا توجد أسئلة متاحة في هذه المادة لإنشاء معركة.');
    }

    final data = {
      'challengerId': challengerId,
      'challengerName': challengerName,
      'subjectId': subjectId,
      'subjectName': subjectName,
      'questionIds': selected,
      'status': 'waiting',
      'scores': {},
      'timeTaken': {},
      'createdAt': FieldValue.serverTimestamp(),
    };

    final ref = await _db.collection('battles').add(data);
    
    // Construct the object locally to return immediately
    return BattleChallenge(
      id: ref.id,
      challengerId: challengerId,
      challengerName: challengerName,
      subjectId: subjectId,
      subjectName: subjectName,
      questionIds: selected,
      status: BattleStatus.waiting,
      scores: {},
      timeTaken: {},
      createdAt: DateTime.now(),
    );
  }

  // ── Join an existing challenge (opponent side) ─────────────────────────────
  Future<BattleChallenge?> joinChallenge({
    required String battleId,
    required String opponentId,
    required String opponentName,
  }) async {
    final ref = _db.collection('battles').doc(battleId);
    final snap = await ref.get();
    if (!snap.exists) return null;

    final battle = BattleChallenge.fromFirestore(snap);
    if (battle.status != BattleStatus.waiting) return null;
    if (battle.challengerId == opponentId) return null; // can't battle yourself

    await ref.update({
      'opponentId': opponentId,
      'opponentName': opponentName,
      'status': 'active',
      'startedAt': FieldValue.serverTimestamp(),
    });

    return BattleChallenge.fromFirestore(await ref.get());
  }

  // ── Submit score after completing the battle ───────────────────────────────
  Future<void> submitScore({
    required String battleId,
    required String userId,
    required int score,
    required int timeTakenSeconds,
  }) async {
    final ref = _db.collection('battles').doc(battleId);
    await ref.update({
      'scores.$userId': score,
      'timeTaken.$userId': timeTakenSeconds,
    });

    // Check if both players have submitted → mark as finished
    final snap = await ref.get();
    final battle = BattleChallenge.fromFirestore(snap);
    if (battle.scores.length >= 2) {
      await ref.update({
        'status': 'finished',
        'finishedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Get a single battle ────────────────────────────────────────────────────
  Future<BattleChallenge?> getBattle(String battleId) async {
    final snap = await _db.collection('battles').doc(battleId).get();
    if (!snap.exists) return null;
    return BattleChallenge.fromFirestore(snap);
  }

  // ── Streams ────────────────────────────────────────────────────────────────
  Stream<BattleChallenge?> streamBattle(String battleId) {
    return _db
        .collection('battles')
        .doc(battleId)
        .snapshots()
        .map((snap) => snap.exists ? BattleChallenge.fromFirestore(snap) : null);
  }

  Stream<List<BattleChallenge>> streamMyBattles(String userId) {
    final challengerStream = _db
        .collection('battles')
        .where('challengerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((s) => s.docs.map(BattleChallenge.fromFirestore).toList());

    final opponentStream = _db
        .collection('battles')
        .where('opponentId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((s) => s.docs.map(BattleChallenge.fromFirestore).toList());

    return CombineLatestStream.combine2(challengerStream, opponentStream, (a, b) {
      final map = <String, BattleChallenge>{};
      for (final c in a) { map[c.id] = c; }
      for (final c in b) { map[c.id] = c; }
      final list = map.values.toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(20).toList();
    });
  }

  Stream<List<BattleChallenge>> streamIncomingChallenges(String userId) {
    return _db
        .collection('battles')
        .where('opponentId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((s) => s.docs.map(BattleChallenge.fromFirestore).toList());
  }

}
