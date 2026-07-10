import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/quiz/presentation/screens/practice_session_screen.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';

class PracticeHistoryScreen extends StatelessWidget {
  final String subjectId;
  final String subjectName;

  const PracticeHistoryScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthService>().user?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C14) : const Color(0xFFE5E2DA),
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'الامتحانات السابقة', 
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold, 
                fontSize: 18,
                color: isDark ? Colors.white : AppColors.textPrimary
              )
            ),
            Text(
              subjectName, 
              style: GoogleFonts.cairo(
                fontSize: 12, 
                color: isDark ? Colors.white38 : AppColors.textSecondary
              )
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF080C14) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded, 
            color: isDark ? Colors.white : Colors.black, 
            size: 20
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: userId == null
          ? const Center(child: Text('يرجى تسجيل الدخول'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('practice_sessions')
                  .where('userId', isEqualTo: userId)
                  .where('subjectId', isEqualTo: subjectId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _buildEmptyState(isDark);
                }

                // Sort locally by creation date descending
                final sortedDocs = docs.toList()
                  ..sort((a, b) {
                    final dataA = a.data() as Map<String, dynamic>;
                    final dataB = b.data() as Map<String, dynamic>;
                    final timeA = dataA['createdAt'] is Timestamp ? dataA['createdAt'] as Timestamp : null;
                    final timeB = dataB['createdAt'] is Timestamp ? dataB['createdAt'] as Timestamp : null;
                    if (timeA == null) return 1;
                    if (timeB == null) return -1;
                    return timeB.compareTo(timeA);
                  });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedDocs.length,
                  itemBuilder: (context, index) {
                    final doc = sortedDocs[index];
                    final docId = doc.id;
                    final data = doc.data() as Map<String, dynamic>;
                    
                    return HistorySessionCard(
                      docId: docId,
                      subjectId: subjectId,
                      data: data,
                      isDark: isDark,
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined, 
            size: 80, 
            color: isDark ? Colors.white10 : Colors.grey[300]
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد امتحانات سابقة بعد',
            style: GoogleFonts.cairo(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              color: isDark ? Colors.white : AppColors.textPrimary
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ امتحانك الأول لتجده محفوظاً هنا!',
            style: GoogleFonts.cairo(color: isDark ? Colors.white38 : AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class HistorySessionCard extends StatefulWidget {
  final String docId;
  final String subjectId;
  final Map<String, dynamic> data;
  final bool isDark;

  const HistorySessionCard({
    super.key,
    required this.docId,
    required this.subjectId,
    required this.data,
    required this.isDark,
  });

  @override
  State<HistorySessionCard> createState() => _HistorySessionCardState();
}

class _HistorySessionCardState extends State<HistorySessionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isDark = widget.isDark;
    
    final date = (data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : null)?.toDate() ?? DateTime.now();
    final correct = (data['correctAnswers'] as num?)?.toInt() ?? 0;
    final total = (data['totalQuestions'] as num?)?.toInt() ?? 0;
    final pct = total > 0 ? (correct / total * 100).round() : 0;
    final topicNames = data['topicNames'] as List<dynamic>?;
    
    final mistakes = data['mistakes'] as List<dynamic>? ?? [];
    
    // Parse difficulty
    final difficultyStr = data['difficulty'] as String?;
    Difficulty? difficulty;
    if (difficultyStr != null) {
      difficulty = Difficulty.values.firstWhere(
        (e) => e.name == difficultyStr,
        orElse: () => Difficulty.easy,
      );
    }

    final scoreColor = _getScoreColor(pct);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A26) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Row with Score, Date and Delete
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pct%',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (difficultyStr != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getDifficultyLabel(difficultyStr),
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            color: isDark ? Colors.white60 : Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      intl.DateFormat('yyyy/MM/dd - hh:mm a').format(date),
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                      onPressed: () => _confirmDelete(context),
                      style: IconButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Info (Topics list)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                topicNames != null && topicNames.isNotEmpty
                    ? topicNames.join('، ')
                    : 'جميع المواضيع',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Stats Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildMiniStat(Icons.check_circle_rounded, '$correct', Colors.green),
                const SizedBox(width: 16),
                _buildMiniStat(Icons.cancel_rounded, '${total - correct}', Colors.red),
                const SizedBox(width: 16),
                _buildMiniStat(Icons.help_rounded, '$total', AppColors.primaryBlue),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.white10),

          // Actions Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                // Restart Button
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      final topicIdsList = (data['topicIds'] as List<dynamic>?)?.map((e) => e.toString()).toList();
                      final topicNamesList = (data['topicNames'] as List<dynamic>?)?.map((e) => e.toString()).toList();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PracticeSessionScreen(
                            subjectId: widget.subjectId,
                            topicIds: topicIdsList,
                            topicNames: topicNamesList ?? ['جميع المواضيع'],
                            selectedDifficulty: difficulty,
                            isFree: false,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: Text(
                      'البدء من جديد',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                
                // Show Mistakes dropdown trigger
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _expanded = !_expanded;
                      });
                    },
                    icon: Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 18),
                    label: Text(
                      _expanded ? 'إخفاء الأخطاء' : 'عرض الأخطاء (${mistakes.length})',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orangeAccent,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Mistakes Collapsible Panel
          if (_expanded)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF080C14) : const Color(0xFFE5E2DA),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mistakes.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'لا توجد أخطاء! أحسنت صنعاً 🎉',
                          style: GoogleFonts.cairo(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    Text(
                      'مراجعة الأخطاء في هذا الامتحان:',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : AppColors.textPrimary,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 12),
                    ...mistakes.map((m) {
                      final mData = m as Map<String, dynamic>;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131A26) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Question text
                            Text(
                              mData['questionText'] ?? '',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.textPrimary,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                            const SizedBox(height: 8),
                            // Correct Option
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'الإجابة الصحيحة: ${mData['correctOption']}',
                                      style: GoogleFonts.cairo(
                                        fontSize: 12,
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Explanation
                            if (mData['explanation'] != null && (mData['explanation'] as String).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'الشرح: ${mData['explanation']}',
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : AppColors.textSecondary,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF131A26) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'حذف الامتحان',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          textAlign: TextAlign.right,
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف هذا الامتحان بشكل نهائي؟',
          style: GoogleFonts.cairo(),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('practice_sessions').doc(widget.docId).delete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'حذف',
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _getDifficultyLabel(String diff) {
    switch (diff) {
      case 'easy':
        return 'سهل';
      case 'medium':
        return 'متوسط';
      case 'hard':
        return 'صعب';
      default:
        return 'الكل';
    }
  }

  Color _getScoreColor(int pct) {
    if (pct >= 85) return Colors.green;
    if (pct >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildMiniStat(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
