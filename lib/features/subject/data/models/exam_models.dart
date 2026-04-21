/// نموذج بيانات الامتحان (دورة)
class ExamItem {
  final String id;
  final String title;
  final String lastUpdated;
  final int questionCount;
  final bool isAvailable; // false = مقفل
  final bool isNew;

  const ExamItem({
    required this.id,
    required this.title,
    required this.lastUpdated,
    required this.questionCount,
    required this.isAvailable,
    this.isNew = false,
  });
}

/// نموذج بيانات الوسم / التصنيف
class TagItem {
  final String id;
  final String title;
  final int questionCount;
  final int wrongCount;
  final bool isNew;

  const TagItem({
    required this.id,
    required this.title,
    required this.questionCount,
    this.wrongCount = 0,
    this.isNew = false,
  });
}

// ── بيانات تجريبية ─────────────────────────────────

final List<ExamItem> mockExams = [
  ExamItem(id: '1', title: 'دورة 2023-2024 - الفصل الأول', lastUpdated: '08/11/2024', questionCount: 100, isAvailable: false, isNew: true),
  ExamItem(id: '2', title: 'دورة 2022-2023 - الفصل الأول', lastUpdated: '15/10/2024', questionCount: 99,  isAvailable: false, isNew: true),
  ExamItem(id: '3', title: 'دورة 2021-2022 - الفصل الأول', lastUpdated: '15/10/2024', questionCount: 100, isAvailable: false, isNew: true),
  ExamItem(id: '4', title: 'دورة 2020-2021 - الفصل الأول', lastUpdated: '15/10/2024', questionCount: 97,  isAvailable: false, isNew: true),
  ExamItem(id: '5', title: 'دورة 2019-2020 - الفصل الأول', lastUpdated: '15/10/2024', questionCount: 100, isAvailable: false, isNew: true),
  ExamItem(id: '6', title: 'دورة 2018-2019 - الفصل الأول', lastUpdated: '15/10/2024', questionCount: 100, isAvailable: false, isNew: true),
  ExamItem(id: '7', title: 'دورة 2017-2018 - الفصل الأول', lastUpdated: '15/10/2024', questionCount: 100, isAvailable: false, isNew: true),
  ExamItem(id: '8', title: 'دورة 2016-2017 - الفصل الأول', lastUpdated: '15/10/2024', questionCount: 100, isAvailable: false, isNew: true),
  ExamItem(id: '9', title: 'دورة 2015-2016 - الفصل الأول', lastUpdated: '23/09/2024', questionCount: 82,  isAvailable: false, isNew: true),
  ExamItem(id: '10', title: 'دورة 2015-2016 - الفصل الأول التجريبية', lastUpdated: '21/02/2024', questionCount: 30, isAvailable: true, isNew: false),
];

final List<TagItem> mockTags = [
  TagItem(id: '1', title: 'الفصل الرابع: الربط الكيميائي',       questionCount: 24, isNew: true),
  TagItem(id: '2', title: 'الفصل الأول: المولات والمعادلات',      questionCount: 25, isNew: true),
  TagItem(id: '3', title: 'الفصل الخامس: حالات المادة',           questionCount: 28, isNew: true),
  TagItem(id: '4', title: 'الفصل الثالث: الإلكترونات في الذرات',  questionCount: 18, isNew: true),
  TagItem(id: '5', title: 'الفصل العاشر: الدورية',                questionCount: 15, isNew: false),
  TagItem(id: '6', title: 'الفصل السابع: تفاعلات الريدوكس (أكسدة/إرجاع) والتحليل الكهربائي', questionCount: 18, isNew: false),
  TagItem(id: '7', title: 'الفصل السادس: تغيرات الانتالبية',      questionCount: 21, wrongCount: 1, isNew: false),
];
