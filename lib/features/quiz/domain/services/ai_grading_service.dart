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

enum AIProvider { gemini, bynara, groq, openRouter }

class AIGradingService {
  // Singleton pattern implementation
  static final AIGradingService _instance = AIGradingService._internal();

  factory AIGradingService() {
    return _instance;
  }

  AIGradingService._internal();

  final dio_client.Dio _dio = dio_client.Dio(
    dio_client.BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // الإعدادات الافتراضية (سيتم تجاوزها من Firestore إذا وجدت)
  String _geminiKey = '';
  String _bynaraKey = '';
  String _groqKey = '';
  String _openRouterKey = '';
  String _openRouterModel = 'nvidia/nemotron-3-ultra-550b-a55b:free';
  String _geminiModel = 'gemini-3.5-flash';
  String _bynaraModel = 'auto/bynara';

  bool _isInitialized = false;

  String _getApiUrl(AIProvider provider) {
    if (kIsWeb) {
      if (Uri.base.host == 'localhost') {
        switch (provider) {
          case AIProvider.gemini:
            return 'https://generativelanguage.googleapis.com';
          case AIProvider.bynara:
            return 'https://router.bynara.id';
          case AIProvider.groq:
            return 'https://api.groq.com';
          case AIProvider.openRouter:
            return 'https://openrouter.ai';
        }
      } else {
        switch (provider) {
          case AIProvider.gemini:
            return 'https://generativelanguage.googleapis.com';
          case AIProvider.bynara:
            return '/api/bynara';
          case AIProvider.groq:
            return '/api/groq';
          case AIProvider.openRouter:
            return '/api/openrouter';
        }
      }
    } else {
      switch (provider) {
        case AIProvider.gemini:
          return 'https://generativelanguage.googleapis.com';
        case AIProvider.bynara:
          return 'https://router.bynara.id';
        case AIProvider.groq:
          return 'https://api.groq.com';
        case AIProvider.openRouter:
          return 'https://openrouter.ai';
      }
    }
  }

  /// تحميل الإعدادات من Firestore
  Future<void> _initialize() async {
    if (_isInitialized) return;
    try {
      final doc = await _firestore.collection('settings').doc('ai_config').get();
      if (doc.exists) {
        final data = doc.data()!;
        _geminiKey = data['geminiKey'] ?? '';
        _geminiModel = data['geminiModel'] ?? 'gemini-3.5-flash';
        _bynaraKey = data['bynaraKey'] ?? '';
        _bynaraModel = data['bynaraModel'] ?? 'auto/bynara';
        _groqKey = data['groqKey'] ?? '';
        _openRouterKey = data['openRouterKey'] ?? '';
        _openRouterModel = data['openRouterModel'] ?? 'nvidia/nemotron-3-ultra-550b-a55b:free';
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
    if (_geminiKey.isEmpty && _bynaraKey.isEmpty && _groqKey.isEmpty && _openRouterKey.isEmpty) {
      return AIGradingResult.error('لم يتم ضبط مفاتيح الذكاء الاصطناعي في لوحة التحكم.');
    }

    AIProvider provider;
    if (retryCount == 0) {
      provider = AIProvider.gemini;
    } else if (retryCount == 1) {
      provider = AIProvider.bynara;
    } else if (retryCount == 2) {
      provider = AIProvider.groq;
    } else if (retryCount == 3) {
      provider = AIProvider.openRouter;
    } else {
      return AIGradingResult.error('فشلت جميع المحاولات. يرجى التأكد من الاتصال بالإنترنت.');
    }

    // تخطي المزود إذا كان مفتاحه فارغاً
    if ((provider == AIProvider.gemini && _geminiKey.isEmpty) ||
        (provider == AIProvider.bynara && _bynaraKey.isEmpty) ||
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
      } else if (provider == AIProvider.bynara) {
        responseText = await _callOpenAICompatible(
          url: '${_getApiUrl(AIProvider.bynara)}/v1/chat/completions',
          key: _bynaraKey,
          model: _bynaraModel,
          question: question,
          studentAnswer: studentAnswer,
          modelAnswer: modelAnswer,
        );
      } else if (provider == AIProvider.groq) {
        responseText = await _callOpenAICompatible(
          url: '${_getApiUrl(AIProvider.groq)}/openai/v1/chat/completions',
          key: _groqKey,
          model: 'llama-3.1-8b-instant',
          question: question,
          studentAnswer: studentAnswer,
          modelAnswer: modelAnswer,
        );
      } else if (provider == AIProvider.openRouter) {
        responseText = await _callOpenAICompatible(
          url: '${_getApiUrl(AIProvider.openRouter)}/api/v1/chat/completions',
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
    final url = 'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_geminiKey';
    
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
        final resolvedModel = model ?? _geminiModel;
        final url = 'https://generativelanguage.googleapis.com/v1beta/models/$resolvedModel:generateContent?key=$key';
        final response = await _dio.post(url, data: {
          "contents": [{"parts": [{"text": "قل 'مرحبا'"}]}]
        });
        return response.data['candidates'][0]['content']['parts'][0]['text'];
      } else if (provider == AIProvider.bynara) {
        final key = apiKey?.trim() ?? _bynaraKey;
        if (key.isEmpty) return 'Bynara API Key غير مُعيّن';
        final response = await _dio.post(
          '${_getApiUrl(AIProvider.bynara)}/v1/chat/completions',
          options: dio_client.Options(headers: {'Authorization': 'Bearer $key'}),
          data: {
            "model": model ?? _bynaraModel,
            "messages": [{"role": "user", "content": "قل 'مرحبا'"}]
          },
        );
        return response.data['choices'][0]['message']['content'];
      } else if (provider == AIProvider.groq) {
        final key = apiKey?.trim() ?? _groqKey;
        if (key.isEmpty) return 'Groq API Key غير مُعيّن';
        final response = await _dio.post(
          '${_getApiUrl(AIProvider.groq)}/openai/v1/chat/completions',
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
          '${_getApiUrl(AIProvider.openRouter)}/api/v1/chat/completions',
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
      if (kIsWeb && (msg.contains('XMLHttpRequest') || msg.toLowerCase().contains('network error') || msg.toLowerCase().contains('failed to fetch') || e.type == dio_client.DioExceptionType.connectionError)) {
        return 'CORS Error: لا يمكن الاتصال بالخادم من المتصفح مباشرة بسبب سياسة أمان الويب. لتجاوز هذا في التطوير المحلي، يرجى تشغيل المتصفح بدون حماية: \n\nflutter run -d chrome --web-browser-flag "--disable-web-security"';
      }
      return 'خطأ: $msg';
    } catch (e) {
      if (kIsWeb && e.toString().contains('XMLHttpRequest')) {
        return 'CORS Error: لا يمكن الاتصال بالخادم من المتصفح مباشرة بسبب سياسة أمان الويب. لتجاوز هذا في التطوير المحلي، يرجى تشغيل المتصفح بدون حماية: \n\nflutter run -d chrome --web-browser-flag "--disable-web-security"';
      }
      return 'خطأ: $e';
    }
    return null;
  }

  AIGradingResult _parseResponse(String text) {
    try {
      String cleaned = text.trim();
      
      // Extract JSON block robustly by finding outer-most braces
      int firstBrace = cleaned.indexOf('{');
      int lastBrace = cleaned.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
        cleaned = cleaned.substring(firstBrace, lastBrace + 1);
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
