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

  ExtractedQuestion({
    required this.text,
    required this.type,
    required this.options,
    required this.correctOptionIds,
  });

  factory ExtractedQuestion.fromMap(Map<String, dynamic> map) {
    final optsList = (map['options'] as List?) ?? [];
    final options = optsList
        .map((o) => ExtractedQuestionOption.fromMap(Map<String, dynamic>.from(o)))
        .toList();

    final correctIds = (map['correctOptionIds'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return ExtractedQuestion(
      text: map['text']?.toString() ?? '',
      type: map['type']?.toString() ?? 'mcq',
      options: options,
      correctOptionIds: correctIds,
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
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 25),
    ),
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<ExtractedQuestion>> parsePDF(Uint8List pdfBytes, {int retryCount = 0}) async {
    // 1. Fetch AI configurations from Firestore
    final doc = await _firestore.collection('settings').doc('ai_config').get();
    if (!doc.exists) {
      throw Exception('لم يتم ضبط إعدادات الذكاء الاصطناعي في لوحة التحكم.');
    }

    final data = doc.data()!;
    final geminiKey = data['geminiKey']?.toString() ?? '';
    final openRouterKey = data['openRouterKey']?.toString() ?? '';
    final openRouterModel = data['openRouterModel']?.toString() ?? 'nvidia/nemotron-3-ultra-550b-a55b:free';

    if (geminiKey.isEmpty && openRouterKey.isEmpty) {
      throw Exception('يرجى ضبط مفاتيح الذكاء الاصطناعي (Gemini أو OpenRouter) في لوحة التحكم أولاً.');
    }

    AIProvider provider;
    if (retryCount == 0) {
      provider = geminiKey.isNotEmpty ? AIProvider.gemini : AIProvider.openRouter;
    } else if (retryCount == 1) {
      provider = AIProvider.openRouter;
    } else {
      throw Exception('فشلت جميع محاولات قراءة الـ PDF بالذكاء الاصطناعي.');
    }

    if ((provider == AIProvider.gemini && geminiKey.isEmpty) ||
        (provider == AIProvider.openRouter && openRouterKey.isEmpty)) {
      return parsePDF(pdfBytes, retryCount: retryCount + 1);
    }

    final base64PDF = base64Encode(pdfBytes);

    const prompt = '''
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
    "correctOptionIds": ["A"] // List containing the ID of correct option(s). For "tf", options must be [{"id": "A", "text": "صح"}, {"id": "B", "text": "خطأ"}].
  }
]

CRITICAL REQUIREMENT:
1. Ensure all math and chemistry formulas, units, variables, and equations are represented in standard LaTeX format using \$ for inline math or \$\$ for block math. Example: H_2O, pH, 10^{-3}\\text{ sec}^{-1}, [\\text{NaOH}].
2. Return ONLY a valid JSON array. Do not include markdown code block formatting (like ```json ... ```).
3. Extract ALL questions from the document.
''';

    try {
      String responseText = '';
      if (provider == AIProvider.gemini) {
        final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=$geminiKey';
        final response = await _dio.post(url, data: {
          "contents": [
            {
              "parts": [
                {"text": prompt},
                {
                  "inlineData": {
                    "mimeType": "application/pdf",
                    "data": base64PDF
                  }
                }
              ]
            }
          ],
          "generationConfig": {
            "responseMimeType": "application/json"
          }
        });
        responseText = response.data['candidates'][0]['content']['parts'][0]['text'];
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
                      "file_data": "data:application/pdf;base64,$base64PDF"
                    }
                  }
                ]
              }
            ]
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
      debugPrint('Error parsing PDF with ${provider.name}: $e');
      return parsePDF(pdfBytes, retryCount: retryCount + 1);
    }
  }

  Future<List<ExtractedQuestion>> parseText(String examText, {int retryCount = 0}) async {
    // 1. Fetch AI configurations from Firestore
    final doc = await _firestore.collection('settings').doc('ai_config').get();
    if (!doc.exists) {
      throw Exception('لم يتم ضبط إعدادات الذكاء الاصطناعي في لوحة التحكم.');
    }

    final data = doc.data()!;
    final geminiKey = data['geminiKey']?.toString() ?? '';
    final groqKey = data['groqKey']?.toString() ?? '';
    final openRouterKey = data['openRouterKey']?.toString() ?? '';
    final openRouterModel = data['openRouterModel']?.toString() ?? 'nvidia/nemotron-3-ultra-550b-a55b:free';

    if (geminiKey.isEmpty && groqKey.isEmpty && openRouterKey.isEmpty) {
      throw Exception('لم يتم ضبط مفاتيح الذكاء الاصطناعي في لوحة التحكم.');
    }

    AIProvider provider;
    if (retryCount == 0) {
      provider = geminiKey.isNotEmpty ? AIProvider.gemini : (groqKey.isNotEmpty ? AIProvider.groq : AIProvider.openRouter);
    } else if (retryCount == 1) {
      provider = (geminiKey.isNotEmpty && groqKey.isNotEmpty) ? AIProvider.groq : AIProvider.openRouter;
    } else if (retryCount == 2) {
      provider = AIProvider.openRouter;
    } else {
      throw Exception('فشلت جميع محاولات استخراج الأسئلة بالذكاء الاصطناعي.');
    }

    if ((provider == AIProvider.gemini && geminiKey.isEmpty) ||
        (provider == AIProvider.groq && groqKey.isEmpty) ||
        (provider == AIProvider.openRouter && openRouterKey.isEmpty)) {
      return parseText(examText, retryCount: retryCount + 1);
    }

    final prompt = '''
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
    "correctOptionIds": ["A"] // List containing the ID of correct option(s). For "tf", options must be [{"id": "A", "text": "صح"}, {"id": "B", "text": "خطأ"}].
  }
]

CRITICAL REQUIREMENT:
1. Ensure all math and chemistry formulas, units, variables, and equations are represented in standard LaTeX format using \$ for inline math or \$\$ for block math. Example: H_2O, pH, 10^{-3}\\text{ sec}^{-1}, [\\text{NaOH}].
2. Return ONLY a valid JSON array. Do not include markdown code block formatting (like ```json ... ```).
3. Extract ALL questions from the text.

Exam text:
$examText
''';

    try {
      String responseText = '';
      if (provider == AIProvider.gemini) {
        final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=$geminiKey';
        final response = await _dio.post(url, data: {
          "contents": [{
            "parts": [{"text": prompt}]
          }],
          "generationConfig": {
            "responseMimeType": "application/json"
          }
        });
        responseText = response.data['candidates'][0]['content']['parts'][0]['text'];
      } else if (provider == AIProvider.groq) {
        final response = await _dio.post(
          'https://api.groq.com/openai/v1/chat/completions',
          options: dio_client.Options(headers: {'Authorization': 'Bearer $groqKey'}),
          data: {
            "model": "llama3-8b-8192",
            "response_format": {"type": "json_object"},
            "messages": [
              {"role": "user", "content": prompt}
            ]
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
              {"role": "user", "content": prompt}
            ]
          },
        );
        responseText = response.data['choices'][0]['message']['content'];
      }

      return _parseResponseJson(responseText);
    } catch (e) {
      debugPrint('Error extracting text with ${provider.name}: $e');
      return parseText(examText, retryCount: retryCount + 1);
    }
  }

  List<ExtractedQuestion> _parseResponseJson(String responseText) {
    responseText = responseText.trim();
    
    // Extract JSON block robustly by finding the outer-most brackets/braces
    int firstBracket = responseText.indexOf('[');
    int lastBracket = responseText.lastIndexOf(']');
    
    // If no list brackets found, check for object braces
    if (firstBracket == -1 || lastBracket == -1 || lastBracket < firstBracket) {
      firstBracket = responseText.indexOf('{');
      lastBracket = responseText.lastIndexOf('}');
    }
    
    if (firstBracket != -1 && lastBracket != -1 && lastBracket > firstBracket) {
      responseText = responseText.substring(firstBracket, lastBracket + 1);
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
        .map((item) => ExtractedQuestion.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }
}
