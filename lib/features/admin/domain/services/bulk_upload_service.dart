import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadError {
  final int row;
  final String message;

  UploadError({required this.row, required this.message});
}

class ParsedQuestionResult {
  final List<QuizQuestion> questions;
  final List<UploadError> errors;

  ParsedQuestionResult({required this.questions, required this.errors});
}

class BulkUploadService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<ParsedQuestionResult> parseAndValidateCsv(Uint8List fileBytes, String subjectId) async {
    List<QuizQuestion> parsedQuestions = [];
    List<UploadError> errors = [];

    // 1. Decode CSV
    final csvString = utf8.decode(fileBytes);
    final rows = const CsvToListConverter().convert(csvString);

    if (rows.isEmpty || rows.length == 1) {
      return ParsedQuestionResult(questions: [], errors: [UploadError(row: 0, message: 'الملف فارغ أو لا يحتوي على أسئلة.')]);
    }

    // Assume first row is header
    final header = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    
    // Find column indices
    int colText = header.indexOf('questiontext');
    int colType = header.indexOf('type');
    int colOptA = header.indexOf('opt_a');
    int colOptB = header.indexOf('opt_b');
    int colOptC = header.indexOf('opt_c');
    int colOptD = header.indexOf('opt_d');
    int colCorrect = header.indexOf('correctans');
    int colDiff = header.indexOf('difficulty');
    int colCognitive = header.indexOf('cognitivelevel');
    int colTime = header.indexOf('timesec');
    int colTopic = header.indexOf('topicname');
    int colExpl = header.indexOf('explanation');

    if (colText == -1) {
      return ParsedQuestionResult(questions: [], errors: [UploadError(row: 0, message: 'العمود QuestionText مفقود.')]);
    }

    // 2. Fetch topics for auto-mapping
    final topicsSnap = await _db.collection('topics')
        .where('subjectId', isEqualTo: subjectId)
        .get();
    
    Map<String, String> topicMap = {};
    for (var doc in topicsSnap.docs) {
      final name = (doc.data()['name'] as String).trim().toLowerCase();
      topicMap[name] = doc.id;
    }

