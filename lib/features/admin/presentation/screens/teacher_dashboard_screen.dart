import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/presentation/screens/subject_dashboard_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _SubjectStats {
  final int subscribers;
  final int activeStudents;
  final int revenue;

  _SubjectStats({
    this.subscribers = 0,
    this.activeStudents = 0,
    this.revenue = 0,
  });
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final Map<String, _SubjectStats> _statsMap = {};
  bool _statsLoading = true;
  int _totalTeacherRevenue = 0;
  int _totalTeacherStudents = 0;

  @override
  void initState() {
    super.initState();
    _fetchAllStats();
  }

  Future<void> _fetchAllStats() async {
    if (!mounted) return;
    setState(() => _statsLoading = true);
    try {
      final subjectsSnap = await FirebaseFirestore.instance
          .collection('subjects')
          .where(
            Filter.or(
              Filter('teacherId', isEqualTo: _currentUserId),
              Filter('teacherIds', arrayContains: _currentUserId),
            ),
          )
          .get();

      final subjectIds = subjectsSnap.docs.map((d) => d.id).toList();
      if (subjectIds.isEmpty) {
        if (mounted) {
          setState(() {
            _statsLoading = false;
            _totalTeacherRevenue = 0;
            _totalTeacherStudents = 0;
          });
        }
        return;
      }

      int totalRevenue = 0;
      Set<String> totalUniqueStudents = {};

      for (final id in subjectIds) {
        // 1. Fetch Subscribers Count
        final subsSnap = await FirebaseFirestore.instance
            .collection('user_subjects')
            .where('subjectId', isEqualTo: id)
            .count()
            .get();
        final subsCount = subsSnap.count ?? 0;

        // 2. Fetch Active Students (Distinct users who took exams)
        final attemptsSnap = await FirebaseFirestore.instance
            .collection('exam_attempts')
            .where('subjectId', isEqualTo: id)
            .get();
        
        final uniqueStudents = attemptsSnap.docs.map((d) => d.data()['userId'] as String?).whereType<String>().toSet();
        final activeCount = uniqueStudents.length;

        // 3. Fetch Revenue
        final activationsSnap = await FirebaseFirestore.instance
            .collection('user_subjects')
            .where('subjectId', isEqualTo: id)
            .get();
        
        int revenue = 0;
        for (var doc in activationsSnap.docs) {
          final data = doc.data();
          final type = data['activationType'] as String? ?? 'free';
          final price = (data['price'] as num?)?.toInt() ?? 0;
          if (type == 'purchase' || price > 0) {
            revenue += price;
          }
          
          final userId = data['userId'] as String?;
          if (userId != null) totalUniqueStudents.add(userId);
        }

        _statsMap[id] = _SubjectStats(
          subscribers: subsCount,
          activeStudents: activeCount,
          revenue: revenue,
        );
        
        totalRevenue += revenue;
      }

      if (mounted) {
        setState(() {
          _totalTeacherRevenue = totalRevenue;
          _totalTeacherStudents = totalUniqueStudents.length;
          _statsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching teacher stats: $e');
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('لوحة تحكم المعلم', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        backgroundColor: theme.appBarTheme.backgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchAllStats,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('subjects')
            .where(
              Filter.or(
                Filter('teacherId', isEqualTo: _currentUserId),
                Filter('teacherIds', arrayContains: _currentUserId),
              ),
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}', style: GoogleFonts.cairo()));
          }

          final subjects = snapshot.data!.docs;

          if (subjects.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_stories_rounded, size: 64, color: isDark ? Colors.white24 : Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد مواد مرتبطة بك حالياً.',
                    style: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSimpleAnalytics(subjects, isDark),
                const SizedBox(height: 24),
                Text(
                  'موادي الدراسية',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: subjects.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final subjectDoc = subjects[index];
                    final data = subjectDoc.data() as Map<String, dynamic>;
                    return _buildSubjectListItem(context, subjectDoc.id, data, isDark);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSimpleAnalytics(List<QueryDocumentSnapshot> subjects, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.primaryBlue.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('المواد', subjects.length.toString(), Icons.book_rounded),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildStatItem(
            'طلابك', 
            _statsLoading ? '...' : _totalTeacherStudents.toString(), 
            Icons.people_rounded
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildStatItem(
            'الإيرادات', 
            _statsLoading ? '...' : '$_totalTeacherRevenue', 
            Icons.account_balance_wallet_rounded
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSubjectListItem(BuildContext context, String id, Map<String, dynamic> data, bool isDark) {
    final stats = _statsMap[id] ?? _SubjectStats();
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubjectDashboardScreen(
              subjectId: id,
              subjectName: data['name'] ?? '',
              breadcrumbs: const ['لوحة تحكم المعلم'], 
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.auto_stories_rounded, color: AppColors.primaryBlue, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['name'] ?? 'بدون اسم',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'إدارة المحتوى والأقسام',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMiniStat('المشتركين', stats.subscribers.toString(), Icons.groups_rounded, isDark),
                _buildMiniStat('النشطين', stats.activeStudents.toString(), Icons.trending_up_rounded, isDark),
                _buildMiniStat('إحصاءات مالية', '${stats.revenue} ل.س', Icons.payments_rounded, isDark, valueColor: Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, bool isDark, {Color? valueColor}) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _statsLoading ? '...' : value,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: valueColor ?? (isDark ? Colors.white : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
