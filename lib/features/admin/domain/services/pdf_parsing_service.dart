import 'dart:convert';
import 'package:dio/dio.dart' as dio_client;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:quizzly/features/quiz/domain/services/ai_grading_service.dart';

class ExtractedQuestionOption {
  final String id;
  final String text;

  ExtractedQuestionOption({required this.id, required this.text});

  factory ExtractedQuestionOption.fromMap(Map<String, dynamic> map) {
    return ExtractedQuestionOption(
      id: map['id']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'text': text};
  }
}

class ExtractedQuestion {
  final String text;
  final String type; // 'mcq', 'tf', 'checkbox', 'essay'
  final List<ExtractedQuestionOption> options;
  final List<String> correctOptionIds;
  final List<String>? topicIds;
  final List<String>? topicNames;
  final String? explanation;

  ExtractedQuestion({
    required this.text,
    required this.type,
    required this.options,
    required this.correctOptionIds,
    this.topicIds,
    this.topicNames,
    this.explanation,
  });

  factory ExtractedQuestion.fromMap(Map<String, dynamic> map) {
    final optsList = (map['options'] as List?) ?? [];
    final options = optsList
        .map(
          (o) => ExtractedQuestionOption.fromMap(Map<String, dynamic>.from(o)),
        )
        .toList();

    final correctIds =
        (map['correctOptionIds'] as List?)?.map((e) => e.toString()).toList() ??
        [];

    final tIds = (map['topicIds'] as List?)?.map((e) => e.toString()).toList();
    final tNames = (map['topicNames'] as List?)
        ?.map((e) => e.toString())
        .toList();

    return ExtractedQuestion(
      text: map['text']?.toString() ?? '',
      type: map['type']?.toString() ?? 'mcq',
      options: options,
      correctOptionIds: correctIds,
      topicIds: tIds,
      topicNames: tNames,
      explanation: map['explanation']?.toString(),
    );
  }
}

class PDFParsingService {
  // Singleton pattern implementation
  static final PDFParsingService _instance = PDFParsingService._internal();

  factory PDFParsingService() {
    return _instance;
  }

  PDFParsingService._internal();

