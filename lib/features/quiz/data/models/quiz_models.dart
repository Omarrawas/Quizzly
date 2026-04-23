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

  const QuestionAnalytics({
    this.timesAnswered = 0,
    this.correctAnswers = 0,
    this.totalTimeSpent = 0,
  });

  double get successRate => timesAnswered > 0 ? correctAnswers / timesAnswered : 0.0;
  double get avgTime => timesAnswered > 0 ? totalTimeSpent / timesAnswered : 0.0;

  factory QuestionAnalytics.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const QuestionAnalytics();
    return QuestionAnalytics(
      timesAnswered: map['timesAnswered'] ?? 0,
      correctAnswers: map['correctAnswers'] ?? 0,
      totalTimeSpent: map['totalTimeSpent'] ?? 0,
    );
  }
}

/// نموذج سؤال متطور
class QuizQuestion {
  final String? id;
  final int number;
  final String text;
  final QuestionType type;
  final List<QuizOption>? options;
  final String? correctOptionId; // For MCQ/TF
  final String? essayAnswer;     // For Essay
  final String? explanation;     // شرح الإجابة
  final String? explanationImageUrl; // صورة الشرح لزيادة الوضوح
  final Difficulty? difficulty;
  final CognitiveLevel? cognitiveLevel;
  final int? estimatedTime;      // بالثواني
  final List<String>? topicIds;
  final String? tagLabel;
  final String? imageUrl;
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
    this.correctOptionId,
    this.essayAnswer,
    this.explanation,
    this.explanationImageUrl,
    this.difficulty,
    this.cognitiveLevel,
    this.estimatedTime,
    this.topicIds,
    this.tagLabel,
    this.imageUrl,
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
      options: (data['options'] as List?)?.map((e) => QuizOption(id: e['id'], text: e['text'])).toList(),
      correctOptionId: data['correctOptionId'],
      essayAnswer: data['essayAnswer'],
      explanation: data['explanation'],
      explanationImageUrl: data['explanationImageUrl'],
      difficulty: _parseDifficulty(data['difficulty']),
      cognitiveLevel: _parseCognitiveLevel(data['cognitiveLevel']),
      estimatedTime: data['estimatedTime'],
      topicIds: List<String>.from(data['topicIds'] ?? []),
      tagLabel: data['tagLabel'],
      imageUrl: data['imageUrl'],
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
      'number': number,
      'text': text,
      'type': type.name,
      'options': options?.map((e) => {'id': e.id, 'text': e.text}).toList(),
      'correctOptionId': correctOptionId,
      'essayAnswer': essayAnswer,
      'explanation': explanation,
      'explanationImageUrl': explanationImageUrl,
      'difficulty': difficulty?.name,
      'cognitiveLevel': cognitiveLevel?.name,
      'estimatedTime': estimatedTime,
      'topicIds': topicIds,
      'tagLabel': tagLabel,
      'imageUrl': imageUrl,
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
      correctOptionId: 'a',
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
      correctOptionId: 'a',
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
      correctOptionId: 'c',
      tagLabel: 'الفصل الخامس: حالات المادة',
    ),
  ],
);
