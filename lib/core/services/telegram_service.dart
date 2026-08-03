import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class TelegramService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Default Bot Username (Fallback)
  static const String defaultBotUsername = 'QuizzlySuportBot';

  /// Returns the Telegram deep link to launch the support bot for a specific user ID.
  /// Example: https://t.me/QuizzlySuportBot?start=USER_85746
  static Future<String> getBotDeepLink(String userId) async {
    String botUsername = defaultBotUsername;
    try {
      final doc = await _db.collection('settings').doc('socials').get();
      if (doc.exists && doc.data()?['supportBotUrl'] != null) {
        final url = doc.data()!['supportBotUrl'] as String;
        final uri = Uri.tryParse(url);
        if (uri != null && uri.pathSegments.isNotEmpty) {
          botUsername = uri.pathSegments.last.replaceAll('@', '');
        }
      }
    } catch (e) {
      debugPrint('TelegramService: error fetching bot username: $e');
    }
    return 'https://t.me/$botUsername?start=$userId';
  }

  /// Get Telegram Bot Token from Firestore settings
  static Future<String> _getBotToken() async {
    try {
      final doc = await _db.collection('settings').doc('socials').get();
      if (doc.exists && doc.data()?['telegramBotToken'] != null) {
        final token = doc.data()!['telegramBotToken'] as String;
        if (token.isNotEmpty) return token;
      }
    } catch (e) {
      debugPrint('TelegramService: error getting bot token: $e');
    }
    return ''; // Set or configured token in dashboard
  }

  /// Send a direct message to a Telegram Chat ID via Telegram Bot API
  static Future<bool> sendDirectMessage({
    required String chatId,
    required String text,
  }) async {
    final botToken = await _getBotToken();
    if (botToken.isEmpty) {
      debugPrint('TelegramService Warning: Bot token is not configured in settings/socials');
      return false;
    }

    try {
      final url = Uri.parse('https://api.telegram.org/bot$botToken/sendMessage');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text': text,
          'parse_mode': 'Markdown',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['ok'] == true;
      } else {
        debugPrint('TelegramService Send Error (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('TelegramService HTTP Exception: $e');
      return false;
    }
  }

  /// Send a notification to a specific user by Quizzly UserId if their Telegram account is linked
  static Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String message,
  }) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data();
      final telegramChatId = userData?['telegramChatId'] as String?;

      if (telegramChatId == null || telegramChatId.isEmpty) {
        debugPrint('TelegramService: User $userId does not have a linked Telegram Chat ID.');
        return false;
      }

      final formattedText = "🔔 *$title*\n\n$message";
      return await sendDirectMessage(chatId: telegramChatId, text: formattedText);
    } catch (e) {
      debugPrint('TelegramService Notification Error: $e');
      return false;
    }
  }

  // ── Phase 9: Automated System Notification Handlers ──────────────────

  /// 1. Subscription Expiration Notification (انتهاء الاشتراك)
  static Future<bool> notifySubscriptionExpired(String userId) async {
    return sendNotificationToUser(
      userId: userId,
      title: 'تنبيه انتهاء الاشتراك ⚠️',
      message: 'عزيزي الطالب، لقد انتهت مدة اشتراكك في المادة. لتجديد الاشتراك ومتابعة دروسك واختباراتك يرجى شحن حسابك أو تفعيل كود جديد.',
    );
  }

  /// 2. Activation Request Approval (قبول طلب التفعيل)
  static Future<bool> notifyActivationApproved(String userId, String details) async {
    return sendNotificationToUser(
      userId: userId,
      title: 'تم قبول طلب التفعيل 🎉',
      message: 'تهانينا! تم تفعيل الاشتراك بنجاح.\n\nتفاصيل: $details\nنتمنى لك رحلة دراسية ممتعة ومكللة بالنجاح 🎓',
    );
  }

  /// 3. Payment Rejection Notification (رفض عملية الدفع)
  static Future<bool> notifyPaymentRejected(String userId, String reason) async {
    return sendNotificationToUser(
      userId: userId,
      title: 'تنبيه حول عملية الشحن ❌',
      message: 'نعتذر، تعذر قبول عملية شحن الرصيد / التفعيل.\nالسبب: $reason\nإذا كنت تعتقد أن هذا خطأ، يرجى مراسلتنا هنا عبر البوت.',
    );
  }

  /// 4. New Lesson Added Notification (إضافة درس جديد)
  static Future<bool> notifyNewLesson(String userId, String lessonTitle, String subjectName) async {
    return sendNotificationToUser(
      userId: userId,
      title: 'درس جديد متوفر الآن 📚',
      message: 'تمت إضافة درس جديد: *$lessonTitle*\nالمادة: *$subjectName*\nيمكنك الدخول الآن لمشاهدة المضمون وممارسة الأسئلة.',
    );
  }

  /// 5. Exam Results Notification (نتائج الاختبارات)
  static Future<bool> notifyExamResult(String userId, String examTitle, String resultText) async {
    return sendNotificationToUser(
      userId: userId,
      title: 'نتيجة اختبار جديدة 📊',
      message: 'تم إعلان نتيجة الاختبار: *$examTitle*\nالنتيجة: *$resultText*\nأحسنت الاستمرار! واصل التفوق 🌟',
    );
  }

  /// 6. Broadcast Announcement Notification (الإعلانات المهمة)
  static Future<bool> notifyBroadcastAnnouncement(String title, String body) async {
    try {
      final usersSnap = await _db.collection('users').where('telegramChatId', isNotEqualTo: null).get();
      int successCount = 0;
      for (var doc in usersSnap.docs) {
        final chatId = doc.data()['telegramChatId'] as String?;
        if (chatId != null && chatId.isNotEmpty) {
          final sent = await sendDirectMessage(
            chatId: chatId,
            text: "📢 *إعلان مهم: $title*\n\n$body",
          );
          if (sent) successCount++;
        }
      }
      debugPrint('TelegramService: Broadcast sent to $successCount users.');
      return successCount > 0;
    } catch (e) {
      debugPrint('TelegramService Broadcast Error: $e');
      return false;
    }
  }
}
