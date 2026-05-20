import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quizzly/core/theme/app_theme.dart';
import 'package:quizzly/core/theme/theme_service.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/firebase_options.dart';
import 'package:quizzly/features/home/domain/services/college_service.dart';
import 'package:quizzly/features/home/domain/services/content_service.dart';
import 'package:quizzly/features/auth/presentation/screens/splash_screen.dart';
import 'package:quizzly/features/auth/presentation/screens/login_screen.dart';
import 'package:quizzly/features/home/presentation/screens/home_screen.dart';
import 'package:quizzly/features/quiz/domain/services/smart_notification_service.dart';
import 'package:quizzly/features/quiz/domain/services/list_service.dart';
import 'package:quizzly/features/settings/domain/services/settings_service.dart';
import 'package:quizzly/core/services/app_update_service.dart';
import 'package:flutter/foundation.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();

  // Initialize Smart Notifications in background
  SmartNotificationService().init().catchError((e) {
    debugPrint('Smart Notification initialization failed: $e');
  });

  // Enable 100% offline persistence to store data, results, and queue writes automatically (Android/iOS only).
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // Initialize App Update Service in background
  AppUpdateService().initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeService(prefs)),
        ChangeNotifierProvider(create: (_) => SettingsService(prefs)),
        Provider(create: (_) => CollegeService()),
        Provider(create: (_) => ContentService()),
        Provider(create: (_) => ListService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'Quizzly',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: scaffoldMessengerKey,
          navigatorKey: navigatorKey,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.themeMode,
          // Proper Arabic RTL Support
          locale: const Locale('ar'),
          supportedLocales: const [
            Locale('ar'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: '/splash',
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const HomeScreen(),
          },
        );
      },
    );
  }
}