    // 3. Parse rows
    for (int i = 1; i < rows.length; i++) {
      var row = rows[i];
      if (row.isEmpty || row.length < colText || row[colText].toString().trim().isEmpty) continue;

      String text = row[colText].toString().trim();
      
      // Map Topic
      String topicName = colTopic != -1 && row.length > colTopic ? row[colTopic].toString().trim() : '';
      List<String> topicIds = [];
      if (topicName.isNotEmpty) {
        String? mappedId = topicMap[topicName.toLowerCase()];
        if (mappedId != null) {
          topicIds.add(mappedId);
        } else {
          errors.add(UploadError(row: i + 1, message: 'الموضوع "$topicName" غير موجود.'));
        }
      }

      // Parse Type
      String typeStr = colType != -1 && row.length > colType ? row[colType].toString().trim().toLowerCase() : 'mcq';
      QuestionType type;
      switch (typeStr) {
        case 'tf': type = QuestionType.trueFalse; break;
        case 'essay': type = QuestionType.essay; break;
        case 'mcq':
        default: type = QuestionType.mcq;
      }

      // Options
      List<String> options = [];
      if (type == QuestionType.mcq || type == QuestionType.trueFalse) {
        if (colOptA != -1 && row.length > colOptA && row[colOptA].toString().trim().isNotEmpty) options.add(row[colOptA].toString().trim());
        if (colOptB != -1 && row.length > colOptB && row[colOptB].toString().trim().isNotEmpty) options.add(row[colOptB].toString().trim());
        if (colOptC != -1 && row.length > colOptC && row[colOptC].toString().trim().isNotEmpty) options.add(row[colOptC].toString().trim());
        if (colOptD != -1 && row.length > colOptD && row[colOptD].toString().trim().isNotEmpty) options.add(row[colOptD].toString().trim());
        
        if (type == QuestionType.mcq && options.length < 2) {
          errors.add(UploadError(row: i + 1, message: 'أسئلة الاختيارات يجب أن تحتوي على خيارين على الأقل.'));
        }
      }

      // Correct Answer
      String correctAnsRaw = colCorrect != -1 && row.length > colCorrect ? row[colCorrect].toString().trim() : '';
      dynamic correctAnswer;
      if (type == QuestionType.mcq) {
        // Map a, b, c, d to index 0, 1, 2, 3
        int ansIndex = -1;
        switch (correctAnsRaw.toLowerCase()) {
          case 'a': ansIndex = 0; break;
          case 'b': ansIndex = 1; break;
          case 'c': ansIndex = 2; break;
          case 'd': ansIndex = 3; break;
        }
        if (ansIndex != -1 && ansIndex < options.length) {
          correctAnswer = ansIndex;
        } else if (correctAnsRaw.isNotEmpty) {
          errors.add(UploadError(row: i + 1, message: 'الإجابة الصحيحة غير مطابقة لأي خيار.'));
        }
      } else if (type == QuestionType.trueFalse) {
        if (correctAnsRaw.toLowerCase() == 'true' || correctAnsRaw.toLowerCase() == 'صح') {
          correctAnswer = true;
        } else if (correctAnsRaw.toLowerCase() == 'false' || correctAnsRaw.toLowerCase() == 'خطأ') {
          correctAnswer = false;
        } else {
          errors.add(UploadError(row: i + 1, message: 'إجابة الصح/خطأ غير صالحة.'));
        }
      } else {
        correctAnswer = correctAnsRaw; // For essay
      }

      // Difficulty
      String diffStr = colDiff != -1 && row.length > colDiff ? row[colDiff].toString().trim().toLowerCase() : 'medium';
      Difficulty diff;
      switch (diffStr) {
        case 'easy': diff = Difficulty.easy; break;
        case 'hard': diff = Difficulty.hard; break;
        case 'medium':
        default: diff = Difficulty.medium;
      }

      // Cognitive Level
      String cogStr = colCognitive != -1 && row.length > colCognitive ? row[colCognitive].toString().trim().toLowerCase() : 'understanding';
      CognitiveLevel cog;
      switch (cogStr) {
        case 'recall': cog = CognitiveLevel.recall; break;
        case 'application': cog = CognitiveLevel.application; break;
        case 'understanding':
        default: cog = CognitiveLevel.understanding;
      }

      // Time
      int timeSec = 60;
      if (colTime != -1 && row.length > colTime) {
        timeSec = int.tryParse(row[colTime].toString()) ?? 60;
      }

      String expl = colExpl != -1 && row.length > colExpl ? row[colExpl].toString().trim() : '';

      final q = QuizQuestion(
        id: _db.collection('dummy').doc().id, // Generate a temp ID
        number: i,
        text: text,
        type: type,
        options: options.isNotEmpty 
            ? options.asMap().entries.map((e) => QuizOption(id: e.key.toString(), text: e.value)).toList() 
            : null,
        correctOptionIds: (type == QuestionType.mcq || type == QuestionType.trueFalse) ? (correctAnswer != null ? [correctAnswer.toString()] : []) : [],
        essayAnswer: type == QuestionType.essay ? correctAnswer?.toString() : null,
        explanation: expl.isNotEmpty ? expl : null,
        difficulty: diff,
        cognitiveLevel: cog,
        topicIds: topicIds.isNotEmpty ? topicIds : null,
        estimatedTime: timeSec,
      );

      parsedQuestions.add(q);
    }

