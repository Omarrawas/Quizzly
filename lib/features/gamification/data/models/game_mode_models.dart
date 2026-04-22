import 'package:cloud_firestore/cloud_firestore.dart';

enum GameModeType { quickQuiz, survival, timeAttack }

class GameModeConfig {
  final String id;
  final String name;
  final GameModeType type;
  final bool isActive;
  final Map<String, dynamic> config;

  const GameModeConfig({
    required this.id,
    required this.name,
    required this.type,
    this.isActive = true,
    required this.config,
  });

  factory GameModeConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    GameModeType parseType(String? t) {
      switch (t) {
        case 'survival': return GameModeType.survival;
        case 'time_attack': return GameModeType.timeAttack;
        case 'quick_quiz':
        default: return GameModeType.quickQuiz;
      }
    }

    return GameModeConfig(
      id: doc.id,
      name: data['name'] ?? 'نمط غير معروف',
      type: parseType(data['type']),
      isActive: data['isActive'] ?? false,
      config: data['config'] ?? {},
    );
  }
}

/// Base class for handling runtime game logic
abstract class GameModeController {
  final GameModeConfig config;
  
  GameModeController(this.config);

  /// Called when an answer is submitted to update mode-specific state (like time or lives)
  /// Returns false if the game is over.
  bool processAnswer(bool isCorrect, int timeSpentSeconds);
  
  /// Get current state description (e.g. "Lives: 2", "Time: 45s")
  String get statusDisplay;
}

class SurvivalModeController extends GameModeController {
  int lives;
  
  SurvivalModeController(super.config) : lives = config.config['maxLives'] ?? 3;

  @override
  bool processAnswer(bool isCorrect, int timeSpentSeconds) {
    if (!isCorrect) {
      lives--;
    }
    return lives > 0;
  }

  @override
  String get statusDisplay => '❤️ $lives';
}

class TimeAttackController extends GameModeController {
  late int timeLeft;
  final int bonusPerCorrect;
  final int penaltyPerWrong;

  TimeAttackController(super.config) 
      : bonusPerCorrect = config.config['bonusPerCorrect'] ?? 5,
        penaltyPerWrong = config.config['penaltyPerWrong'] ?? -3 {
    timeLeft = config.config['startingTime'] ?? 60;
  }

  /// Needs to be called periodically (every second) by the UI timer.
  /// Returns false if time is up.
  bool tick() {
    timeLeft--;
    return timeLeft > 0;
  }

  @override
  bool processAnswer(bool isCorrect, int timeSpentSeconds) {
    if (isCorrect) {
      timeLeft += bonusPerCorrect;
    } else {
      timeLeft += penaltyPerWrong; // usually a negative value
    }
    return timeLeft > 0;
  }

  @override
  String get statusDisplay => '⏱️ ${timeLeft}s';
}
