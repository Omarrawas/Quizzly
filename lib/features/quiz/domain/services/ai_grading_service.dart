import 'dart:convert';
import 'package:dio/dio.dart' as dio_client;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AIGradingResult {
  final double score;
  final String feedback;
  final bool isSuccess;

  AIGradingResult({
    required this.score,
    required this.feedback,
    this.isSuccess = true,
  });

  factory AIGradingResult.error(String message) {
    return AIGradingResult(score: 0, feedback: message, isSuccess: false);
  }
}

enum AIProvider { gemini, groq, openRouter }

class AIGradingService {
  // Singleton pattern implementation
  static final AIGradingService _instance = AIGradingService._internal();

  factory AIGradingService() {
    return _instance;
  }

  AIGradingService._internal();

  final dio_client.Dio _dio = dio_client.Dio(
    dio_client.BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // الإعدادات الافتراضية (سيتم تجاوزها من Firestore إذا وجدت)
  String _geminiKey = '';
  String _groqKey = '';
  String _openRouterKey = '';
  String _openRouterModel = 'nvidia/nemotron-3-ultra-550b-a55b:free';
  String _cloudflareProxyUrl = 'https://quizzly-proxy.omar-rawas17.workers.dev';

  bool _isInitialized = false;

  /// تحميل الإعدادات من Firestore
  Future<void> _initialize() async {
    if (_isInitialized) return;
    try {
      final doc = await _firestore.collection('settings').doc('ai_config').get();
      if (doc.exists) {
        final data = doc.data()!;
        _geminiKey = data['geminiKey'] ?? '';
        _groqKey = data['groqKey'] ?? '';
        _openRouterKey = data['openRouterKey'] ?? '';
        _openRouterModel = data['openRouterModel'] ?? 'nvidia/nemotron-3-ultra-550b-a55b:free';
        _cloudflareProxyUrl = data['cloudflareProxyUrl'] ?? _cloudflareProxyUrl;
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error loading AI config: $e');
    }
  }

  Future<AIGradingResult> gradeEssayAnswer({
    required String question,
    required String studentAnswer,
    required String modelAnswer,
    String? explanation,
    int retryCount = 0,
  }) async {
    await _initialize();

    // التحقق من وجود مفاتيح
    if (_geminiKey.isEmpty && _groqKey.isEmpty && _openRouterKey.isEmpty) {
      return AIGradingResult.error('لم يتم ضبط مفاتيح الذكاء الاصطناعي في لوحة التحكم.');
    }

    AIProvider provider;
    if (retryCount == 0) {
      provider = AIProvider.gemini;
    } else if (retryCount == 1) {
      provider = AIProvider.groq;
    } else if (retryCount == 2) {
      provider = AIProvider.openRouter;
    } else {
      return AIGradingResult.error('فشلت جميع المحاولات. يرجى التأكد من الاتصال بالإنترنت.');
    }

    // تخطي المزود إذا كان مفتاحه فارغاً
    if ((provider == AIProvider.gemini && _geminiKey.isEmpty) ||
        (provider == AIProvider.groq && _groqKey.isEmpty) ||
        (provider == AIProvider.openRouter && _openRouterKey.isEmpty)) {
      return gradeEssayAnswer(
        question: question,
        studentAnswer: studentAnswer,
        modelAnswer: modelAnswer,
        explanation: explanation,
        retryCount: retryCount + 1,
      );
    }

    try {
      String responseText = '';
      
      if (provider == AIProvider.gemini) {
        responseText = await _callGemini(question, studentAnswer, modelAnswer, explanation);
      } else if (provider == AIProvider.groq) {
        responseText = await _callOpenAICompatible(
          url: 'https://api.groq.com/openai/v1/chat/completions',
          key: _groqKey,
          model: 'llama3-8b-8192',
          question: question,
          studentAnswer: studentAnswer,
          modelAnswer: modelAnswer,
        );
      } else if (provider == AIProvider.openRouter) {
        responseText = await _callOpenAICompatible(
          url: 'https://openrouter.ai/api/v1/chat/completions',
          key: _openRouterKey,
          model: _openRouterModel,
          question: question,
          studentAnswer: studentAnswer,
          modelAnswer: modelAnswer,
        );
      }

      return _parseResponse(responseText);

    } catch (e) {
      debugPrint('Error with ${provider.name}: $e');
      return gradeEssayAnswer(
        question: question,
        studentAnswer: studentAnswer,
        modelAnswer: modelAnswer,
        explanation: explanation,
        retryCount: retryCount + 1,
      );
    }
  }

  Future<String> _callGemini(String q, String ans, String modelAns, String? exp) async {
    final prompt = _buildPrompt(q, ans, modelAns, exp);
    final url = '$_cloudflareProxyUrl/v1beta/models/gemini-2.0-flash:generateContent?key=$_geminiKey';
    
    final response = await _dio.post(url, data: {
      "contents": [{
        "parts": [{"text": prompt}]
      }],
      "generationConfig": {
        "responseMimeType": "application/json"
      }
    });

    return response.data['candidates'][0]['content']['parts'][0]['text'];
  }

  Future<String> _callOpenAICompatible({
    required String url,
    required String key,
    required String model,
    required String question,
    required String studentAnswer,
    required String modelAnswer,
  }) async {
    final prompt = _buildPrompt(question, studentAnswer, modelAnswer, null);
    
    final response = await _dio.post(
      url,
      options: dio_client.Options(headers: {'Authorization': 'Bearer $key'}),
      data: {
        "model": model,
        "response_format": {"type": "json_object"},
        "messages": [
          {"role": "system", "content": "أنت مصحح أكاديمي خبير باللغة العربية. يجب أن ترجع النتيجة بصيغة JSON فقط."},
          {"role": "user", "content": prompt}
        ]
      },
    );

    return response.data['choices'][0]['message']['content'];
  }

  String _buildPrompt(String q, String ans, String modelAns, String? exp) {
    return '''
قم بتقييم إجابة الطالب الأكاديمية بناءً على المعطيات التالية:
السؤال: "$q"
الإجابة النموذجية: "$modelAns"
توضيح: "${exp ?? ''}"
إجابة الطالب: "$ans"

المطلوب بدقة هو إرجاع النتيجة ككائن JSON صالح ومكتمل يحتوي على المفاتيح التالية باللغة العربية:
{
  "score": [الدرجة المستحقة كرقم عشري أو صحيح من 10 مثل 8.5 أو 9],
  "feedback": "[نص التقييم والتعليق الأكاديمي المختصر والمفيد باللغة العربية]"
}
''';
  }

  /// اختبار اتصال مزود محدد
  Future<String?> testProvider({
    required AIProvider provider,
    String? model,
    String? apiKey,
  }) async {
    await _initialize();

    try {
      if (provider == AIProvider.gemini) {
        final key = apiKey?.trim() ?? _geminiKey;
        if (key.isEmpty) return 'Gemini API Key غير مُعيّن';
        final url = '$_cloudflareProxyUrl/v1beta/models/gemini-2.0-flash:generateContent?key=$key';
        final response = await _dio.post(url, data: {
          "contents": [{"parts": [{"text": "قل 'مرحبا'"}]}]
        });
        return response.data['candidates'][0]['content']['parts'][0]['text'];
      } else if (provider == AIProvider.groq) {
        final key = apiKey?.trim() ?? _groqKey;
        if (key.isEmpty) return 'Groq API Key غير مُعيّن';
        final response = await _dio.post(
          'https://api.groq.com/openai/v1/chat/completions',
          options: dio_client.Options(headers: {'Authorization': 'Bearer $key'}),
          data: {
            "model": model ?? 'llama3-8b-8192',
            "messages": [{"role": "user", "content": "قل 'مرحبا'"}]
          },
        );
        return response.data['choices'][0]['message']['content'];
      } else if (provider == AIProvider.openRouter) {
        final key = apiKey?.trim() ?? _openRouterKey;
        if (key.isEmpty) return 'OpenRouter API Key غير مُعيّن';
        final response = await _dio.post(
          'https://openrouter.ai/api/v1/chat/completions',
          options: dio_client.Options(headers: {'Authorization': 'Bearer $key'}),
          data: {
            "model": model ?? _openRouterModel,
            "messages": [{"role": "user", "content": "قل 'مرحبا'"}]
          },
        );
        return response.data['choices'][0]['message']['content'];
      }
    } on dio_client.DioException catch (e) {
      final data = e.response?.data;
      String? msg;
      if (data is Map) {
        msg = data['error']?['message']?.toString();
      }
      msg ??= e.message ?? e.toString();
      return 'خطأ: $msg';
    } catch (e) {
      return 'خطأ: $e';
    }
    return null;
  }

  AIGradingResult _parseResponse(String text) {
    try {
      // تنظيف الكتل البرمجية إذا وجدت (مثل ```json ... ```)
      String cleaned = text.trim();
      if (cleaned.startsWith('```')) {
        final lines = cleaned.split('\n');
        if (lines.first.startsWith('```')) {
          lines.removeAt(0);
        }
        if (lines.last.startsWith('```')) {
          lines.removeLast();
        }
        cleaned = lines.join('\n').trim();
      }

      final data = jsonDecode(cleaned);
      final score = double.tryParse(data['score']?.toString() ?? '0') ?? 0;
      final feedback = data['feedback']?.toString() ?? 'تم التقييم بنجاح';

      return AIGradingResult(score: score, feedback: feedback);
    } catch (e) {
      debugPrint('JSON parsing failed, falling back to Regex: $e');
      try {
        final scoreMatch = RegExp(r'"score":\s*([\d.]+)').firstMatch(text) ?? 
                           RegExp(r'الدرجة:\s*([\d.]+)/10').firstMatch(text);
        final feedbackMatch = RegExp(r'"feedback":\s*"(.*?)"', dotAll: true).firstMatch(text) ?? 
                              RegExp(r'التعليق:\s*(.*)', dotAll: true).firstMatch(text);

        final score = double.tryParse(scoreMatch?.group(1) ?? '0') ?? 0;
        final feedback = feedbackMatch?.group(1)?.trim() ?? 'تم التقييم بنجاح';

        return AIGradingResult(score: score, feedback: feedback);
      } catch (innerException) {
        return AIGradingResult.error('فشل في تحليل النتيجة: $text');
      }
    }
  }
}