    return ParsedQuestionResult(questions: parsedQuestions, errors: errors);
  }

  Future<void> saveQuestions(List<QuizQuestion> questions, String subjectId) async {
    final batch = _db.batch();
    for (var q in questions) {
      final docRef = _db.collection('questions').doc();
      final data = q.toMap();
      data['subjectId'] = subjectId;
      data['createdAt'] = FieldValue.serverTimestamp();
      batch.set(docRef, data);
    }
    await batch.commit();
  }

  String exportQuestionsToCSV(List<QueryDocumentSnapshot> docs, Map<String, String> topicIdToName) {
    List<List<dynamic>> rows = [];
    
    // إجبار Excel على استخدام الفاصلة كفاصل للأعمدة بغض النظر عن إعدادات المنطقة
    rows.add(['sep=,']);
    
    // Header
    rows.add([
      'QuestionText', 'Type', 'Opt_A', 'Opt_B', 'Opt_C', 'Opt_D', 
      'CorrectAns', 'Difficulty', 'CognitiveLevel', 'TimeSec', 
      'TopicName', 'Explanation'
    ]);

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final type = data['type'] ?? 'mcq';
      final options = data['options'] as List? ?? [];
      
      String optA = options.isNotEmpty ? options[0]['text'].toString() : '';
      String optB = options.length > 1 ? options[1]['text'].toString() : '';
      String optC = options.length > 2 ? options[2]['text'].toString() : '';
      String optD = options.length > 3 ? options[3]['text'].toString() : '';

      String correctAns = '';
      if (type == 'mcq') {
        final correctIds = data['correctOptionIds'] as List? ?? (data['correctOptionId'] != null ? [data['correctOptionId']] : []);
        int idx = options.indexWhere((o) => correctIds.contains(o['id'].toString()));
        if (idx != -1) {
          correctAns = String.fromCharCode(97 + idx); // a, b, c, d
        }
      } else if (type == 'tf') {
        final correctIds = data['correctOptionIds'] as List? ?? (data['correctOptionId'] != null ? [data['correctOptionId']] : []);
        correctAns = correctIds.contains('true') || correctIds.contains('صح') ? 'صح' : 'خطأ';
      } else {
        correctAns = data['essayAnswer'] ?? '';
      }

      String topicName = '';
      final topicId = data['topicId'];
      if (topicId != null) {
        topicName = topicIdToName[topicId] ?? '';
      }

      rows.add([
        data['text'] ?? '',
        type,
        optA, optB, optC, optD,
        correctAns,
        data['difficulty'] ?? 'medium',
        data['cognitiveLevel'] ?? 'understanding',
        data['estimatedTime'] ?? 60,
        topicName,
        data['explanation'] ?? ''
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  static String generateTemplate({
    required List<QuizQuestion> questions,
    required Map<String, String> topicIdToName,
  }) {
    List<List<dynamic>> rows = [];
    
    // إجبار Excel على استخدام الفاصلة كفاصل للأعمدة بغض النظر عن إعدادات المنطقة
    rows.add(['sep=,']);
    
    // Header
    rows.add([
      'QuestionText', 'Type', 'Opt_A', 'Opt_B', 'Opt_C', 'Opt_D', 
      'CorrectAns', 'Difficulty', 'CognitiveLevel', 'TimeSec', 
      'TopicName', 'Explanation'
    ]);

    for (var q in questions) {
      final type = q.type.name;
      final options = q.options ?? [];
      
      String optA = options.isNotEmpty ? options[0].text : '';
      String optB = options.length > 1 ? options[1].text : '';
      String optC = options.length > 2 ? options[2].text : '';
      String optD = options.length > 3 ? options[3].text : '';

      String correctAns = '';
      if (q.type == QuestionType.mcq) {
        int idx = options.indexWhere((o) => q.correctOptionIds.contains(o.id));
        if (idx != -1) {
          correctAns = String.fromCharCode(97 + idx); // a, b, c, d
        }
      } else if (q.type == QuestionType.trueFalse) {
        correctAns = q.correctOptionIds.contains('true') || q.correctOptionIds.contains('صح') ? 'صح' : 'خطأ';
      } else {
        correctAns = q.essayAnswer ?? '';
      }

      String topicName = '';
      if (q.topicIds != null && q.topicIds!.isNotEmpty) {
        topicName = topicIdToName[q.topicIds!.first] ?? '';
      }

      rows.add([
        q.text,
        type,
        optA, optB, optC, optD,
        correctAns,
        q.difficulty?.name ?? 'medium',
        q.cognitiveLevel?.name ?? 'understanding',
        q.estimatedTime,
        topicName,
        q.explanation ?? ''
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }
}
