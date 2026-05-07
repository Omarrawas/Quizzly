import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/domain/services/spaced_repetition_service.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';

class CramModeSessionScreen extends StatefulWidget {
  final List<QuizQuestion> questions;
  final String subjectId;

  const CramModeSessionScreen({
    super.key,
    required this.questions,
    required this.subjectId,
  });

  @override
  State<CramModeSessionScreen> createState() => _CramModeSessionScreenState();
}

class _CramModeSessionScreenState extends State<CramModeSessionScreen> {
  int _currentIndex = 0;
  bool _isAnswerVisible = false;
  String? _currentMnemonic;
  bool _isLoadingMnemonic = false;
  final SpacedRepetitionService _srsService = SpacedRepetitionService();

  @override
  void initState() {
    super.initState();
    _loadMnemonic();
  }

  Future<void> _loadMnemonic() async {
    final userId = context.read<AuthService>().user?.uid;
    if (userId == null) return;

    setState(() => _isLoadingMnemonic = true);
    final mastery = await _srsService.getQuestionMastery(
      userId,
      widget.questions[_currentIndex].id!,
    );
    if (mounted) {
      setState(() {
        _currentMnemonic = mastery?.mnemonic;
        _isLoadingMnemonic = false;
      });
    }
  }

  void _revealAnswer() {
    setState(() => _isAnswerVisible = true);
    HapticFeedback.mediumImpact();
  }

  void _submitRecall(bool success) async {
    final userId = context.read<AuthService>().user?.uid;
    final question = widget.questions[_currentIndex];

    if (userId != null) {
      // Update mastery: 5 for success, 1 for failure in cram mode
      _srsService.updateMastery(
        userId: userId,
        questionId: question.id!,
        subjectId: widget.subjectId,
        quality: success ? 5 : 1,
      );
    }

    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _isAnswerVisible = false;
      });
      _loadMnemonic();
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أنهيت جلسة المراجعة المكثفة بنجاح!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_currentIndex];
    final progress = (_currentIndex + 1) / widget.questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate for focus
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'مراجعة مكثفة',
          style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildCramCard(question),
            ),
          ),
          const SizedBox(height: 32),
          _buildControls(),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildCramCard(QuizQuestion q) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            q.text,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.6,
            ),
          ),
          if (_isAnswerVisible) ...[
            const SizedBox(height: 32),
            Container(
              height: 2,
              width: 80,
              color: Colors.amber.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 32),
            Text(
              q.options?.firstWhere((o) => q.correctOptionIds.contains(o.id)).text ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
          ],
          const Spacer(),
          _buildMnemonicSection(),
        ],
      ),
    );
  }

  Widget _buildMnemonicSection() {
    if (_isLoadingMnemonic) {
      return const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2));
    }

    return GestureDetector(
      onTap: _showMnemonicDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.psychology_outlined, color: Colors.amber, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _currentMnemonic ?? 'أضف رابط ذهني للحفظ...',
                style: GoogleFonts.cairo(
                  color: _currentMnemonic != null ? Colors.white70 : Colors.white30,
                  fontSize: 12,
                  fontStyle: _currentMnemonic != null ? FontStyle.normal : FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_currentMnemonic != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.edit_rounded, color: Colors.white30, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  void _showMnemonicDialog() {
    final controller = TextEditingController(text: _currentMnemonic);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'رابط ذهني للحفظ',
          style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          style: GoogleFonts.cairo(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'اكتب جملة أو كلمة تساعدك على التذكر...',
            hintStyle: GoogleFonts.cairo(color: Colors.white30),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.2),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.white30)),
          ),
          ElevatedButton(
            onPressed: () async {
              final userId = context.read<AuthService>().user?.uid;
              if (userId != null) {
                await _srsService.updateMnemonic(
                  userId,
                  widget.questions[_currentIndex].id!,
                  widget.subjectId,
                  controller.text,
                );
                setState(() => _currentMnemonic = controller.text);
              }
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: Text('حفظ', style: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    if (!_isAnswerVisible) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton(
            onPressed: _revealAnswer,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(
              'كشف الإجابة',
              style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _buildRecallButton(
              label: 'أحتاج مراجعة',
              icon: Icons.refresh_rounded,
              color: Colors.redAccent,
              onTap: () => _submitRecall(false),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildRecallButton(
              label: 'أعرفها جيداً',
              icon: Icons.check_circle_outline_rounded,
              color: Colors.greenAccent,
              onTap: () => _submitRecall(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecallButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
