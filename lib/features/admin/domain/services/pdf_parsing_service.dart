import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart' as dio_client;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
  final dio_client.Dio _dio = dio_client.Dio();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<ExtractedQuestion>> parsePDF(Uint8List pdfBytes) async {
    // 1. Fetch AI configurations from Firestore
    final doc = await _firestore.collection('settings').doc('ai_config').get();
    if (!doc.exists) {
      throw Exception('لم يتم ضبط إعدادات الذكاء الاصطناعي في لوحة التحكم.');
    }

    final data = doc.data()!;
    final apiKey = data['geminiKey']?.toString() ?? '';
    final proxyUrl = data['cloudflareProxyUrl']?.toString() ??
        'https://quizzly-proxy.omar-rawas17.workers.dev';

    if (apiKey.isEmpty) {
      throw Exception('مفتاح Gemini API Key غير مُعيّن في لوحة التحكم.');
    }

    // 2. Prepare Base64 data for the PDF
    final base64PDF = base64Encode(pdfBytes);

    // 3. Construct prompt
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

    // 4. Send request to Gemini API (via Cloudflare Proxy)
    final url = '$proxyUrl/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';

    try {
      final response = await _dio.post(
        url,
        data: {
          "contents": [
            {
              "parts": [
                {
                  "inlineData": {
                    "mimeType": "application/pdf",
                    "data": base64PDF,
                  }
                },
                {"text": prompt}
              ]
            }
          ]
        },
      );

      final candidates = response.data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('لم يرجع نموذج الذكاء الاصطناعي أي استجابة.');
      }

      String responseText =
          candidates[0]['content']['parts'][0]['text']?.toString() ?? '';
      
      // Clean markdown code blocks if any
      responseText = responseText.trim();
      if (responseText.startsWith('```')) {
        final lines = responseText.split('\n');
        if (lines.first.startsWith('```')) {
          lines.removeAt(0);
        }
        if (lines.isNotEmpty && lines.last.startsWith('```')) {
          lines.removeLast();
        }
        responseText = lines.join('\n').trim();
      }

      final decoded = jsonDecode(responseText);
      if (decoded is! List) {
        throw Exception('تنسيق الاستجابة المستلمة ليس قائمة JSON صالحة.');
      }

      return decoded
          .map((item) => ExtractedQuestion.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } on dio_client.DioException catch (e) {
      final errorMsg = e.response?.data?['error']?['message'] ?? e.message;
      throw Exception('خطأ في الاتصال بالذكاء الاصطناعي: $errorMsg');
    } catch (e) {
      throw Exception('فشل في معالجة وتحليل ملف الـ PDF: $e');
    }
  }
}