  final dio_client.Dio _dio = dio_client.Dio(
    dio_client.BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 150),
    ),
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<ExtractedQuestion>> parsePDF(
    Uint8List pdfBytes, {
    String? subjectId,
    String? sectionId,
    int retryCount = 0,
    List<String>? errors,
  }) async {
    final currentErrors = errors ?? [];

    // Load available topics context if subjectId is provided
    String topicsPromptContext = '';
    if (subjectId != null) {
      try {
        final snapshot = await _firestore
            .collection('topics')
            .where('subjectId', isEqualTo: subjectId)
            .get();
        final docs = snapshot.docs;
        final nameMap = {
          for (var doc in docs) doc.id: doc.data()['name'] ?? '',
        };
        final lessons = docs
            .where((doc) => doc.data()['type'] == 'lesson')
            .toList();

        if (lessons.isNotEmpty) {
          final buffer = StringBuffer();
          buffer.writeln(
            '\nAvailable Topics/Lessons (Use these exact IDs in "topicIds" if the question is related):',
          );
          for (var doc in lessons) {
            final data = doc.data();
            final parentId = data['parentId'];
            final parentName = parentId != null ? nameMap[parentId] : null;
            final fullName = parentName != null
                ? '$parentName - ${data['name']}'
                : data['name'];
            buffer.writeln('- ID: "${doc.id}", Name: "$fullName"');
          }
          topicsPromptContext = buffer.toString();
        }
      } catch (e) {
        debugPrint('Error loading topics context for parsePDF: $e');
      }
    }

    // 1. Fetch AI configurations from Firestore
    final doc = await _firestore.collection('settings').doc('ai_config').get();
    if (!doc.exists) {
      throw Exception('لم يتم ضبط إعدادات الذكاء الاصطناعي في لوحة التحكم.');
    }

    final data = doc.data()!;
    final geminiKey = data['geminiKey']?.toString() ?? '';
    final openRouterKey = data['openRouterKey']?.toString() ?? '';
    final openRouterModel =
        data['openRouterModel']?.toString() ??
        'nvidia/nemotron-3-ultra-550b-a55b:free';

    if (geminiKey.isEmpty && openRouterKey.isEmpty) {
      throw Exception(
        'يرجى ضبط مفاتيح الذكاء الاصطناعي (Gemini أو OpenRouter) في لوحة التحكم أولاً.',
      );
    }

    AIProvider provider;
    if (retryCount == 0) {
      provider = geminiKey.isNotEmpty
          ? AIProvider.gemini
          : AIProvider.openRouter;
    } else if (retryCount == 1) {
      provider = AIProvider.openRouter;
    } else {
      throw Exception(
        'فشلت جميع محاولات قراءة الـ PDF بالذكاء الاصطناعي.\nالأخطاء:\n${currentErrors.join('\n')}',
      );
    }

    if ((provider == AIProvider.gemini && geminiKey.isEmpty) ||
        (provider == AIProvider.openRouter && openRouterKey.isEmpty)) {
      currentErrors.add('${provider.name}: مفتاح API فارغ');
      return parsePDF(
        pdfBytes,
        subjectId: subjectId,
        sectionId: sectionId,
        retryCount: retryCount + 1,
        errors: currentErrors,
      );
    }

    final base64PDF = base64Encode(pdfBytes);

    final prompt =
        '''
Extract all questions from the attached exam PDF.
Return a raw JSON array matching this schema:
[
  {
    "text": "Question text in Arabic...",
    "type": "mcq" | "tf" | "checkbox", // Use "mcq" for multiple choice (choice options A, B, C, D), "tf" for True/False (صح/خطأ), "checkbox" for multiple correct answers.
    "options": [
      {"id": "A", "text": "Option text..."},
      {"id": "B", "text": "Option text..."}
    ],
    "correctOptionIds": ["A"], // List containing the ID of correct option(s). For "tf", options must be [{"id": "A", "text": "صح"}, {"id": "B", "text": "خطأ"}].
    "explanation": "Detailed step-by-step solution or explanation of how to solve the question in Arabic...",
    "topicIds": [] // Select relevant topic ID(s) from the list below if applicable.
  }
]
$topicsPromptContext

CRITICAL REQUIREMENT:
1. Represent actual mathematical/chemical equations, formulas, variables, and reactions in LaTeX using \$ for inline or \$\$ for block math.
2. DO NOT wrap plain text, English words, names, or simple units (e.g. Joule, Joul, Volt, Ampere, Ohm, Kelvin, Watt, m, kg, sec, mol) in LaTeX delimiters (\$...\$ or \\text{...}). They must be returned as plain text so they render in standard clean fonts.
3. Extract ALL questions from the document.
4. SOLVE each question scientifically using precise curriculum-aligned physics/chemistry knowledge to guarantee "correctOptionIds" are completely correct. Double-check all calculation units (e.g., Heat capacity unit is Joule/Kelvin or J/K, not Joule/mol).
5. Generate a detailed, step-by-step explanation/solution in Arabic for each question and put it in the "explanation" field.
6. Match each question with the correct topic ID(s) from the available topics list provided above, and include it in the "topicIds" array. If no topic matches, leave it empty.
''';

    try {
      String responseText = '';
      if (provider == AIProvider.gemini) {
        final url =
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=$geminiKey';
        final response = await _dio.post(
          url,
          data: {
            "contents": [
              {
                "parts": [
                  {"text": prompt},
                  {
                    "inlineData": {
                      "mimeType": "application/pdf",
                      "data": base64PDF,
                    },
                  },
                ],
              },
            ],
            "generationConfig": {"responseMimeType": "application/json"},
          },
        );
        responseText =
            response.data['candidates'][0]['content']['parts'][0]['text'];
      } else if (provider == AIProvider.openRouter) {
        final url = 'https://openrouter.ai/api/v1/chat/completions';
        final response = await _dio.post(
          url,
          options: dio_client.Options(
            headers: {
              'Authorization': 'Bearer $openRouterKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://github.com/Quizzly',
              'X-Title': 'Quizzly Admin App',
            },
          ),
          data: {
            "model": openRouterModel,
            "messages": [
              {
                "role": "user",
                "content": [
                  {"type": "text", "text": prompt},
                  {
                    "type": "file",
                    "file": {
                      "filename": "exam.pdf",
                      "file_data": "data:application/pdf;base64,$base64PDF",
                    },
                  },
                ],
              },
            ],
          },
        );

        final choices = response.data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final firstChoice = choices[0] as Map?;
          final message = firstChoice?['message'] as Map?;
          responseText = message?['content']?.toString() ?? '';
        }
      }

      if (responseText.isNotEmpty) {
        return _parseResponseJson(responseText);
      }
      throw Exception('لم يرجع نموذج ${provider.name} أي استجابة صالحة.');
    } catch (e) {
      String errMsg = e.toString();
      if (e is dio_client.DioException) {
        final resp = e.response;
        if (resp != null) {
          errMsg =
              'Dio Error (${resp.statusCode}): ${resp.statusMessage ?? ''} ${resp.data ?? ''}';
        }
      }
      debugPrint('Error parsing PDF with ${provider.name}: $errMsg');
      currentErrors.add('${provider.name}: $errMsg');
      return parsePDF(
        pdfBytes,
        subjectId: subjectId,
        sectionId: sectionId,
        retryCount: retryCount + 1,
        errors: currentErrors,
      );
    }
  }

  Future<List<ExtractedQuestion>> parseText(
    String examText, {
    int retryCount = 0,
    List<String>? errors,
  }) async {
    final currentErrors = errors ?? [];
    // 1. Fetch AI configurations from Firestore
    final doc = await _firestore.collection('settings').doc('ai_config').get();
    if (!doc.exists) {
      throw Exception('لم يتم ضبط إعدادات الذكاء الاصطناعي في لوحة التحكم.');
    }

    final data = doc.data()!;
    final geminiKey = data['geminiKey']?.toString() ?? '';
    final groqKey = data['groqKey']?.toString() ?? '';
    final openRouterKey = data['openRouterKey']?.toString() ?? '';
    final openRouterModel =
        data['openRouterModel']?.toString() ??
        'nvidia/nemotron-3-ultra-550b-a55b:free';

    if (geminiKey.isEmpty && groqKey.isEmpty && openRouterKey.isEmpty) {
      throw Exception('لم يتم ضبط مفاتيح الذكاء الاصطناعي في لوحة التحكم.');
    }

    AIProvider provider;
    if (retryCount == 0) {
      provider = geminiKey.isNotEmpty
          ? AIProvider.gemini
          : (groqKey.isNotEmpty ? AIProvider.groq : AIProvider.openRouter);
    } else if (retryCount == 1) {
      provider = (geminiKey.isNotEmpty && groqKey.isNotEmpty)
          ? AIProvider.groq
          : AIProvider.openRouter;
    } else if (retryCount == 2) {
      provider = AIProvider.openRouter;
    } else {
      throw Exception(
        'فشلت جميع محاولات استخراج الأسئلة بالذكاء الاصطناعي.\nالأخطاء:\n${currentErrors.join('\n')}',
      );
    }

    if ((provider == AIProvider.gemini && geminiKey.isEmpty) ||
        (provider == AIProvider.groq && groqKey.isEmpty) ||
        (provider == AIProvider.openRouter && openRouterKey.isEmpty)) {
      currentErrors.add('${provider.name}: مفتاح API فارغ');
      return parseText(
        examText,
        retryCount: retryCount + 1,
        errors: currentErrors,
      );
    }

    final prompt =
        '''
Extract all questions from the following exam text.
Return a raw JSON array matching this schema:
[
  {
    "text": "Question text in Arabic...",
    "type": "mcq" | "tf" | "checkbox", // Use "mcq" for multiple choice (choice options A, B, C, D), "tf" for True/False (صح/خطأ), "checkbox" for multiple correct answers.
    "options": [
      {"id": "A", "text": "Option text..."},
      {"id": "B", "text": "Option text..."}
    ],
    "correctOptionIds": ["A"], // List containing the ID of correct option(s). For "tf", options must be [{"id": "A", "text": "صح"}, {"id": "B", "text": "خطأ"}].
    "explanation": "Detailed step-by-step solution or explanation of how to solve the question in Arabic..."
  }
]

CRITICAL REQUIREMENT:
1. Represent actual mathematical/chemical equations, formulas, variables, and reactions in LaTeX using \$ for inline or \$\$ for block math.
2. DO NOT wrap plain text, English words, names, or simple units (e.g. Joule, Joul, Volt, Ampere, Ohm, Kelvin, Watt, m, kg, sec, mol) in LaTeX delimiters (\$...\$ or \\text{...}). They must be returned as plain text so they render in standard clean fonts.
3. Extract ALL questions from the text.
4. SOLVE each question scientifically using precise curriculum-aligned physics/chemistry knowledge to guarantee "correctOptionIds" are completely correct. Double-check all calculation units (e.g., Heat capacity unit is Joule/Kelvin or J/K, not Joule/mol).
5. Generate a detailed, step-by-step explanation/solution in Arabic for each question and put it in the "explanation" field.

Exam text:
$examText
''';

    try {
      String responseText = '';
      if (provider == AIProvider.gemini) {
        final url =
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=$geminiKey';
        final response = await _dio.post(
          url,
          data: {
            "contents": [
              {
                "parts": [
                  {"text": prompt},
                ],
              },
            ],
            "generationConfig": {"responseMimeType": "application/json"},
          },
        );
        responseText =
            response.data['candidates'][0]['content']['parts'][0]['text'];
      } else if (provider == AIProvider.groq) {
        final response = await _dio.post(
          'https://api.groq.com/openai/v1/chat/completions',
          options: dio_client.Options(
            headers: {'Authorization': 'Bearer $groqKey'},
          ),
          data: {
            "model": "llama-3.1-8b-instant",
            "response_format": {"type": "json_object"},
            "messages": [
              {"role": "user", "content": prompt},
            ],
          },
        );
        responseText = response.data['choices'][0]['message']['content'];
      } else if (provider == AIProvider.openRouter) {
        final response = await _dio.post(
          'https://openrouter.ai/api/v1/chat/completions',
          options: dio_client.Options(
            headers: {
              'Authorization': 'Bearer $openRouterKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://github.com/Quizzly',
              'X-Title': 'Quizzly Admin App',
            },
          ),
          data: {
            "model": openRouterModel,
            "messages": [
              {"role": "user", "content": prompt},
            ],
          },
        );
        responseText = response.data['choices'][0]['message']['content'];
      }

      return _parseResponseJson(responseText);
    } catch (e) {
      String errMsg = e.toString();
      if (e is dio_client.DioException) {
        final resp = e.response;
        if (resp != null) {
          errMsg =
              'Dio Error (${resp.statusCode}): ${resp.statusMessage ?? ''} ${resp.data ?? ''}';
        }
      }
      debugPrint('Error extracting text with ${provider.name}: $errMsg');
      currentErrors.add('${provider.name}: $errMsg');
      return parseText(
        examText,
        retryCount: retryCount + 1,
        errors: currentErrors,
      );
    }
  }

  List<ExtractedQuestion> _parseResponseJson(String responseText) {
    responseText = responseText.trim();
    responseText = _escapeRawBackslashes(responseText);

    // Extract JSON block robustly by finding the outer-most list or object boundary
    int firstBracket = responseText.indexOf('[');
    int firstBrace = responseText.indexOf('{');

    int startIdx = -1;
    int endIdx = -1;

    if (firstBracket != -1 && (firstBrace == -1 || firstBracket < firstBrace)) {
      // Outer-most structure is a List
      startIdx = firstBracket;
      endIdx = responseText.lastIndexOf(']');
    } else if (firstBrace != -1 &&
        (firstBracket == -1 || firstBrace < firstBracket)) {
      // Outer-most structure is an Object
      startIdx = firstBrace;
      endIdx = responseText.lastIndexOf('}');
    }

    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      responseText = responseText.substring(startIdx, endIdx + 1);
    }

    var decoded = jsonDecode(responseText);
    if (decoded is Map) {
      // Find the first list value in the map (e.g. "questions" list)
      final listKey = decoded.keys.firstWhere(
        (key) => decoded[key] is List,
        orElse: () => '',
      );
      if (listKey.isNotEmpty) {
        decoded = decoded[listKey];
      }
    }

    if (decoded is! List) {
      throw Exception('تنسيق الاستجابة المستلمة ليس قائمة JSON صالحة.');
    }

    return decoded
        .map(
          (item) => ExtractedQuestion.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<String> solveQuestionWithAI(
    String questionText,
    List<String> options,
  ) async {
    // Fetch AI configurations from Firestore
    final doc = await _firestore.collection('settings').doc('ai_config').get();
    if (!doc.exists) {
      throw Exception('لم يتم ضبط إعدادات الذكاء الاصطناعي في لوحة التحكم.');
    }

    final data = doc.data()!;
    final geminiKey = data['geminiKey']?.toString() ?? '';
    final openRouterKey = data['openRouterKey']?.toString() ?? '';
    final openRouterModel =
        data['openRouterModel']?.toString() ??
        'nvidia/nemotron-3-ultra-550b-a55b:free';

    if (geminiKey.isEmpty && openRouterKey.isEmpty) {
      throw Exception(
        'يرجى ضبط مفاتيح الذكاء الاصطناعي (Gemini أو OpenRouter) في لوحة التحكم أولاً.',
      );
    }

    final provider = geminiKey.isNotEmpty
        ? AIProvider.gemini
        : AIProvider.openRouter;
    final optionsPrompt = options.isNotEmpty
        ? '\nالخيارات:\n${options.map((opt) => "- $opt").join('\n')}'
        : '';

    final prompt =
        '''
حل هذا السؤال بالتفصيل واكتب شرحًا علميًا دقيقًا ومبسطًا لطريقة الحل باللغة العربية.
نص السؤال:
$questionText
$optionsPrompt

المتطلبات الهامة:
1. اكتب الشرح باللغة العربية بشكل منسق ومبسط ليفهمه الطالب.
2. استخدم تنسيق LaTeX للمعادلات والرموز الرياضية والكيميائية (مثل \$ H_2O \$ أو \$ x^2 \$).
3. لا تضف أي نصوص ترحيبية أو كود برمجى أو علامات اقتباس، ابدأ مباشرة بكتابة شرح الحل.
''';

    try {
      String responseText = '';
      if (provider == AIProvider.gemini) {
        final url =
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=$geminiKey';
        final response = await _dio.post(
          url,
          data: {
            "contents": [
              {
                "parts": [
                  {"text": prompt},
                ],
              },
            ],
          },
        );
        responseText =
            response.data['candidates'][0]['content']['parts'][0]['text'];
      } else if (provider == AIProvider.openRouter) {
        final url = 'https://openrouter.ai/api/v1/chat/completions';
        final response = await _dio.post(
          url,
          options: dio_client.Options(
            headers: {
              'Authorization': 'Bearer $openRouterKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://github.com/Quizzly',
              'X-Title': 'Quizzly Admin App',
            },
          ),
          data: {
            "model": openRouterModel,
            "messages": [
              {"role": "user", "content": prompt},
            ],
          },
        );

        final choices = response.data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final firstChoice = choices[0] as Map?;
          final message = firstChoice?['message'] as Map?;
          responseText = message?['content']?.toString() ?? '';
        }
      }

      return responseText.trim();
    } catch (e) {
      String errMsg = e.toString();
      if (e is dio_client.DioException) {
        final resp = e.response;
        if (resp != null) {
          errMsg =
              'Dio Error (${resp.statusCode}): ${resp.statusMessage ?? ''} ${resp.data ?? ''}';
        }
      }
      throw Exception('فشل جلب الحل بالذكاء الاصطناعي: $errMsg');
    }
  }

  Future<List<String>> generateOptionsWithAI(
    String questionText,
    String correctAnswer,
  ) async {
    final doc = await _firestore.collection('settings').doc('ai_config').get();
    if (!doc.exists) {
      throw Exception('لم يتم ضبط إعدادات الذكاء الاصطناعي في لوحة التحكم.');
    }

    final data = doc.data()!;
    final geminiKey = data['geminiKey']?.toString() ?? '';
    final openRouterKey = data['openRouterKey']?.toString() ?? '';
    final openRouterModel =
        data['openRouterModel']?.toString() ??
        'nvidia/nemotron-3-ultra-550b-a55b:free';

    if (geminiKey.isEmpty && openRouterKey.isEmpty) {
      throw Exception(
        'يرجى ضبط مفاتيح الذكاء الاصطناعي (Gemini أو OpenRouter) في لوحة التحكم أولاً.',
      );
    }

    final provider = geminiKey.isNotEmpty
        ? AIProvider.gemini
        : AIProvider.openRouter;

    final prompt =
        '''
أنت مصمم أسئلة تعليمية خبير باللغة العربية.
قم بتوليد 3 خيارات خاطئة ذكية ومقنعة (Distractors) للسؤال التالي، بناءً على الإجابة الصحيحة المعطاة.
السؤال:
$questionText

الإجابة الصحيحة:
$correctAnswer

أرجع النتيجة كـ JSON Array مكون من نصوص الخيارات الخاطئة فقط بصيغة:
[
  "الخيار الخاطئ الأول",
  "الخيار الخاطئ الثاني",
  "الخيار الخاطئ الثالث"
]
أرجع القائمة فقط دون أي شرح أو تنسيق markdown. لا تضف كود ```json.
''';

    try {
      String responseText = '';
      if (provider == AIProvider.gemini) {
        final url =
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=$geminiKey';
        final response = await _dio.post(
          url,
          data: {
            "contents": [
              {
                "parts": [
                  {"text": prompt},
                ],
              },
            ],
            "generationConfig": {"responseMimeType": "application/json"},
          },
        );
        responseText =
            response.data['candidates'][0]['content']['parts'][0]['text'];
      } else if (provider == AIProvider.openRouter) {
        final url = 'https://openrouter.ai/api/v1/chat/completions';
        final response = await _dio.post(
          url,
          options: dio_client.Options(
            headers: {
              'Authorization': 'Bearer $openRouterKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://github.com/Quizzly',
              'X-Title': 'Quizzly Admin App',
            },
          ),
          data: {
            "model": openRouterModel,
            "messages": [
              {"role": "user", "content": prompt},
            ],
          },
        );

        final choices = response.data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final firstChoice = choices[0] as Map?;
          final message = firstChoice?['message'] as Map?;
          responseText = message?['content']?.toString() ?? '';
        }
      }

      responseText = responseText.trim();
      int firstBracket = responseText.indexOf('[');
      int lastBracket = responseText.lastIndexOf(']');
      if (firstBracket != -1 &&
          lastBracket != -1 &&
          lastBracket > firstBracket) {
        responseText = responseText.substring(firstBracket, lastBracket + 1);
      }

      final decoded = jsonDecode(responseText);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
      throw Exception('الاستجابة المستلمة ليست قائمة JSON صالحة.');
    } catch (e) {
      String errMsg = e.toString();
      if (e is dio_client.DioException) {
        final resp = e.response;
        if (resp != null) {
          errMsg =
              'Dio Error (${resp.statusCode}): ${resp.statusMessage ?? ''} ${resp.data ?? ''}';
        }
      }
      throw Exception('فشل توليد الخيارات بالذكاء الاصطناعي: $errMsg');
    }
  }

  String _escapeRawBackslashes(String jsonStr) {
    final sb = StringBuffer();
    for (int i = 0; i < jsonStr.length; i++) {
      final char = jsonStr[i];
      if (char == '\\') {
        if (i + 1 < jsonStr.length) {
          final nextChar = jsonStr[i + 1];
          bool isControl = false;
          if (nextChar == '"' || nextChar == '\\' || nextChar == '/') {
            isControl = true;
          } else if (nextChar == 'n') {
            isControl = true;
          } else if (nextChar == 't') {
            if (i + 2 < jsonStr.length) {
              final afterNext = jsonStr[i + 2];
              isControl = !RegExp(r'[a-zA-Z]').hasMatch(afterNext);
            } else {
              isControl = true;
            }
          } else if (nextChar == 'r') {
            if (i + 2 < jsonStr.length) {
              final afterNext = jsonStr[i + 2];
              isControl = !RegExp(r'[a-zA-Z]').hasMatch(afterNext);
            } else {
              isControl = true;
            }
          } else if (nextChar == 'b') {
            if (i + 2 < jsonStr.length) {
              final afterNext = jsonStr[i + 2];
              isControl = !RegExp(r'[a-zA-Z]').hasMatch(afterNext);
            } else {
              isControl = true;
            }
          } else if (nextChar == 'f') {
            if (i + 2 < jsonStr.length) {
              final afterNext = jsonStr[i + 2];
              isControl = !RegExp(r'[a-zA-Z]').hasMatch(afterNext);
            } else {
              isControl = true;
            }
          } else if (nextChar == 'u') {
            if (i + 5 < jsonStr.length) {
              final hex = jsonStr.substring(i + 2, i + 6);
              isControl = RegExp(r'^[0-9a-fA-F]{4}$').hasMatch(hex);
            }
          }

          if (isControl) {
            sb.write('\\');
          } else {
            sb.write('\\\\');
          }
        } else {
          sb.write('\\\\');
        }
      } else {
        sb.write(char);
      }
    }
    return sb.toString();
  }
}
