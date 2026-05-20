import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;

class SmartNotificationService {
  static final SmartNotificationService _instance = SmartNotificationService._internal();
  factory SmartNotificationService() => _instance;
  SmartNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_data.initializeTimeZones();
    
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationClick(response);
      },
    );

    // Request permissions for Android (13+) and iOS
    if (!kIsWeb) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();

      final IOSFlutterLocalNotificationsPlugin? iosImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Schedules a "Flash Quiz" notification
  Future<void> scheduleFlashQuiz({
    required int id,
    required String question,
    required List<String> options,
    required int correctIndex,
  }) async {
    final List<AndroidNotificationAction> actions = options.asMap().entries.map((entry) {
      return AndroidNotificationAction(
        'action_${entry.key}',
        entry.value,
        showsUserInterface: true,
      );
    }).toList();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'flash_quiz_channel',
      'Flash Quizzes',
      channelDescription: 'Quick interactive quizzes',
      importance: Importance.max,
      priority: Priority.high,
    );

    final NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        androidDetails.channelId,
        androidDetails.channelName,
        channelDescription: androidDetails.channelDescription,
        importance: androidDetails.importance,
        priority: androidDetails.priority,
        actions: actions,
      ),
    );

    await _notificationsPlugin.show(
      id,
      '⚡ اختبار سريع!',
      question,
      details,
      payload: 'correct_$correctIndex',
    );
  }

  /// Shows a standard plain notification without quiz actions
  Future<void> showPlainNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'general_notifications_channel',
      'General Notifications',
      channelDescription: 'Important updates and announcements',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      details,
    );
  }

  void _handleNotificationClick(NotificationResponse response) {
    if (response.actionId != null) {
      final parts = response.actionId!.split('_');
      if (parts.length < 2) return;
      
      final selectedIndex = int.parse(parts.last);
      final payload = response.payload;
      
      if (payload != null && payload.startsWith('correct_')) {
        final correctIndex = int.parse(payload.split('_').last);
        
        if (selectedIndex == correctIndex) {
          debugPrint('✅ Correct Answer from Notification!');
        } else {
          debugPrint('❌ Wrong Answer from Notification!');
        }
      }
    }
  }

  Future<void> sendSampleFlashQuiz() async {
    await scheduleFlashQuiz(
      id: 100,
      question: 'ما هو رمز الصوديوم في الجدول الدوري؟',
      options: ['S', 'Na', 'Cl', 'Mg'],
      correctIndex: 1,
    );
  }
}
