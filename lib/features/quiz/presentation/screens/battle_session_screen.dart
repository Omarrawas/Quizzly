import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/domain/services/battle_service.dart';
import 'package:quizzly/features/quiz/domain/services/exam_generator_service.dart';
import 'package:share_plus/share_plus.dart';

class BattleSessionScreen extends StatefulWidget {
  final BattleChallenge battle;

  const BattleSessionScreen({
    super.key,
    required this.battle,
  });

  @override
  State<BattleSessionScreen> createState() => _BattleSessionScreenState();
}

class _BattleSessionScreenState extends State<BattleSessionScreen> {
  final ExamGeneratorService _generatorService = ExamGeneratorService();
  final BattleService _battleService = BattleService();
  
  List<QuizQuestion> _questions = [];
  bool _isLoading = true;
  
  int _currentIndex = 0;
  int _score = 0;
  int _timeTakenSeconds = 0;
  Timer? _timer;
  
  bool _isFinished = false;
  
  late BattleChallenge _currentBattle;
  StreamSubscription<BattleChallenge?>? _battleSubscription;

  @override
  void initState() {
    super.initState();
    _currentBattle = widget.battle;
    if (_currentBattle.status == BattleStatus.waiting) {
      _listenToBattleStatus();
    } else {
      _loadQuestions();
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _battleSubscription?.cancel();
    super.dispose();
  }

  void _listenToBattleStatus() {
    _battleSubscription = _battleService.streamBattle(_currentBattle.id).listen((updatedBattle) {
      if (updatedBattle != null && mounted) {
        setState(() {
          _currentBattle = updatedBattle;
        });
        if (updatedBattle.status == BattleStatus.active) {
          _battleSubscription?.cancel();
          _loadQuestions();
          _startTimer();
        }
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isFinished) {
        setState(() {
          _timeTakenSeconds++;
        });
      }
    });
  }

  Future<void> _loadQuestions() async {
    try {
      List<String> ids = _currentBattle.questionIds;
      
      // Fallback: if IDs are empty, try to fetch the battle document again
      if (ids.isEmpty) {
        final freshBattle = await _battleService.getBattle(_currentBattle.id);
        if (freshBattle != null && freshBattle.questionIds.isNotEmpty) {
          ids = freshBattle.questionIds;
        }
      }

      if (ids.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final qs = await _generatorService.getQuestionsByIds(ids);
      if (mounted) {
        setState(() {
          _questions = qs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تحميل الأسئلة: $e')),
        );
      }
    }
  }

  void _answerQuestion(String selectedOptionId) {
    if (_isFinished) return;

    final question = _questions[_currentIndex];
    final isCorrect = question.correctOptionIds.contains(selectedOptionId);

    if (isCorrect) {
      HapticFeedback.lightImpact();
      setState(() {
        _score += 10; // 10 points per correct answer
      });
    } else {
      HapticFeedback.heavyImpact();
    }

    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      _finishBattle();
    }
  }

  Future<void> _finishBattle() async {
    setState(() {
      _isFinished = true;
    });
    _timer?.cancel();

    final userId = context.read<AuthService>().user?.uid;
    if (userId != null) {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      try {
        await _battleService.submitScore(
          battleId: _currentBattle.id,
          userId: userId,
          score: _score,
          timeTakenSeconds: _timeTakenSeconds,
        );
        if (!mounted) return;
        Navigator.pop(context); // close loader
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء حفظ النتيجة')));
      }
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_currentBattle.status == BattleStatus.waiting) {
      return _buildWaitingScreen(isDark);
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        body: const Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('المعركة')),
        body: const Center(child: Text('عذراً، لا توجد أسئلة لهذه المعركة.')),
      );
    }

    if (_isFinished) {
      return _buildResultScreen();
    }

    final question = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF0F172A).withValues(alpha: 0.05), 
                borderRadius: BorderRadius.circular(20)
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_timeTakenSeconds), 
                    style: GoogleFonts.inter(
                      color: isDark ? Colors.white : AppColors.textPrimary, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                ],
              ),
            ),
            Text(
              'سؤال ${_currentIndex + 1}/${_questions.length}', 
              style: GoogleFonts.cairo(
                color: isDark ? Colors.white : AppColors.textPrimary, 
                fontSize: 16,
                fontWeight: FontWeight.bold
              )
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF0F172A).withValues(alpha: 0.05), 
                borderRadius: BorderRadius.circular(20)
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '$_score', 
                    style: GoogleFonts.inter(
                      color: isDark ? Colors.white : AppColors.textPrimary, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child: SingleChildScrollView(
                          child: Text(
                            question.text,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 22, 
                              fontWeight: FontWeight.bold, 
                              color: isDark ? Colors.white : AppColors.textPrimary, 
                              height: 1.6
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (question.options != null)
                    ...question.options!.map((opt) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _answerQuestion(opt.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                                foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.borderLight),
                                ),
                                alignment: Alignment.centerRight,
                                elevation: isDark ? 0 : 2,
                                shadowColor: Colors.black.withValues(alpha: 0.05),
                              ),
                              child: Text(
                                opt.text,
                                style: GoogleFonts.cairo(fontSize: 16),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ),
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  final GlobalKey _boundaryKey = GlobalKey();

  Future<void> _shareResultImage() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.amber)),
      );

      // Give frame a brief moment to fully render
      await Future.delayed(const Duration(milliseconds: 150));

      RenderRepaintBoundary? boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('تعذر تحديد منطقة التقاط الصورة.');
      }
      
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('تعذر استخراج بيانات الصورة.');
      }
      
      Uint8List pngBytes = byteData.buffer.asUint8List();
      
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/quizzly_match_result.png').create();
      await file.writeAsBytes(pngBytes);
      
      if (mounted) {
        navigator.pop(); // Close loader
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'لقد خضت معركة حماسية في تطبيق Quizzly! 🔥🚀',
        ),
      );
    } catch (e) {
      if (mounted) {
        navigator.pop(); // Close loader
      }
      messenger.showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء مشاركة النتيجة: $e')),
      );
    }
  }

  Widget _buildResultScreen() {
    return StreamBuilder<BattleChallenge?>(
      stream: _battleService.streamBattle(_currentBattle.id),
      builder: (context, snapshot) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC), 
            body: const Center(child: CircularProgressIndicator(color: Colors.amber))
          );
        }
        
        final updatedBattle = snapshot.data;
        if (updatedBattle == null) return const Scaffold(body: Center(child: Text('خطأ في تحميل النتيجة')));

        final userId = context.read<AuthService>().user?.uid;
        final myScore = updatedBattle.scores[userId] ?? _score;
        final myTime = updatedBattle.timeTaken[userId] ?? _timeTakenSeconds;
        
        final bool isChallenger = updatedBattle.challengerId == userId;
        final myName = isChallenger ? updatedBattle.challengerName : (updatedBattle.opponentName ?? 'أنت');
        final oppName = isChallenger ? (updatedBattle.opponentName ?? 'بانتظار المنافس') : updatedBattle.challengerName;
        
        final opponentId = isChallenger ? updatedBattle.opponentId : updatedBattle.challengerId;
        final opponentScore = opponentId != null ? updatedBattle.scores[opponentId] : null;
        final opponentTime = opponentId != null ? updatedBattle.timeTaken[opponentId] : null;

        final bool isWaiting = opponentScore == null;
        
        String resultText = 'بانتظار المنافس...';
        Color resultColor = Colors.amber;
        
        if (opponentScore != null) {
          if (myScore > opponentScore) {
            resultText = 'أنت الفائز! 🏆';
            resultColor = Colors.greenAccent;
          } else if (myScore < opponentScore) {
            resultText = 'خسرت المعركة 😢';
            resultColor = Colors.redAccent;
          } else {
            // Tie breaker: time
            if (myTime < (opponentTime ?? 9999)) {
              resultText = 'أنت الفائز (أسرع)! ⚡';
              resultColor = Colors.greenAccent;
            } else if (myTime > (opponentTime ?? 0)) {
              resultText = 'خسرت (أبطأ)! 🐢';
              resultColor = Colors.redAccent;
            } else {
              resultText = 'تعادل! 🤝';
              resultColor = Colors.blueAccent;
            }
          }
        }

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RepaintBoundary(
                    key: _boundaryKey,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.school_rounded, color: AppColors.primaryBlue, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'Quizzly Match',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Icon(
                            isWaiting ? Icons.hourglass_top_rounded : (resultColor == Colors.greenAccent ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded),
                            size: 80,
                            color: resultColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            resultText,
                            style: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.bold, color: resultColor),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: _buildScoreCard(myName, myScore, myTime, true),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildScoreCard(oppName, opponentScore, opponentTime, false),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context), // back to hub
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                          foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text('خروج', style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _shareResultImage,
                        icon: const Icon(Icons.share_rounded, size: 20),
                        label: Text('مشاركة النتيجة', style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScoreCard(String name, int? score, int? time, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String scoreStr = '-';
    if (score != null && _questions.isNotEmpty) {
      final pct = ((score / _questions.length) * 100).round();
      scoreStr = '$pct%';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isMe 
            ? AppColors.primaryBlue.withValues(alpha: isDark ? 0.2 : 0.1) 
            : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMe 
              ? AppColors.primaryBlue.withValues(alpha: 0.5) 
              : (isDark ? Colors.white12 : AppColors.borderLight)
        ),
      ),
      child: Column(
        children: [
          Text(
            name, 
            style: GoogleFonts.cairo(
              color: isDark ? Colors.white70 : AppColors.textSecondary, 
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Text(
            scoreStr,
            style: GoogleFonts.inter(
              color: isDark ? Colors.white : AppColors.textPrimary, 
              fontSize: 28, 
              fontWeight: FontWeight.bold
            ),
          ),
          Text(
            'نسبة النجاح', 
            style: GoogleFonts.cairo(
              color: isDark ? Colors.white30 : AppColors.textSecondary.withValues(alpha: 0.5), 
              fontSize: 11
            )
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer_outlined, 
                color: isDark ? Colors.white30 : AppColors.textSecondary.withValues(alpha: 0.5), 
                size: 14
              ),
              const SizedBox(width: 4),
              Text(
                time != null ? _formatTime(time) : '--:--',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white54 : AppColors.textSecondary, 
                  fontSize: 12
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingScreen(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'بانتظار المعركة',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.flash_on_rounded,
                    color: Colors.amber,
                    size: 60,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'بانتظار انضمام المنافس...',
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'لن تبدأ المعركة حتى يقوم الطرف الآخر بالدخول.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 48),
              Text(
                'كود المعركة الخاص بك:',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white38 : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectableText(
                      _currentBattle.id,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: AppColors.primaryBlue),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _currentBattle.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ كود التحدي!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(color: Colors.amber),
            ],
          ),
        ),
      ),
    );
  }
}
