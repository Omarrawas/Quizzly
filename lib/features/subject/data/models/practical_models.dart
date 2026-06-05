import 'package:cloud_firestore/cloud_firestore.dart';

enum PracticalCategory {
  summary,
  drawing,
  experiment,
  interview,
}

class PracticalItem {
  final String id;
  final String title;
  final String description;
  final PracticalCategory category;
  final String? content; // Legacy: rich text summaries
  final String? imageUrl; // Legacy: single image
  final List<String>? steps; // Legacy: experiments
  final List<OralQuestion>? oralQuestions; // Legacy: interviews
  final List<MicroscopicLabel>? labels; // Legacy: drawings
  
  // New Lesson fields
  final String mediaType; // 'none', 'video', 'images'
  final String? videoUrl;
  final List<String> imageUrls;
  final List<Map<String, dynamic>> attachments;
  final Map<String, dynamic> rawData;
  
  final bool isNew;
  final bool isFree;
  final String lastUpdated;

  const PracticalItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.content,
    this.imageUrl,
    this.steps,
    this.oralQuestions,
    this.labels,
    this.mediaType = 'none',
    this.videoUrl,
    this.imageUrls = const [],
    this.attachments = const [],
    this.rawData = const {},
    this.isNew = false,
    this.isFree = false,
    required this.lastUpdated,
  });

  // Convenience getters for UI compatibility
  List<MicroscopicLabel> get microscopicLabels => labels ?? [];
  List<String> get experiments => steps ?? [];
  List<OralQuestion> get interviews => oralQuestions ?? [];

  factory PracticalItem.fromFirestore(DocumentSnapshot doc) {
    return PracticalItem.fromMap(doc.id, doc.data() as Map<String, dynamic>? ?? {});
  }

  factory PracticalItem.fromMap(String id, Map<String, dynamic> data) {
    PracticalCategory category;
    switch (data['subType']) {
      case 'drawing': category = PracticalCategory.drawing; break;
      case 'experiment': category = PracticalCategory.experiment; break;
      case 'interview': category = PracticalCategory.interview; break;
      default: category = PracticalCategory.summary;
    }

    final details = data['practicalDetails'] as Map<String, dynamic>? ?? {};

    return PracticalItem(
      id: id,
      title: data['title'] ?? data['name'] ?? '',
      description: data['description'] ?? '',
      category: category,
      content: details['content'],
      imageUrl: details['imageUrl'],
      steps: details['steps'] != null ? List<String>.from(details['steps']) : null,
      oralQuestions: details['questions'] != null 
          ? (details['questions'] as List).map((q) => OralQuestion.fromMap(q)).toList()
          : null,
      labels: details['labels'] != null
          ? (details['labels'] as List).map((l) => MicroscopicLabel.fromMap(l)).toList()
          : null,
      mediaType: data['mediaType'] ?? 'none',
      videoUrl: data['videoUrl'],
      imageUrls: data['imageUrls'] != null ? List<String>.from(data['imageUrls']) : [],
      attachments: data['attachments'] != null ? List<Map<String, dynamic>>.from(data['attachments']) : [],
      rawData: data,
      isNew: data['isNew'] ?? false,
      isFree: data['isFree'] ?? false,
      lastUpdated: (data['createdAt'] as Timestamp?)?.toDate().toString().split(' ')[0] ?? 'غير معروف',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'type': 'practical',
      'subType': category.name,
      'mediaType': mediaType,
      'videoUrl': videoUrl,
      'imageUrls': imageUrls,
      'attachments': attachments,
      'isNew': isNew,
      'isFree': isFree,
      'practicalDetails': {
        if (content != null) 'content': content,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (steps != null) 'steps': steps,
        if (oralQuestions != null) 'questions': oralQuestions!.map((q) => q.toMap()).toList(),
        if (labels != null) 'labels': labels!.map((l) => l.toMap()).toList(),
      },
    };
  }
}

class OralQuestion {
  final String question;
  final String answer;

  const OralQuestion({required this.question, required this.answer});

  factory OralQuestion.fromMap(Map<String, dynamic> map) {
    return OralQuestion(
      question: map['q'] ?? '',
      answer: map['a'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'q': question, 'a': answer};
}

class MicroscopicLabel {
  final double x; // percentage 0.0 to 1.0
  final double y; // percentage 0.0 to 1.0
  final String label;

  const MicroscopicLabel({required this.x, required this.y, required this.label});

  factory MicroscopicLabel.fromMap(Map<String, dynamic> map) {
    return MicroscopicLabel(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      label: map['label'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'x': x, 'y': y, 'label': label};
}

// ── Mock Data (Legacy support) ───────────────────────

final Map<PracticalCategory, List<PracticalItem>> mockPracticalData = {
  PracticalCategory.summary: [
    PracticalItem(
      id: 's1',
      title: 'مذاكرة النسج العام - الأسبوع الأول',
      description: 'تلخيص شامل للمحاضرة الأولى في النسج العام مع التركيز على النقاط الهامة.',
      category: PracticalCategory.summary,
      content: 'هنا يتم وضع المحتوى الكتابي للمذاكرة بشكل مفصل...',
      lastUpdated: '12/05/2024',
      isNew: true,
    ),
  ],
  PracticalCategory.drawing: [
    PracticalItem(
      id: 'd1',
      title: 'النسيج الظهاري المطبق الحرشفي',
      description: 'رسمة مجهرية توضح طبقات النسيج الظهاري المطبق الحرشفي المتقرن.',
      category: PracticalCategory.drawing,
      imageUrl: 'https://images.unsplash.com/photo-1530026405186-ed1f139313f8?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
      labels: [
        MicroscopicLabel(x: 0.5, y: 0.2, label: 'طبقة متقرنة'),
        MicroscopicLabel(x: 0.5, y: 0.5, label: 'طبقة شائكة'),
      ],
      lastUpdated: '10/05/2024',
    ),
  ],
  PracticalCategory.experiment: [
    PracticalItem(
      id: 'e1',
      title: 'تجربة الكشف عن الغلوكوز',
      description: 'شرح مفصل لخطوات تجربة الكشف عن الغلوكوز باستخدام محلول فهلنغ.',
      category: PracticalCategory.experiment,
      steps: [
        'نضع 2 مل من محلول الغلوكوز في أنبوب اختبار.',
        'نضيف 1 مل من محلول فهلنغ A و 1 مل من محلول فهلنغ B.',
        'نسخن الأنبوب بلطف فوق اللهب.',
        'نلاحظ تشكل راسب أحمر آجري.',
      ],
      lastUpdated: '08/05/2024',
    ),
  ],
  PracticalCategory.interview: [
    PracticalItem(
      id: 'i1',
      title: 'أسئلة مقابلة الكيمياء الحيوية',
      description: 'أهم الأسئلة الشفهية المتكررة في مقابلات الكيمياء الحيوية العملية.',
      category: PracticalCategory.interview,
      oralQuestions: [
        OralQuestion(question: 'ما هو مبدأ تفاعل بيوريت؟', answer: 'يكشف عن الروابط الببتيدية في البروتينات حيث يتفاعل أيون النحاس مع الرابطة الببتيدية في وسط قلوى ليعطي لوناً بنفسجياً.'),
        OralQuestion(question: 'لماذا نستخدم حمض الكبريت المركز في تفاعل مولش؟', answer: 'لأنه يعمل كعامل نازع للماء من السكاكر الأحادية ليحولها إلى فورفورال أو مشتقاته.'),
      ],
      lastUpdated: '05/05/2024',
    ),
  ],
};
