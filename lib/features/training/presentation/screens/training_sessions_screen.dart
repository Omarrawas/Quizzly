import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/training/presentation/screens/create_training_session_screen.dart';

class TrainingSessionsScreen extends StatefulWidget {
  final String subjectName;

  const TrainingSessionsScreen({
    super.key,
    this.subjectName = 'الكيمياء',
  });

  @override
  State<TrainingSessionsScreen> createState() => _TrainingSessionsScreenState();
}

class _TrainingSessionsScreenState extends State<TrainingSessionsScreen> {
  // للتبسيط سيتم استخدام قائمة فارغة في البداية لتوضيح الشاشة الفارغة
  // يمكنك تغييرها لاختبار عرض قائمة الجلسات
  final List<Map<String, dynamic>> _sessions = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _sessions.isEmpty ? _buildEmptyState() : _buildSessionsList(),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryBlue,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateTrainingSessionScreen(
                subjectName: widget.subjectName,
              ),
            ),
          ).then((value) {
            if (value == true) {
              // افتراض إضافة جلسة جديدة للتبسيط
              setState(() {
                _sessions.add({
                  'name': 'جلسة تدريب جديدة',
                  'questionsCount': 100,
                  'examsCount': 1,
                  'time': '60د',
                  'date': '20/04/2026, 2:52 مساءً',
                });
              });
            }
          });
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'جلسة جديدة',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      automaticallyImplyLeading: false,
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(
          Icons.arrow_forward_ios_rounded,
          color: AppColors.textPrimary,
          size: 20,
        ),
      ),
      title: Text(
        'جلسات التدريب',
        style: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFF1F5F9)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: 80,
            color: AppColors.primaryBlue.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 20),
          Text(
            'لا توجد جلسات تدريب',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'قم بإنشاء جلسة تدريب جديدة من شاشة الأوراق',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        return Card(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.borderLight),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session['name'],
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildPill(
                            icon: Icons.help_outline_rounded,
                            label: '0/${session['questionsCount']}',
                            color: AppColors.primaryBlue,
                            bgColor: const Color(0xFFEFF6FF),
                          ),
                          _buildPill(
                            icon: Icons.library_books_rounded,
                            label: '${session['examsCount']} امتحان',
                            color: const Color(0xFF16A34A),
                            bgColor: const Color(0xFFF0FDF4),
                          ),
                          _buildPill(
                            icon: Icons.timer_outlined,
                            label: session['time'],
                            color: const Color(0xFF9333EA),
                            bgColor: const Color(0xFFFDF4FF),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            session['date'],
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPill({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
