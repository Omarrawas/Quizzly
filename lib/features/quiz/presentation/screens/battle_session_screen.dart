import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/domain/services/battle_service.dart';
import 'package:quizzly/features/quiz/domain/services/exam_generator_service.dart';

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
  
  @override
  void initState() {
    super.initState();
    _loadQuestions();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
      List<String> ids = widget.battle.questionIds;
      
      // Fallback: if IDs are empty, try to fetch the battle document again
      if (ids.isEmpty) {
        final freshBattle = await _battleService.getBattle(widget.battle.id);
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
          battleId: widget.battle.id,
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

  Widget _buildResultScreen() {
    return StreamBuilder<BattleChallenge?>(
      stream: _battleService.streamBattle(widget.battle.id),
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
        
        final opponentId = updatedBattle.challengerId == userId ? updatedBattle.opponentId : updatedBattle.challengerId;
        final opponentName = updatedBattle.challengerId == userId ? updatedBattle.opponentName : updatedBattle.challengerName;
        
        final opponentScore = updatedBattle.scores[opponentId];
        final opponentTime = updatedBattle.timeTaken[opponentId];

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
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isWaiting ? Icons.hourglass_top_rounded : (resultColor == Colors.greenAccent ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded),
                    size: 80,
                    color: resultColor,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    resultText,
                    style: GoogleFonts.cairo(fontSize: 28, fontWeight: FontWeight.bold, color: resultColor),
                  ),
                  const SizedBox(height: 48),
                  
                  // Score cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildScoreCard('أنت', myScore, myTime, true),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildScoreCard(opponentName ?? 'المنافس', opponentScore, opponentTime, false),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 64),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context), // back to hub
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : AppColors.primaryBlue,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('خروج', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
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
              fontSize: 16
            )
          ),
          const SizedBox(height: 12),
          Text(
            score != null ? '$score' : '-',
            style: GoogleFonts.inter(
              color: isDark ? Colors.white : AppColors.textPrimary, 
              fontSize: 32, 
              fontWeight: FontWeight.bold
            ),
          ),
          Text(
            'نقطة', 
            style: GoogleFonts.cairo(
              color: isDark ? Colors.white30 : AppColors.textSecondary.withValues(alpha: 0.5), 
              fontSize: 12
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
}
