import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج خيار الإجابة
class QuizOption {
  final String id;
  final String text;

  const QuizOption({required this.id, required this.text});
}

enum QuestionType { mcq, essay, trueFalse }
enum Difficulty { easy, medium, hard }
enum CognitiveLevel { recall, understanding, application }
enum QuestionStatus { draft, pendingReview, approved, rejected }

class QuestionAnalytics {
  final int timesAnswered;
  final int correctAnswers;
  final int totalTimeSpent;
  final double successRate; // Pre-calculated for performance
  final double avgTime;     // Pre-calculated for performance

  const QuestionAnalytics({
    this.timesAnswered = 0,
    this.correctAnswers = 0,
    this.totalTimeSpent = 0,
    this.successRate = 0.0,
    this.avgTime = 0.0,
  });

  factory QuestionAnalytics.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const QuestionAnalytics();
    return QuestionAnalytics(
      timesAnswered: map['timesAnswered'] ?? 0,
      correctAnswers: map['correctAnswers'] ?? 0,
      totalTimeSpent: map['totalTimeSpent'] ?? 0,
      successRate: (map['successRate'] ?? 0.0).toDouble(),
      avgTime: (map['avgTime'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timesAnswered': timesAnswered,
      'correctAnswers': correctAnswers,
      'totalTimeSpent': totalTimeSpent,
      'successRate': successRate,
      'avgTime': avgTime,
    };
  }
}

/// نموذج سؤال متطور بنظام "Tutor Engine"
class QuizQuestion {
  final String? id;
  final int number;
  final String text;
  final QuestionType type;
  final List<QuizOption>? options;
  final List<String> correctOptionIds; 
  final String? essayAnswer;     
  final String? explanation;     
  final String? explanationImageUrl; 
  final Difficulty? difficulty;
  final CognitiveLevel? cognitiveLevel;
  final int? estimatedTime;      
  
  // --- Smart EdTech Fields ---
  final String? primaryTopicId;   // Subject indexing
  final List<String>? topicIds;   // Querying (Firestore array-contains)
  final List<String>? topicNames; // Cache/Denormalization to avoid joins
  final Map<String, double>? topicWeights; // AI/Logic weights
  final double discriminationIndex; // Measures how well question distinguishes student levels
  final bool isFrequentlyWrong;     // Flag for "Trap" questions
  
  final String? tagLabel;
  final String? imageUrl;
  final List<String> examTags;
  final QuestionAnalytics analytics;

  // Moderation fields
  final QuestionStatus status;
  final String? authorId;
  final String? reviewerId;
  final String? reviewFeedback;

  const QuizQuestion({
    required this.number,
    required this.text,
    required this.type,
    this.id,
    this.options,
    this.correctOptionIds = const [],
    this.essayAnswer,
    this.explanation,
    this.explanationImageUrl,
    this.difficulty,
    this.cognitiveLevel,
    this.estimatedTime,
    this.primaryTopicId,
    this.topicIds,
    this.topicNames,
    this.topicWeights,
    this.discriminationIndex = 0.5,
    this.isFrequentlyWrong = false,
    this.tagLabel,
    this.imageUrl,
    this.examTags = const [],
    this.analytics = const QuestionAnalytics(),
    this.status = QuestionStatus.draft,
    this.authorId,
    this.reviewerId,
    this.reviewFeedback,
  });

