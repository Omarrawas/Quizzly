import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';

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

  Future<ParsedQuestionResult> parseAndValidateCsv(Uint8List fileBytes, String subjectId, {String? sectionId}) async {
    List<QuizQuestion> parsedQuestions = [];
    List<UploadError> errors = [];

    // 1. Decode CSV
    String csvString = utf8.decode(fileBytes, allowMalformed: true);
    
    // Strip UTF-8 BOM if present
    if (csvString.startsWith('\uFEFF')) {
      csvString = csvString.substring(1);
    }
    
    var rows = const CsvToListConverter(
      eol: '\n',
      fieldDelimiter: ',',
      textDelimiter: '"',
    ).convert(csvString);

    if (rows.isEmpty) {

      return ParsedQuestionResult(questions: [], errors: [UploadError(row: 0, message: 'الملف فارغ.')]);
    }

    // Skip "sep=," metadata row if present
    if (rows.isNotEmpty && rows.first.isNotEmpty && rows.first.first.toString().startsWith('sep=')) {
      rows = rows.sublist(1);
    }

    if (rows.isEmpty || rows.length == 1) {
      return ParsedQuestionResult(questions: [], errors: [UploadError(row: 0, message: 'الملف لا يحتوي على أسئلة.')]);
    }

    // Assume first row is header
    final header = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    
    // Find column indices
    int colText = header.indexOf('questiontext');
    int colTranslation = header.indexOf('translationtext');
    int colType = header.indexOf('type');
    int colOptA = header.indexOf('opt_a');
    int colOptB = header.indexOf('opt_b');
    int colOptC = header.indexOf('opt_c');
    int colOptD = header.indexOf('opt_d');
    int colOptE = header.indexOf('opt_e');
    int colOptF = header.indexOf('opt_f');
    int colOptG = header.indexOf('opt_g');
    int colOptH = header.indexOf('opt_h');
    int colOptI = header.indexOf('opt_i');
    int colOptJ = header.indexOf('opt_j');
    int colOptK = header.indexOf('opt_k');
    int colOptL = header.indexOf('opt_l');
    int colCorrect = header.indexOf('correctans');
    int colDiff = header.indexOf('difficulty');
    int colCognitive = header.indexOf('cognitivelevel');
    int colTime = header.indexOf('timesec');
    int colTopic = header.indexOf('topicname');
    int colExpl = header.indexOf('explanation');
    int colExplImg = header.indexOf('explanationimageurl');
    int colExplVid = header.indexOf('explanationvideourl');
    int colExplAud = header.indexOf('explanationaudiourl');
    int colExplPdf = header.indexOf('explanationpdfurl');
    int colImg = header.indexOf('imageurl');
    int colTag = header.indexOf('taglabel');
    int colExamTags = header.indexOf('examtags');

    if (colText == -1) {
      return ParsedQuestionResult(questions: [], errors: [UploadError(row: 0, message: 'العمود QuestionText مفقود.')]);
    }

    var topicsQuery = _db.collection('topics')
        .where('subjectId', isEqualTo: subjectId);
    
    if (sectionId != null) {
      topicsQuery = topicsQuery.where('sectionId', isEqualTo: sectionId);
    }

    final topicsSnap = await topicsQuery.get();
    
    Map<String, String> topicIdToName = {};
    Map<String, String> topicMap = {};
    Map<String, Map<String, dynamic>> topicsRawMap = {};
    
    for (var doc in topicsSnap.docs) {
      final data = doc.data();
      final name = (data['name'] as String).trim().toLowerCase();
      topicMap[name] = doc.id;
      topicIdToName[doc.id] = name;
      topicsRawMap[doc.id] = data;
    }

    final seenQuestions = <String>{};

    // 3. Parse rows
    for (int i = 1; i < rows.length; i++) {
      var row = rows[i];
      if (row.isEmpty || row.length <= colText || row[colText] == null || row[colText].toString().trim().isEmpty) continue;

      String text = row[colText].toString().trim();
      
      // Prevent duplicates in the same file
      final normalizedText = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (seenQuestions.contains(normalizedText)) {
        errors.add(UploadError(row: i + 1, message: 'سؤال مكرر داخل الملف.'));
        continue;
      }
      seenQuestions.add(normalizedText);

      // Other fields
      String translation = colTranslation != -1 && row.length > colTranslation ? row[colTranslation].toString().trim() : '';
      String explImg = colExplImg != -1 && row.length > colExplImg ? row[colExplImg].toString().trim() : '';
      String explVid = colExplVid != -1 && row.length > colExplVid ? row[colExplVid].toString().trim() : '';
      String explAud = colExplAud != -1 && row.length > colExplAud ? row[colExplAud].toString().trim() : '';
      String explPdf = colExplPdf != -1 && row.length > colExplPdf ? row[colExplPdf].toString().trim() : '';
      String imgUrl = colImg != -1 && row.length > colImg ? row[colImg].toString().trim() : '';
      String tag = colTag != -1 && row.length > colTag ? row[colTag].toString().trim() : '';
      
      String examTagsRaw = colExamTags != -1 && row.length > colExamTags ? row[colExamTags].toString().trim() : '';
      List<String> examTags = [];
      if (examTagsRaw.isNotEmpty) {
        examTags = examTagsRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      
      // Map Topic (Handle "Chapter - Lesson" format)
      String fullTopicPath = colTopic != -1 && row.length > colTopic ? row[colTopic].toString().trim() : '';
      List<String> topicIds = [];
      
      if (fullTopicPath.isNotEmpty) {
        String chapterName = '';
        String lessonName = fullTopicPath;
        
        if (fullTopicPath.contains(' - ')) {
          final parts = fullTopicPath.split(' - ');
          chapterName = parts[0].trim().toLowerCase();
          lessonName = parts[1].trim().toLowerCase();
        } else {
          lessonName = fullTopicPath.trim().toLowerCase();
        }

        // Try to find the topic
        String? finalTopicId;
        
        if (chapterName.isNotEmpty) {
          // Find chapter first
          final chapterId = topicMap[chapterName];
          if (chapterId != null) {
            // Find lesson under this chapter
            for (var entry in topicsRawMap.entries) {
              if (entry.value['name'].toString().toLowerCase() == lessonName && 
                  entry.value['parentId'] == chapterId) {
                finalTopicId = entry.key;
                break;
              }
            }
          }
        }
        
        // Fallback: search by lesson name directly if not found via path
        finalTopicId ??= topicMap[lessonName];

        if (finalTopicId != null) {
          topicIds.add(finalTopicId);
        } else {
          errors.add(UploadError(row: i + 1, message: 'الموضوع "$fullTopicPath" غير موجود في هذا المادة.'));
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
        if (colOptE != -1 && row.length > colOptE && row[colOptE].toString().trim().isNotEmpty) options.add(row[colOptE].toString().trim());
        if (colOptF != -1 && row.length > colOptF && row[colOptF].toString().trim().isNotEmpty) options.add(row[colOptF].toString().trim());
        if (colOptG != -1 && row.length > colOptG && row[colOptG].toString().trim().isNotEmpty) options.add(row[colOptG].toString().trim());
        if (colOptH != -1 && row.length > colOptH && row[colOptH].toString().trim().isNotEmpty) options.add(row[colOptH].toString().trim());
        if (colOptI != -1 && row.length > colOptI && row[colOptI].toString().trim().isNotEmpty) options.add(row[colOptI].toString().trim());
        if (colOptJ != -1 && row.length > colOptJ && row[colOptJ].toString().trim().isNotEmpty) options.add(row[colOptJ].toString().trim());
        if (colOptK != -1 && row.length > colOptK && row[colOptK].toString().trim().isNotEmpty) options.add(row[colOptK].toString().trim());
        if (colOptL != -1 && row.length > colOptL && row[colOptL].toString().trim().isNotEmpty) options.add(row[colOptL].toString().trim());
        
        if (type == QuestionType.mcq && options.length < 2) {
          errors.add(UploadError(row: i + 1, message: 'أسئلة الاختيارات يجب أن تحتوي على خيارين على الأقل.'));
        }
      }

      // Correct Answer
      String correctAnsRaw = colCorrect != -1 && row.length > colCorrect ? row[colCorrect].toString().trim() : '';
      dynamic correctAnswer;
      if (type == QuestionType.mcq) {
        // Map a, b, c, d, e, f, g, h, i, j, k, l to index 0-11
        int ansIndex = -1;
        switch (correctAnsRaw.toLowerCase()) {
          case 'a': ansIndex = 0; break;
          case 'b': ansIndex = 1; break;
          case 'c': ansIndex = 2; break;
          case 'd': ansIndex = 3; break;
          case 'e': ansIndex = 4; break;
          case 'f': ansIndex = 5; break;
          case 'g': ansIndex = 6; break;
          case 'h': ansIndex = 7; break;
          case 'i': ansIndex = 8; break;
          case 'j': ansIndex = 9; break;
          case 'k': ansIndex = 10; break;
          case 'l': ansIndex = 11; break;
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
        id: _generateQuestionId(text),
        number: i,
        text: text,
        translationText: translation.isNotEmpty ? translation : null,
        type: type,
        options: options.isNotEmpty 
            ? options.asMap().entries.map((e) => QuizOption(id: e.key.toString(), text: e.value)).toList() 
            : null,
        correctOptionIds: (type == QuestionType.mcq || type == QuestionType.trueFalse) ? (correctAnswer != null ? [correctAnswer.toString()] : []) : [],
        essayAnswer: type == QuestionType.essay ? correctAnswer?.toString() : null,
        explanation: expl.isNotEmpty ? expl : null,
        explanationImageUrl: explImg.isNotEmpty ? explImg : null,
        explanationVideoUrl: explVid.isNotEmpty ? explVid : null,
        explanationAudioUrl: explAud.isNotEmpty ? explAud : null,
        explanationPdfUrl: explPdf.isNotEmpty ? explPdf : null,
        imageUrl: imgUrl.isNotEmpty ? imgUrl : null,
        tagLabel: tag.isNotEmpty ? tag : null,
        examTags: examTags,
        difficulty: diff,
        cognitiveLevel: cog,
        topicIds: topicIds.isNotEmpty ? topicIds : null,
        estimatedTime: timeSec,
      );

      parsedQuestions.add(q);
    }

    return ParsedQuestionResult(questions: parsedQuestions, errors: errors);
  }

  Future<ParsedQuestionResult> parseAndValidateExcel(Uint8List fileBytes, String subjectId, {String? sectionId}) async {
    List<QuizQuestion> parsedQuestions = [];
    List<UploadError> errors = [];

    late Excel excel;
    try {
      excel = Excel.decodeBytes(fileBytes);
    } catch (e) {
      return ParsedQuestionResult(questions: [], errors: [UploadError(row: 0, message: 'تعذّر قراءة ملف Excel: $e')]);
    }

    if (excel.tables.isEmpty) {
      return ParsedQuestionResult(questions: [], errors: [UploadError(row: 0, message: 'الملف فارغ أو غير صالح.')]);
    }

    final table = excel.tables.values.first;
    if (table.maxRows <= 1) {
      return ParsedQuestionResult(questions: [], errors: [UploadError(row: 0, message: 'الملف لا يحتوي على أسئلة.')]);
    }

    // Header row
    final headerRow = table.rows.first;
    final header = headerRow.map((e) => e?.value?.toString().trim().toLowerCase() ?? '').toList();

    int colText = header.indexOf('questiontext');
    int colTranslation = header.indexOf('translationtext');
    int colType = header.indexOf('type');
    int colOptA = header.indexOf('opt_a');
    int colOptB = header.indexOf('opt_b');
    int colOptC = header.indexOf('opt_c');
    int colOptD = header.indexOf('opt_d');
    int colOptE = header.indexOf('opt_e');
    int colOptF = header.indexOf('opt_f');
    int colOptG = header.indexOf('opt_g');
    int colOptH = header.indexOf('opt_h');
    int colOptI = header.indexOf('opt_i');
    int colOptJ = header.indexOf('opt_j');
    int colOptK = header.indexOf('opt_k');
    int colOptL = header.indexOf('opt_l');
    int colCorrect = header.indexOf('correctans');
    int colDiff = header.indexOf('difficulty');
    int colCognitive = header.indexOf('cognitivelevel');
    int colTime = header.indexOf('timesec');
    int colTopic = header.indexOf('topicname');
    int colExpl = header.indexOf('explanation');
    int colExplImg = header.indexOf('explanationimageurl');
    int colExplVid = header.indexOf('explanationvideourl');
    int colExplAud = header.indexOf('explanationaudiourl');
    int colExplPdf = header.indexOf('explanationpdfurl');
    int colImg = header.indexOf('imageurl');
    int colTag = header.indexOf('taglabel');
    int colExamTags = header.indexOf('examtags');

    if (colText == -1) {
      return ParsedQuestionResult(questions: [], errors: [UploadError(row: 0, message: 'العمود QuestionText مفقود.')]);
    }

    var excelTopicsQuery = _db.collection('topics')
        .where('subjectId', isEqualTo: subjectId);
    
    if (sectionId != null) {
      excelTopicsQuery = excelTopicsQuery.where('sectionId', isEqualTo: sectionId);
    }

    final topicsSnap = await excelTopicsQuery.get();
    
    Map<String, String> topicMap = {};
    Map<String, Map<String, dynamic>> topicsRawMap = {};
    
    for (var doc in topicsSnap.docs) {
      final data = doc.data();
      final name = (data['name'] as String).trim().toLowerCase();
      topicMap[name] = doc.id;
      topicsRawMap[doc.id] = data;
    }

    final seenQuestions = <String>{};

    for (int i = 1; i < table.maxRows; i++) {
      var row = table.rows[i];
      if (row.isEmpty || row.length <= colText || row[colText]?.value == null || row[colText]!.value.toString().trim().isEmpty) continue;

      String text = row[colText]!.value.toString().trim();
      final normalizedText = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (seenQuestions.contains(normalizedText)) {
        errors.add(UploadError(row: i + 1, message: 'سؤال مكرر داخل الملف.'));
        continue;
      }
      seenQuestions.add(normalizedText);

      // Extract new fields safely
      String translation = colTranslation != -1 && row.length > colTranslation ? row[colTranslation]?.value?.toString().trim() ?? '' : '';
      String explImg = colExplImg != -1 && row.length > colExplImg ? row[colExplImg]?.value?.toString().trim() ?? '' : '';
      String explVid = colExplVid != -1 && row.length > colExplVid ? row[colExplVid]?.value?.toString().trim() ?? '' : '';
      String explAud = colExplAud != -1 && row.length > colExplAud ? row[colExplAud]?.value?.toString().trim() ?? '' : '';
      String explPdf = colExplPdf != -1 && row.length > colExplPdf ? row[colExplPdf]?.value?.toString().trim() ?? '' : '';
      String imgUrl = colImg != -1 && row.length > colImg ? row[colImg]?.value?.toString().trim() ?? '' : '';
      String tag = colTag != -1 && row.length > colTag ? row[colTag]?.value?.toString().trim() ?? '' : '';
      
      String examTagsRaw = colExamTags != -1 && row.length > colExamTags ? row[colExamTags]?.value?.toString().trim() ?? '' : '';
      List<String> examTags = [];
      if (examTagsRaw.isNotEmpty) {
        examTags = examTagsRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }

      String fullTopicPath = colTopic != -1 && row.length > colTopic ? row[colTopic]?.value?.toString().trim() ?? '' : '';
      List<String> topicIds = [];
      if (fullTopicPath.isNotEmpty) {
        String chapterName = '';
        String lessonName = fullTopicPath;
        if (fullTopicPath.contains(' - ')) {
          final parts = fullTopicPath.split(' - ');
          chapterName = parts[0].trim().toLowerCase();
          lessonName = parts[1].trim().toLowerCase();
        } else {
          lessonName = fullTopicPath.trim().toLowerCase();
        }

        String? finalTopicId;
        if (chapterName.isNotEmpty) {
          final chapterId = topicMap[chapterName];
          if (chapterId != null) {
            for (var entry in topicsRawMap.entries) {
              if (entry.value['name'].toString().toLowerCase() == lessonName && entry.value['parentId'] == chapterId) {
                finalTopicId = entry.key;
                break;
              }
            }
          }
        }
        finalTopicId ??= topicMap[lessonName];

        if (finalTopicId != null) {
          topicIds.add(finalTopicId);
        } else {
          errors.add(UploadError(row: i + 1, message: 'الموضوع "$fullTopicPath" غير موجود.'));
        }
      }

      String typeStr = colType != -1 && row.length > colType ? row[colType]?.value?.toString().trim().toLowerCase() ?? 'mcq' : 'mcq';
      QuestionType type = typeStr == 'tf' ? QuestionType.trueFalse : (typeStr == 'essay' ? QuestionType.essay : QuestionType.mcq);

      List<String> options = [];
      if (type == QuestionType.mcq || type == QuestionType.trueFalse) {
        if (colOptA != -1 && row.length > colOptA && row[colOptA]?.value != null && row[colOptA]!.value.toString().trim().isNotEmpty) options.add(row[colOptA]!.value.toString().trim());
        if (colOptB != -1 && row.length > colOptB && row[colOptB]?.value != null && row[colOptB]!.value.toString().trim().isNotEmpty) options.add(row[colOptB]!.value.toString().trim());
        if (colOptC != -1 && row.length > colOptC && row[colOptC]?.value != null && row[colOptC]!.value.toString().trim().isNotEmpty) options.add(row[colOptC]!.value.toString().trim());
        if (colOptD != -1 && row.length > colOptD && row[colOptD]?.value != null && row[colOptD]!.value.toString().trim().isNotEmpty) options.add(row[colOptD]!.value.toString().trim());
        if (colOptE != -1 && row.length > colOptE && row[colOptE]?.value != null && row[colOptE]!.value.toString().trim().isNotEmpty) options.add(row[colOptE]!.value.toString().trim());
        if (colOptF != -1 && row.length > colOptF && row[colOptF]?.value != null && row[colOptF]!.value.toString().trim().isNotEmpty) options.add(row[colOptF]!.value.toString().trim());
        if (colOptG != -1 && row.length > colOptG && row[colOptG]?.value != null && row[colOptG]!.value.toString().trim().isNotEmpty) options.add(row[colOptG]!.value.toString().trim());
        if (colOptH != -1 && row.length > colOptH && row[colOptH]?.value != null && row[colOptH]!.value.toString().trim().isNotEmpty) options.add(row[colOptH]!.value.toString().trim());
        if (colOptI != -1 && row.length > colOptI && row[colOptI]?.value != null && row[colOptI]!.value.toString().trim().isNotEmpty) options.add(row[colOptI]!.value.toString().trim());
        if (colOptJ != -1 && row.length > colOptJ && row[colOptJ]?.value != null && row[colOptJ]!.value.toString().trim().isNotEmpty) options.add(row[colOptJ]!.value.toString().trim());
        if (colOptK != -1 && row.length > colOptK && row[colOptK]?.value != null && row[colOptK]!.value.toString().trim().isNotEmpty) options.add(row[colOptK]!.value.toString().trim());
        if (colOptL != -1 && row.length > colOptL && row[colOptL]?.value != null && row[colOptL]!.value.toString().trim().isNotEmpty) options.add(row[colOptL]!.value.toString().trim());
      }

      String correctAnsRaw = colCorrect != -1 && row.length > colCorrect ? row[colCorrect]?.value?.toString().trim() ?? '' : '';
      dynamic correctAnswer;
      if (type == QuestionType.mcq) {
        int ansIndex = -1;
        switch (correctAnsRaw.toLowerCase()) {
          case 'a': ansIndex = 0; break;
          case 'b': ansIndex = 1; break;
          case 'c': ansIndex = 2; break;
          case 'd': ansIndex = 3; break;
          case 'e': ansIndex = 4; break;
          case 'f': ansIndex = 5; break;
          case 'g': ansIndex = 6; break;
          case 'h': ansIndex = 7; break;
          case 'i': ansIndex = 8; break;
          case 'j': ansIndex = 9; break;
          case 'k': ansIndex = 10; break;
          case 'l': ansIndex = 11; break;
        }
        if (ansIndex != -1 && ansIndex < options.length) correctAnswer = ansIndex;
      } else if (type == QuestionType.trueFalse) {
        if (correctAnsRaw.toLowerCase() == 'true' || correctAnsRaw.toLowerCase() == 'صح') {
          correctAnswer = true;
        } else if (correctAnsRaw.toLowerCase() == 'false' || correctAnsRaw.toLowerCase() == 'خطأ') {
          correctAnswer = false;
        }
      } else {
        correctAnswer = correctAnsRaw;
      }

      Difficulty diff = Difficulty.values.firstWhere((e) => e.name == (colDiff != -1 && row.length > colDiff ? row[colDiff]?.value?.toString().trim().toLowerCase() : 'medium'), orElse: () => Difficulty.medium);
      CognitiveLevel cog = CognitiveLevel.values.firstWhere((e) => e.name == (colCognitive != -1 && row.length > colCognitive ? row[colCognitive]?.value?.toString().trim().toLowerCase() : 'understanding'), orElse: () => CognitiveLevel.understanding);
      int timeSec = int.tryParse(colTime != -1 && row.length > colTime ? row[colTime]?.value?.toString() ?? '60' : '60') ?? 60;

      parsedQuestions.add(QuizQuestion(
        id: _generateQuestionId(text),
        number: i,
        text: text,
        translationText: translation.isNotEmpty ? translation : null,
        type: type,
        options: options.isNotEmpty ? options.asMap().entries.map((e) => QuizOption(id: e.key.toString(), text: e.value)).toList() : null,
        correctOptionIds: (type == QuestionType.mcq || type == QuestionType.trueFalse) ? (correctAnswer != null ? [correctAnswer.toString()] : []) : [],
        essayAnswer: type == QuestionType.essay ? correctAnswer?.toString() : null,
        explanation: colExpl != -1 && row.length > colExpl ? row[colExpl]?.value?.toString().trim() : null,
        explanationImageUrl: explImg.isNotEmpty ? explImg : null,
        explanationVideoUrl: explVid.isNotEmpty ? explVid : null,
        explanationAudioUrl: explAud.isNotEmpty ? explAud : null,
        explanationPdfUrl: explPdf.isNotEmpty ? explPdf : null,
        imageUrl: imgUrl.isNotEmpty ? imgUrl : null,
        tagLabel: tag.isNotEmpty ? tag : null,
        examTags: examTags,
        difficulty: diff,
        cognitiveLevel: cog,
        topicIds: topicIds.isNotEmpty ? topicIds : null,
        estimatedTime: timeSec,
      ));
    }

    return ParsedQuestionResult(questions: parsedQuestions, errors: errors);
  }

  Future<ParsedQuestionResult> parseAndValidateJSON(Uint8List fileBytes) async {
    try {
      final jsonString = utf8.decode(fileBytes);
      final List<dynamic> data = json.decode(jsonString);
      List<QuizQuestion> parsedQuestions = [];
      List<UploadError> errors = [];

      for (int i = 0; i < data.length; i++) {
        try {
          final q = QuizQuestion.fromMap(data[i] as Map<String, dynamic>);
          // Regenerate ID to ensure consistency and avoid collisions if imported from a different source
          final finalQ = q.copyWith(id: _generateQuestionId(q.text));
          parsedQuestions.add(finalQ);
        } catch (e) {
          errors.add(UploadError(row: i + 1, message: 'بيانات غير صالحة: $e'));
        }
      }
      return ParsedQuestionResult(questions: parsedQuestions, errors: errors);
    } catch (e) {
      return ParsedQuestionResult(questions: [], errors: [UploadError(row: 0, message: 'ملف JSON غير صالح: $e')]);
    }
  }

  Future<void> saveQuestions(List<QuizQuestion> questions, String subjectId, {String? sectionId}) async {
    final batch = _db.batch();
    for (var q in questions) {
      final docRef = _db.collection('questions').doc(q.id);
      final data = q.toMap();
      data['subjectId'] = subjectId;
      if (sectionId != null) {
        data['parentId'] = sectionId;
      }
      data['updatedAt'] = FieldValue.serverTimestamp();
      batch.set(docRef, data, SetOptions(merge: true));
    }
    await batch.commit();
  }

  String _generateQuestionId(String text) {
    // Generate a deterministic ID based on question text to prevent duplicates
    final normalized = text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return 'q_${normalized.hashCode.abs()}';
  }


  static Uint8List generateExcelTemplate({
    required List<QuizQuestion> questions,
    required Map<String, Map<String, dynamic>> topicsMap,
  }) {
    final excel = Excel.createExcel();
    final sheet = excel['Questions'];
    excel.setDefaultSheet('Questions');

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#EEEEEE'),
    );

    final List<String> headers = [
      'QuestionText',
      'TranslationText',
      'Type',
      'Opt_A',
      'Opt_B',
      'Opt_C',
      'Opt_D',
      'Opt_E',
      'Opt_F',
      'Opt_G',
      'Opt_H',
      'Opt_I',
      'Opt_J',
      'Opt_K',
      'Opt_L',
      'CorrectAns',
      'Difficulty',
      'CognitiveLevel',
      'TimeSec',
      'TopicName',
      'Explanation',
      'ExplanationImageUrl',
      'ExplanationVideoUrl',
      'ExplanationAudioUrl',
      'ExplanationPdfUrl',
      'ImageUrl',
      'TagLabel',
      'ExamTags'
    ];

    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final options = q.options ?? [];
      
      String correctAns = '';
      if (q.type == QuestionType.mcq) {
        int idx = options.indexWhere((o) => q.correctOptionIds.contains(o.id));
        if (idx != -1) correctAns = String.fromCharCode(97 + idx);
      } else if (q.type == QuestionType.trueFalse) {
        correctAns = q.correctOptionIds.contains('true') || q.correctOptionIds.contains('صح') ? 'صح' : 'خطأ';
      } else {
        correctAns = q.essayAnswer ?? '';
      }

      String topicName = '';
      if (q.topicIds != null && q.topicIds!.isNotEmpty) {
        final topicId = q.topicIds!.first;
        final topicData = topicsMap[topicId];
        if (topicData != null) {
          final parentId = topicData['parentId'];
          if (parentId != null) {
            final parentData = topicsMap[parentId];
            topicName = "${parentData?['name'] ?? ''} - ${topicData['name'] ?? ''}";
          } else {
            topicName = topicData['name'] ?? '';
          }
        }
      }

      final rowValues = [
        q.text,
        q.translationText ?? '',
        q.type.name,
        options.isNotEmpty ? options[0].text : '',
        options.length > 1 ? options[1].text : '',
        options.length > 2 ? options[2].text : '',
        options.length > 3 ? options[3].text : '',
        options.length > 4 ? options[4].text : '',
        options.length > 5 ? options[5].text : '',
        options.length > 6 ? options[6].text : '',
        options.length > 7 ? options[7].text : '',
        options.length > 8 ? options[8].text : '',
        options.length > 9 ? options[9].text : '',
        options.length > 10 ? options[10].text : '',
        options.length > 11 ? options[11].text : '',
        correctAns,
        q.difficulty?.name ?? 'medium',
        q.cognitiveLevel?.name ?? 'understanding',
        q.estimatedTime,
        topicName,
        q.explanation ?? '',
        q.explanationImageUrl ?? '',
        q.explanationVideoUrl ?? '',
        q.explanationAudioUrl ?? '',
        q.explanationPdfUrl ?? '',
        q.imageUrl ?? '',
        q.tagLabel ?? '',
        q.examTags.join(', '),
      ];

      for (int j = 0; j < rowValues.length; j++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1));
        final val = rowValues[j];
        if (val is int) {
          cell.value = IntCellValue(val);
        } else if (val is double) {
          cell.value = DoubleCellValue(val);
        } else {
          cell.value = TextCellValue(val.toString());
        }
      }
    }

    return Uint8List.fromList(excel.encode()!);
  }

  static Uint8List generateJSONTemplate(List<QuizQuestion> questions) {
    final List<Map<String, dynamic>> data = questions.map((q) => q.toMap()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    return Uint8List.fromList(utf8.encode(jsonString));
  }
}
