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
  final dio_client.Dio _dio = dio_client.Dio();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // الإعدادات الافتراضية (سيتم تجاوزها من Firestore إذا وجدت)
  String _geminiKey = '';
  String _groqKey = '';
  String _openRouterKey = '';
  String _openRouterModel = 'google/gemini-2.0-flash-exp:free';
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
        _openRouterModel = data['openRouterModel'] ?? 'google/gemini-2.0-flash-exp:free';
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
      }]
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
        "messages": [
          {"role": "system", "content": "أنت مصحح أكاديمي خبير باللغة العربية."},
          {"role": "user", "content": prompt}
        ]
      },
    );

    return response.data['choices'][0]['message']['content'];
  }

  String _buildPrompt(String q, String ans, String modelAns, String? exp) {
    return '''
قم بتقييم إجابة الطالب الأكاديمية:
السؤال: "$q"
الإجابة النموذجية: "$modelAns"
توضيح: "${exp ?? ''}"
إجابة الطالب: "$ans"

المطلوب بدقة:
الدرجة: [الرقم]/10
التعليق: [نص التعليق بالعربية]
''';
  }

  /// اختبار اتصال مزود محدد
  Future<String?> testProvider({
    required AIProvider provider,
    String? model,
  }) async {
    await _initialize();

    try {
      if (provider == AIProvider.gemini) {
        if (_geminiKey.isEmpty) return 'Gemini API Key غير مُعيّن';
        final url = '$_cloudflareProxyUrl/v1beta/models/gemini-2.0-flash:generateContent?key=$_geminiKey';
        final response = await _dio.post(url, data: {
          "contents": [{"parts": [{"text": "قل 'مرحبا'"}]}]
        });
        return response.data['candidates'][0]['content']['parts'][0]['text'];
      } else if (provider == AIProvider.groq) {
        if (_groqKey.isEmpty) return 'Groq API Key غير مُعيّن';
        final response = await _dio.post(
          'https://api.groq.com/openai/v1/chat/completions',
          options: dio_client.Options(headers: {'Authorization': 'Bearer $_groqKey'}),
          data: {
            "model": model ?? 'llama3-8b-8192',
            "messages": [{"role": "user", "content": "قل 'مرحبا'"}]
          },
        );
        return response.data['choices'][0]['message']['content'];
      } else if (provider == AIProvider.openRouter) {
        if (_openRouterKey.isEmpty) return 'OpenRouter API Key غير مُعيّن';
        final response = await _dio.post(
          'https://openrouter.ai/api/v1/chat/completions',
          options: dio_client.Options(headers: {'Authorization': 'Bearer $_openRouterKey'}),
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
      final scoreMatch = RegExp(r'الدرجة:\s*([\d.]+)/10').firstMatch(text);
      final feedbackMatch = RegExp(r'التعليق:\s*(.*)', dotAll: true).firstMatch(text);

      final score = double.tryParse(scoreMatch?.group(1) ?? '0') ?? 0;
      final feedback = feedbackMatch?.group(1)?.trim() ?? 'تم التقييم بنجاح';

      return AIGradingResult(score: score, feedback: feedback);
    } catch (e) {
      return AIGradingResult.error('فشل في تحليل النتيجة: $text');
    }
  }
}