  factory QuizQuestion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuizQuestion(
      id: doc.id,
      number: data['order'] ?? 0,
      text: data['text'] ?? '',
      type: _parseType(data['type']),
      options: (data['options'] as List?)?.map((e) => QuizOption(id: e['id'].toString(), text: e['text'].toString())).toList(),
      correctOptionIds: data['correctOptionIds'] != null 
          ? List<String>.from(data['correctOptionIds']) 
          : (data['correctOptionId'] != null ? [data['correctOptionId'].toString()] : []),
      essayAnswer: data['essayAnswer'],
      explanation: data['explanation'],
      explanationImageUrl: data['explanationImageUrl'],
      difficulty: _parseDifficulty(data['difficulty']),
      cognitiveLevel: _parseCognitiveLevel(data['cognitiveLevel']),
      estimatedTime: data['estimatedTime'],
      primaryTopicId: data['primaryTopicId'],
      topicIds: List<String>.from(data['topicIds'] ?? []),
      topicNames: List<String>.from(data['topicNames'] ?? []),
      topicWeights: (data['topicWeights'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toDouble())),
      discriminationIndex: (data['discriminationIndex'] ?? 0.5).toDouble(),
      isFrequentlyWrong: data['isFrequentlyWrong'] ?? false,
      tagLabel: data['tagLabel'],
      imageUrl: data['imageUrl'],
      examTags: List<String>.from(data['examTags'] ?? []),
      analytics: QuestionAnalytics.fromMap(data['analytics']),
      status: _parseStatus(data['status']),
      authorId: data['authorId'],
      reviewerId: data['reviewerId'],
      reviewFeedback: data['reviewFeedback'],
    );
  }

  static QuestionType _parseType(String? type) {
    switch (type) {
      case 'essay': return QuestionType.essay;
      case 'tf': return QuestionType.trueFalse;
      default: return QuestionType.mcq;
    }
  }

  static Difficulty? _parseDifficulty(String? d) {
    if (d == null) return null;
    return Difficulty.values.firstWhere((e) => e.name == d, orElse: () => Difficulty.medium);
  }

  static CognitiveLevel? _parseCognitiveLevel(String? c) {
    if (c == null) return null;
    return CognitiveLevel.values.firstWhere((e) => e.name == c, orElse: () => CognitiveLevel.understanding);
  }

  static QuestionStatus _parseStatus(String? s) {
    if (s == null) return QuestionStatus.draft;
    return QuestionStatus.values.firstWhere((e) => e.name == s, orElse: () => QuestionStatus.draft);
  }

  Map<String, dynamic> toMap() {
    return {
      'order': number,
      'text': text,
      'type': type.name,
      'options': options?.map((e) => {'id': e.id, 'text': e.text}).toList(),
      'correctOptionIds': correctOptionIds,
      'essayAnswer': essayAnswer,
      'explanation': explanation,
      'explanationImageUrl': explanationImageUrl,
      'difficulty': difficulty?.name,
      'cognitiveLevel': cognitiveLevel?.name,
      'estimatedTime': estimatedTime,
      'primaryTopicId': primaryTopicId,
      'topicIds': topicIds,
      'topicNames': topicNames,
      'topicWeights': topicWeights,
      'discriminationIndex': discriminationIndex,
      'isFrequentlyWrong': isFrequentlyWrong,
      'tagLabel': tagLabel,
      'imageUrl': imageUrl,
      'examTags': examTags,
      'analytics': analytics.toMap(),
      'status': status.name,
      'authorId': authorId,
      'reviewerId': reviewerId,
      'reviewFeedback': reviewFeedback,
    };
  }
}

enum ExamType { static, generated }

class GenerationRules {
  final List<String> topicIds;
  final Map<Difficulty, int> difficultyDistribution; // percentage

  const GenerationRules({
    required this.topicIds,
    required this.difficultyDistribution,
  });

  factory GenerationRules.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const GenerationRules(topicIds: [], difficultyDistribution: {});
    final dist = map['difficultyDistribution'] as Map<String, dynamic>? ?? {};
    return GenerationRules(
      topicIds: List<String>.from(map['topicIds'] ?? []),
      difficultyDistribution: {
        Difficulty.easy: dist['easy'] ?? 33,
        Difficulty.medium: dist['medium'] ?? 34,
        Difficulty.hard: dist['hard'] ?? 33,
      },
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'topicIds': topicIds,
      'difficultyDistribution': {
        'easy': difficultyDistribution[Difficulty.easy],
        'medium': difficultyDistribution[Difficulty.medium],
        'hard': difficultyDistribution[Difficulty.hard],
      },
    };
  }
}

