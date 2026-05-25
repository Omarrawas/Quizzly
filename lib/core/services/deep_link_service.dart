import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:quizzly/main.dart';
import 'package:quizzly/features/quiz/presentation/screens/shared_question_screen.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  void initialize() async {
    // Check for initial link when app is closed
    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (e) {
      debugPrint('Error getting initial deep link: $e');
    }

    // Listen for links when app is in foreground or background
    _linkSubscription = appLinks.uriLinkStream.listen((uri) {
      _handleUri(uri);
    }, onError: (err) {
      debugPrint('Deep link stream error: $err');
    });
  }

  void _handleUri(Uri uri) {
    debugPrint('Handling Deep Link: $uri');
    
    // Example: https://quizzly.app/question?id=XYZ&subjectId=ABC
    if (uri.path == '/question' || uri.fragment.contains('/question')) {
      final questionId = uri.queryParameters['id'];
      final subjectId = uri.queryParameters['subjectId'];

      if (questionId != null) {
        _navigateToQuestion(questionId, subjectId);
      }
    }
  }

  void _navigateToQuestion(String questionId, String? subjectId) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SharedQuestionScreen(
          questionId: questionId,
          subjectId: subjectId,
        ),
      ),
    );
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
