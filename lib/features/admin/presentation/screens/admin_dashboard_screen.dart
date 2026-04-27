import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/presentation/widgets/generate_codes_dialog.dart';
import 'package:quizzly/features/admin/presentation/screens/manage_activation_codes_screen.dart';
import 'package:quizzly/features/admin/presentation/screens/database_management_screen.dart';
import 'package:quizzly/features/admin/presentation/screens/analytics_dashboard_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isLoading = false;

  Future<Map<String, String>> _fetchStats() async {
    try {
      final results = await Future.wait([
        _db.collection('users').count().get(),
        _db.collection('activation_codes').count().get(),
        _db.collection('questions').count().get(),
        _db.collection('exam_attempts').count().get(),
      ]);

      return {
        'users': results[0].count.toString(),
        'codes': results[1].count.toString(),
        'questions': results[2].count.toString(),
        'exams': results[3].count.toString(),
      };
    } catch (e) {
      return {
        'users': '0',
        'codes': '0',
        'questions': '0',
        'exams': '0',
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
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
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
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsDashboardScreen()));
                  },
                  icon: const Icon(Icons.analytics_outlined, size: 16),
                  label: Text('تحليلات مفصلة', style: GoogleFonts.cairo(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, String>>(
              future: _fetchStats(),
              builder: (context, snapshot) {
                final stats = snapshot.data ?? {
                  'users': '...',
                  'codes': '...',
                  'questions': '...',
                  'exams': '...',
                };

                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.8,
                  children: [
                    _buildStatCard(
                      icon: Icons.people_alt_rounded,
                      label: 'المستخدمين',
                      value: stats['users']!,
                      color: const Color(0xFF3B82F6),
                    ),
                    _buildStatCard(
                      icon: Icons.vpn_key_rounded,
                      label: 'الأكواد النشطة',
                      value: stats['codes']!,
                      color: const Color(0xFF10B981),
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
                  ],
                );
              }
            ),

            const SizedBox(height: 32),

            // ─── Quick Actions ──────────────────────────────────
            _buildSectionTitle('إجراءات سريعة', isDark),
            const SizedBox(height: 16),
            _buildActionTile(
              icon: Icons.add_moderator_rounded,
              title: 'توليد أكواد تفعيل جديدة',
              subtitle: 'إنشاء مفاتيح وصول للمستخدمين الجدد',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const GenerateCodesDialog(),
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
                  MaterialPageRoute(builder: (_) => const ManageActivationCodesScreen()),
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
                  MaterialPageRoute(builder: (_) => const DatabaseManagementScreen()),
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
                border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11,
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
          side: BorderSide(color: isDark ? Colors.white10 : AppColors.borderLight),
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
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      ),
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