/// نموذج إعدادات الاختبار
class ExamConfig {
  final String? id;
  final String title;
  final ExamType type;
  final int durationSeconds;
  final int totalQuestions;
  final double passingScore;
  final String subjectId;
  final String? category; // e.g. "دورة 2024", "اختبار تجريبي"
  final List<String> staticQuestionIds;
  final GenerationRules? generationRules;

  const ExamConfig({
    this.id,
    required this.title,
    required this.type,
    required this.durationSeconds,
    required this.totalQuestions,
    required this.passingScore,
    required this.subjectId,
    this.category,
    this.staticQuestionIds = const [],
    this.generationRules,
  });

  factory ExamConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamConfig(
      id: doc.id,
      title: data['title'] ?? '',
      type: data['type'] == 'generated' ? ExamType.generated : ExamType.static,
      durationSeconds: data['duration'] ?? 3600,
      totalQuestions: data['totalQuestions'] ?? 0,
      passingScore: (data['passingScore'] ?? 60.0).toDouble(),
      subjectId: data['subjectId'] ?? '',
      category: data['category'],
      staticQuestionIds: List<String>.from(data['staticQuestions'] ?? []),
      generationRules: data['type'] == 'generated' ? GenerationRules.fromMap(data['generationRules']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type == ExamType.generated ? 'generated' : 'static',
      'duration': durationSeconds,
      'totalQuestions': totalQuestions,
      'passingScore': passingScore,
      'subjectId': subjectId,
      'category': category,
      'staticQuestions': staticQuestionIds,
      if (type == ExamType.generated && generationRules != null)
        'generationRules': generationRules!.toMap(),
    };
  }
}

/// نموذج الاختبار المنفذ (لواجهة المستخدم)
class QuizExam {
  final String title;
  final String classification;
  final String lastUpdated;
  final int totalQuestions;
  final List<QuizQuestion> questions;

  const QuizExam({
    required this.title,
    required this.classification,
    required this.lastUpdated,
    required this.totalQuestions,
    required this.questions,
  });
}

/// حالة إجابة السؤال
enum AnswerState { unanswered, correct, wrong }

// ── بيانات تجريبية ─────────────────────────────────────
final QuizExam mockQuizExam = QuizExam(
  title: 'الدورة التجريبية',
  classification: 'الدورات الوزارية',
  lastUpdated: '21/02/2024',
  totalQuestions: 30,
  questions: [
    QuizQuestion(
      number: 1,
      text: 'يستخدم قانون هس لقياس تغيرات الانثالبية:',
      type: QuestionType.mcq,
      options: [
        QuizOption(id: 'a', text: 'المعقدة'),
        QuizOption(id: 'b', text: 'البسيطة'),
        QuizOption(id: 'c', text: 'الناشرة للحرارة'),
        QuizOption(id: 'd', text: 'الخاصة للحرارة'),
      ],
      correctOptionIds: ['a'],
      tagLabel: 'الفصل السادس: تغيرات الانثالبية',
    ),
    QuizQuestion(
      number: 2,
      text: 'الذرة الأكثر كهرسلبية هي:',
      type: QuestionType.mcq,
      options: [
        QuizOption(id: 'a', text: 'فلور'),
        QuizOption(id: 'b', text: 'كلور'),
        QuizOption(id: 'c', text: 'أكسجين'),
        QuizOption(id: 'd', text: 'نيتروجين'),
      ],
      correctOptionIds: ['a'],
      tagLabel: 'الفصل الرابع: الربط الكيميائي',
    ),
    QuizQuestion(
      number: 3,
      text: 'ما وحدة قياس الضغط في النظام الدولي SI؟',
      type: QuestionType.mcq,
      options: [
        QuizOption(id: 'a', text: 'atm'),
        QuizOption(id: 'b', text: 'bar'),
        QuizOption(id: 'c', text: 'Pa (باسكال)'),
        QuizOption(id: 'd', text: 'mmHg'),
      ],
      correctOptionIds: ['c'],
      tagLabel: 'الفصل الخامس: حالات المادة',
    ),
  ],
);
