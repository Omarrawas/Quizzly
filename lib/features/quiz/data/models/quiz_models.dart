/// نموذج خيار الإجابة
class QuizOption {
  final String id;
  final String text;

  const QuizOption({required this.id, required this.text});
}

/// نموذج سؤال
class QuizQuestion {
  final int number;
  final String text;
  final List<QuizOption> options;
  final String correctOptionId;
  final String? tagLabel;
  final String? imageUrl;

  const QuizQuestion({
    required this.number,
    required this.text,
    required this.options,
    required this.correctOptionId,
    this.tagLabel,
    this.imageUrl,
  });
}

/// نموذج الاختبار
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
