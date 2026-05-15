import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/presentation/screens/manage_activation_codes_screen.dart';
import 'package:quizzly/features/admin/presentation/screens/database_management_screen.dart';
import 'package:quizzly/features/admin/presentation/screens/analytics_dashboard_screen.dart';
import 'package:quizzly/features/admin/presentation/screens/reports_management_screen.dart';
import 'package:quizzly/features/admin/presentation/screens/user_management_screen.dart';
import 'package:quizzly/features/admin/presentation/screens/financial_stats_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isLoading = false;

  Future<Map<String, String>> _fetchStats() async {

    Future<int> safeAggCount(AggregateQuery q) async {
      try { return (await q.get()).count ?? 0; }
      catch (e) { debugPrint('AGG COUNT ERROR: $e'); return -1; }
    }

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      // Run each independently so one failure doesn't kill everything
      final usersCount       = await safeAggCount(_db.collection('users').count());
      final activeCodesCount = await safeAggCount(
          _db.collection('activation_codes').where('isUsed', isEqualTo: false).count());
      final usedCodesCount   = await safeAggCount(
          _db.collection('activation_codes').where('isUsed', isEqualTo: true).count());
      final questionsCount   = await safeAggCount(_db.collection('questions').count());
      final examsCount       = await safeAggCount(_db.collection('exam_attempts').count());
      final unisCount        = await safeAggCount(_db.collection('universities').count());
      final collegesCount    = await safeAggCount(_db.collection('colleges').count());
      final deptsCount       = await safeAggCount(_db.collection('departments').count());
      final subjectsCount    = await safeAggCount(_db.collection('subjects').count());

      int totalRevenue = 0;
      try {
        // Filter only by type to avoid composite index requirement;
        // filter timestamp in-memory
        final logsSnap = await _db.collection('credit_logs')
          .where('type', isEqualTo: 'redeem')
          .get();
        for (var doc in logsSnap.docs) {
          final data = doc.data();
          final ts = (data['timestamp'] as Timestamp?)?.toDate();
          if (ts != null && ts.isAfter(startOfMonth)) {
            totalRevenue += (data['amount'] as num?)?.toInt() ?? 0;
          }
        }
      } catch (e) {
        debugPrint('CREDIT_LOGS ERROR: $e');
        totalRevenue = -1;
      }

      String format(int v) => v < 0 ? 'خطأ' : v.toString();

      return {
        'users':      format(usersCount),
        'activeCodes':format(activeCodesCount),
        'usedCodes':  format(usedCodesCount),
        'questions':  format(questionsCount),
        'exams':      format(examsCount),
        'unis':       format(unisCount),
        'colleges':   format(collegesCount),
        'depts':      format(deptsCount),
        'subjects':   format(subjectsCount),
        'revenue':    totalRevenue < 0 ? 'خطأ' : totalRevenue.toString(),
      };
    } catch (e) {
      debugPrint('FETCHSTATS FATAL: $e');
      return {
        'users': '!', 'activeCodes': '!', 'usedCodes': '!', 'questions': '!', 'exams': '!',
        'unis': '!', 'colleges': '!', 'depts': '!', 'subjects': '!', 'revenue': '!',
      };
    }
  }

  void _refresh() {
    setState(() {
      _isLoading = true;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'لوحة تحكم الأدمن',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            color: AppColors.primaryBlue,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Statistics Cards ────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('إحصائيات النظام', isDark),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AnalyticsDashboardScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics_outlined, size: 16),
                  label: Text(
                    'تحليلات مفصلة',
                    style: GoogleFonts.cairo(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, String>>(
              future: _fetchStats(),
              builder: (context, snapshot) {
                final stats =
                    snapshot.data ??
                    {
                      'users': '...',
                      'activeCodes': '...',
                      'usedCodes': '...',
                      'questions': '...',
                      'exams': '...',
                      'unis': '...',
                      'colleges': '...',
                      'depts': '...',
                      'subjects': '...',
                      'revenue': '...',
                    };

                return Column(
                  children: [
                    // Revenue Card
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'الأموال المحصلة لهذا الشهر',
                                style: GoogleFonts.cairo(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${stats['revenue']} ل.س',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    // ── Stat Cards Grid (max 220px per card, 2 cols min) ──
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220, // بطاقة لا تتجاوز 220px
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.9, // نسبة عرض/ارتفاع ثابتة
                          ),
                      itemCount: 5,
                      itemBuilder: (context, index) {
                        final cards = [
                          _buildStatCard(
                            icon: Icons.people_alt_rounded,
                            label: 'المستخدمين',
                            value: stats['users']!,
                            color: const Color(0xFF3B82F6),
                          ),
                          _buildStatCard(
                            icon: Icons.vpn_key_rounded,
                            label: 'الأكواد النشطة',
                            value: stats['activeCodes']!,
                            color: const Color(0xFF10B981),
                          ),
                          _buildStatCard(
                            icon: Icons.person_rounded,
                            label: 'الأكواد المستخدمة',
                            value: stats['usedCodes']!,
                            color: Colors.orange,
                          ),
                          _buildStatCard(
                            icon: Icons.quiz_rounded,
                            label: 'الأسئلة الكلية',
                            value: stats['questions']!,
                            color: const Color(0xFFF59E0B),
                          ),
                          _buildStatCard(
                            icon: Icons.assignment_turned_in_rounded,
                            label: 'اختبارات منجزة',
                            value: stats['exams']!,
                            color: const Color(0xFF8B5CF6),
                          ),
                        ];
                        return cards[index];
                      },
                    ),
                    const SizedBox(height: 16),
                    // Content Stats
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white10
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniStat(
                            'جامعات',
                            stats['unis']!,
                            Icons.account_balance_rounded,
                          ),
                          _buildMiniStat(
                            'كليات',
                            stats['colleges']!,
                            Icons.school_rounded,
                          ),
                          _buildMiniStat(
                            'أقسام',
                            stats['depts']!,
                            Icons.category_rounded,
                          ),
                          _buildMiniStat(
                            'مواد',
                            stats['subjects']!,
                            Icons.book_rounded,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            // ─── Quick Actions ──────────────────────────────────
            _buildSectionTitle('إجراءات سريعة', isDark),
            const SizedBox(height: 16),
            _buildActionTile(
              icon: Icons.manage_accounts_rounded,
              title: 'إدارة المستخدمين',
              subtitle: 'تعديل الصلاحيات وإلغاء ارتباط الأجهزة',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UserManagementScreen(),
                  ),
                );
              },
              isDark: isDark,
            ),
            _buildActionTile(
              icon: Icons.vpn_key_rounded,
              title: 'إدارة مجموعات الأكواد',
              subtitle: 'عرض، طباعة، وحذف دفعات الأكواد',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageActivationCodesScreen(),
                  ),
                );
              },
              isDark: isDark,
            ),
            _buildActionTile(
              icon: Icons.monetization_on_rounded,
              title: 'إدارة الإحصاءات المالية',
              subtitle: 'عرض الأموال المحصلة وإحصاءات المواد',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FinancialStatsScreen(),
                  ),
                );
              },
              isDark: isDark,
            ),
            _buildActionTile(
              icon: Icons.notifications_active_rounded,
              title: 'إرسال إشعار عام',
              subtitle: 'تنبيه جميع المستخدمين بآخر التحديثات',
              onTap: () {},
              isDark: isDark,
            ),
            _buildActionTile(
              icon: Icons.storage_rounded,
              title: 'إدارة قاعدة البيانات',
              subtitle: 'تحديث الجداول والمحتوى التعليمي',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DatabaseManagementScreen(),
                  ),
                );
              },
              isDark: isDark,
            ),
            _buildActionTile(
              icon: Icons.report_problem_rounded,
              title: 'إدارة البلاغات',
              subtitle: 'مراجعة شكاوى المستخدمين حول الأسئلة',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReportsManagementScreen(),
                  ),
                );
              },
              isDark: isDark,
            ),


            const SizedBox(height: 32),

            // ─── System Status ──────────────────────────────────
            _buildSectionTitle('حالة النظام', isDark),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? theme.cardColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white10 : AppColors.borderLight,
                ),
              ),
              child: Column(
                children: [
                  _buildStatusRow('Firestore Database', 'Active', Colors.green),
                  const Divider(height: 32),
                  _buildStatusRow('Auth Services', 'Active', Colors.green),
                  const Divider(height: 32),
                  _buildStatusRow('Cloud Storage', 'Warning', Colors.orange),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.cairo(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppColors.textPrimary,
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? Colors.white10 : AppColors.borderLight,
          ),
        ),
        tileColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primaryBlue),
        ),
        title: Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.cairo(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String service, String status, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          service,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              status,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
