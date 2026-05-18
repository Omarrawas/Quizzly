import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/core/theme/theme_service.dart';
import 'package:quizzly/features/settings/domain/services/settings_service.dart';
import 'package:quizzly/features/settings/presentation/screens/user_profile_screen.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/core/services/app_update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(
            Icons.menu_rounded,
            color: isDark ? Colors.white : AppColors.textPrimary,
            size: 24,
          ),
        ),
        title: Text(
          'الإعدادات',
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1, 
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)
          ),
        ),
      ),
      body: Consumer<SettingsService>(
        builder: (context, settings, child) {
          final auth = Provider.of<AuthService>(context, listen: false);
          final userId = auth.user?.uid ?? '';

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              // ── User Profile Section
              _buildSectionHeader('الحساب', Icons.person_rounded, isDark),
              Consumer<AuthService>(
                builder: (context, auth, _) {
                  final email = auth.user?.email ?? 'مستخدم غير مسجل';
                  return Column(
                    children: [
                       _buildActionTile(
                        title: 'بياناتي الشخصية',
                        subtitle: email,
                        icon: Icons.badge_rounded,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                          );
                        },
                        isDark: isDark,
                      ),
                    ],
                  );
                },
              ),
              _buildDivider(isDark),

              // ── Appearance Settings
              _buildSectionHeader('المظهر', Icons.palette_rounded, isDark),
              Consumer<ThemeService>(
                builder: (context, themeService, _) {
                  return _buildSwitchTile(
                    title: 'الوضع الليلي',
                    subtitle: 'تفعيل الوضع الليلي في جميع صفحات التطبيق',
                    value: themeService.themeMode == ThemeMode.dark,
                    onChanged: (val) => themeService.toggleTheme(),
                    isDark: isDark,
                  );
                },
              ),
              _buildDivider(isDark),

              // ── Study Experience Settings
              _buildSectionHeader('تجربة الدراسة', Icons.menu_book_rounded, isDark),
              _buildSelectionTile(
                title: 'حجم النص',
                subtitle: 'تعديل حجم النصوص المعروضة في شاشات الأسئلة',
                trailingText: settings.textSize == 'smaller'
                    ? 'أصغر'
                    : settings.textSize == 'larger'
                        ? 'أكبر'
                        : settings.textSize == 'very_large'
                            ? 'كبير جداً'
                            : 'الحجم الافتراضي',
                icon: Icons.format_size_rounded,
                onTap: () => _showTextSizeSelectionDialog(context, settings),
                isDark: isDark,
              ),
              _buildSelectionTile(
                title: 'مدة عرض الملاحظات',
                subtitle: 'مدة عرض ملاحظات الطلاب المحفوظة في شاشة الاختبار',
                trailingText: settings.notesDisplayDuration == -1
                    ? 'ثابتة'
                    : '${settings.notesDisplayDuration} ث',
                icon: Icons.speaker_notes_rounded,
                onTap: () => _showSingleSelectionDialog<int>(
                  context,
                  'مدة عرض الملاحظات',
                  [-1, 3, 5, 10],
                  settings.notesDisplayDuration,
                  settings.setNotesDisplayDuration,
                  (v) => v == -1 ? 'ثابتة' : '$v ثواني',
                ),
                isDark: isDark,
              ),
              _buildSelectionTile(
                title: 'مدة عرض الشرح',
                subtitle: 'مدة عرض شريط توضيح الإجابة التلقائي',
                trailingText: settings.explanationDisplayDuration == -1
                    ? 'ثابتة'
                    : '${settings.explanationDisplayDuration} ث',
                icon: Icons.assignment_turned_in_rounded,
                onTap: () => _showSingleSelectionDialog<int>(
                  context,
                  'مدة عرض الشرح',
                  [-1, 3, 5, 10],
                  settings.explanationDisplayDuration,
                  settings.setExplanationDisplayDuration,
                  (v) => v == -1 ? 'ثابتة' : '$v ثواني',
                ),
                isDark: isDark,
              ),
              _buildSwitchTile(
                title: 'تحميل أثناء التشغيل',
                subtitle: 'تحميل الفيديوهات تلقائياً أثناء تشغيلها',
                value: settings.loadWhilePlaying,
                onChanged: settings.setLoadWhilePlaying,
                isDark: isDark,
              ),
              _buildSelectionTile(
                title: 'مقدار القفز في الفيديو',
                subtitle: 'مقدار القفز للأمام أو للخلف: ${settings.skipDuration} ثواني',
                trailingText: '${settings.skipDuration} ث',
                icon: Icons.fast_forward_rounded,
                onTap: () => _showSingleSelectionDialog<int>(
                  context,
                  'مقدار القفز في الفيديو',
                  [5, 10, 15, 30, 60],
                  settings.skipDuration,
                  settings.setSkipDuration,
                  (v) => '$v ثانية',
                ),
                isDark: isDark,
              ),
              _buildDivider(isDark),

              // ── Content Organization
              _buildSectionHeader('تنظيم المحتوى', Icons.sort_rounded, isDark),
              _buildSwitchTile(
                title: 'تثبيت آخر مادة مفتوحة',
                subtitle: 'عرض آخر مادة تم فتحها في أعلى القائمة الرئيسية',
                value: settings.pinLastSubject,
                onChanged: settings.setPinLastSubject,
                isDark: isDark,
              ),
              _buildSwitchTile(
                title: 'عرض حلولي والموضع الأخير',
                subtitle: 'مزامنة حلولك وموضعك الأخير في المواد',
                value: settings.showMySolutions,
                onChanged: settings.setShowMySolutions,
                isDark: isDark,
              ),
              _buildDivider(isDark),

              // ── Updates and Content Data
              _buildSectionHeader('التحديثات وبيانات المحتوى', Icons.sync_rounded, isDark),
              _buildSelectionTile(
                title: 'فترة التحديث التلقائي',
                subtitle: 'التحقق التلقائي من التحديثات كل ${settings.autoUpdateInterval} دقائق',
                trailingText: '${settings.autoUpdateInterval} د',
                icon: Icons.access_time_rounded,
                onTap: () => _showSingleSelectionDialog(
                  context,
                  'فترة التحديث التلقائي',
                  [5, 10, 30, 60, 120],
                  settings.autoUpdateInterval,
                  settings.setAutoUpdateInterval,
                  (v) => '$v دقيقة',
                ),
                isDark: isDark,
              ),
              _buildActionTile(
                title: 'إعادة تحميل بيانات المواد',
                subtitle: 'تحديث وتنزيل بيانات المواد والأسئلة من السحابة',
                icon: Icons.refresh_rounded,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('جاري إعادة تحميل البيانات...'))
                  );
                },
                isDark: isDark,
              ),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? '...';
                  final buildNumber = snapshot.data?.buildNumber ?? '';
                  return _buildActionTile(
                    title: 'التحقق من وجود تحديث',
                    subtitle: 'الإصدار الحالي: $version ($buildNumber) - اضغط للتحقق',
                    icon: Icons.system_update_rounded,
                    onTap: () => AppUpdateService().checkForUpdates(context, showNoUpdateDialog: true),
                    isDark: isDark,
                  );
                },
              ),
              _buildDivider(isDark),

              // ── User Data
              _buildSectionHeader('بيانات المستخدم', Icons.person_rounded, isDark),
              _buildActionTile(
                title: 'حذف بيانات مادة محددة',
                subtitle: 'إزالة سجلات الحلول لمادة معينة',
                icon: Icons.delete_outline_rounded,
                onTap: () => _handleDeleteSubjectProgress(context, userId),
                isDark: isDark,
              ),
              _buildActionTile(
                title: 'حذف الحساب',
                subtitle: 'سيتم حذف حسابك وجميع البيانات نهائياً',
                icon: Icons.person_off_rounded,
                isDestructive: true,
                onTap: () => _handleDeleteAccount(context, auth),
                isDark: isDark,
              ),
              _buildActionTile(
                title: 'نسخ معلومات الجهاز',
                subtitle: 'نسخ المعرّفات التقنية للدعم الفني',
                icon: Icons.copy_rounded,
                hasArrow: false,
                onTap: () => _handleCopyDeviceInfo(context, userId),
                isDark: isDark,
              ),
              _buildDivider(isDark),
              const SizedBox(height: 40),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 32, 
      thickness: 1,
      indent: 20, 
      endIndent: 20, 
      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
    );
  }

  void _showSingleSelectionDialog<T>(
    BuildContext context,
    String title,
    List<T> options,
    T currentValue,
    Function(T) onSelected,
    String Function(T) labelBuilder,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          title, 
          style: GoogleFonts.cairo(
            fontSize: 18, 
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        contentPadding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((opt) {
            final isSelected = opt == currentValue;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected 
                  ? AppColors.primaryBlue.withValues(alpha: isDark ? 0.15 : 0.1) 
                  : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text(
                  labelBuilder(opt), 
                  style: GoogleFonts.cairo(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected 
                      ? (isDark ? const Color(0xFF60A5FA) : AppColors.primaryBlue) 
                      : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  textAlign: TextAlign.center,
                ),
                onTap: () {
                  onSelected(opt);
                  Navigator.pop(context);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: isDark ? const Color(0xFF60A5FA) : AppColors.primaryBlue, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primaryBlue,
      activeTrackColor: AppColors.primaryBlue.withValues(alpha: 0.2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
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
          color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSelectionTile({
    required String title,
    required String subtitle,
    required String trailingText,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
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
          color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
        ),
      ),
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          trailingText,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF60A5FA) : AppColors.primaryBlue,
          ),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded, 
        size: 14, 
        color: isDark ? Colors.white24 : Colors.grey[300]
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool hasArrow = true,
    required bool isDark,
  }) {
    final titleColor = isDestructive 
        ? const Color(0xFFEF4444) 
        : (isDark ? Colors.white : AppColors.textPrimary);
    
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      title: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: titleColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.cairo(
          fontSize: 12,
          color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
        ),
      ),
      trailing: hasArrow ? Icon(
        Icons.arrow_forward_ios_rounded, 
        size: 14, 
        color: isDark ? Colors.white24 : Colors.grey[300]
      ) : null,
      leading: Icon(
        icon, 
        color: isDestructive ? titleColor : (isDark ? Colors.white38 : AppColors.textSecondary), 
        size: 22
      ),
    );
  }

  // ── User Data Action Handlers ──

  Future<void> _handleDeleteSubjectProgress(BuildContext context, String userId) async {
    final db = FirebaseFirestore.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى تسجيل الدخول أولاً.',
            style: GoogleFonts.cairo(),
            textAlign: TextAlign.right,
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Get active subjects
      final activeSubsSnap = await db.collection('user_subjects')
          .where('userId', isEqualTo: userId)
          .get();

      if (!context.mounted) return;
      Navigator.pop(context); // Remove loading indicator

      if (activeSubsSnap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لا توجد مواد مفعّلة حالياً لحذف بياناتها.',
              style: GoogleFonts.cairo(),
              textAlign: TextAlign.right,
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 2. Fetch subject titles
      final List<Map<String, String>> subjectsList = [];
      for (var doc in activeSubsSnap.docs) {
        final subjectId = doc.data()['subjectId'] as String;
        final subDoc = await db.collection('subjects').doc(subjectId).get();
        if (subDoc.exists) {
          final title = subDoc.data()?['title'] ?? 'مادة غير معروفة';
          subjectsList.add({'id': subjectId, 'title': title});
        } else {
          subjectsList.add({'id': subjectId, 'title': subjectId});
        }
      }

      // 3. Show selection dialog
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'حذف بيانات مادة محددة',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: subjectsList.length,
              itemBuilder: (context, index) {
                final sub = subjectsList[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      sub['title']!,
                      style: GoogleFonts.cairo(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.white30 : Colors.grey),
                    onTap: () {
                      Navigator.pop(context); // Close selection list
                      _confirmDeleteSubjectProgress(context, userId, sub['id']!, sub['title']!);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Remove loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء جلب المواد: $e')),
      );
    }
  }

  void _confirmDeleteSubjectProgress(BuildContext context, String userId, String subjectId, String subjectTitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'تأكيد الحذف',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
          textAlign: TextAlign.right,
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف جميع سجلات الحلول، المفضلة، وسجل الإعادة المتباعدة الخاصة بمادة "$subjectTitle"؟ لا يمكن التراجع عن هذا الإجراء.',
          style: GoogleFonts.cairo(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close confirmation dialog
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );

              try {
                final db = FirebaseFirestore.instance;

                // 1. Delete user_history entry fields for the subject
                final userHistoryDoc = db.collection('user_history').doc(userId);
                final userHistorySnap = await userHistoryDoc.get();
                if (userHistorySnap.exists) {
                  await userHistoryDoc.update({
                    'wrongAnswers_$subjectId': FieldValue.delete(),
                    'correctAnswers_$subjectId': FieldValue.delete(),
                    'solvedQuestions_$subjectId': FieldValue.delete(),
                    'skippedQuestions_$subjectId': FieldValue.delete(),
                  });
                }

                // 2. Delete practice sessions for the subject
                final practiceSessions = await db.collection('practice_sessions')
                    .where('userId', isEqualTo: userId)
                    .where('subjectId', isEqualTo: subjectId)
                    .get();
                for (var doc in practiceSessions.docs) {
                  await doc.reference.delete();
                }

                // 3. Delete favorites for the subject
                final favorites = await db.collection('users')
                    .doc(userId)
                    .collection('user_lists')
                    .doc('favorites')
                    .collection('questions')
                    .where('questionData.subjectId', isEqualTo: subjectId)
                    .get();
                for (var doc in favorites.docs) {
                  await doc.reference.delete();
                }

                // 4. Delete mastery entries for the subject
                final mastery = await db.collection('users')
                    .doc(userId)
                    .collection('mastery')
                    .where('subjectId', isEqualTo: subjectId)
                    .get();
                for (var doc in mastery.docs) {
                  await doc.reference.delete();
                }

                if (!context.mounted) return;
                Navigator.pop(context); // Close loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم مسح سجل الحلول لمادة $subjectTitle بنجاح',
                      style: GoogleFonts.cairo(),
                      textAlign: TextAlign.right,
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context); // Close loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('حدث خطأ أثناء الحذف: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('نعم، احذف', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleDeleteAccount(BuildContext context, AuthService auth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'حذف الحساب نهائياً',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
          ],
        ),
        content: Text(
          'تحذير: سيتم حذف حسابك وجميع بياناتك (سجل الحلول، الملاحظات، المفضلة، الكود الفعّال، والرصيد) بشكل نهائي ولا يمكن استرجاعها. هل أنت متأكد من رغبتك في حذف الحساب؟',
          style: GoogleFonts.cairo(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close confirmation dialog
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );

              final success = await auth.deleteAccount();
              if (!context.mounted) return;
              Navigator.pop(context); // Close loading indicator

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم حذف الحساب بنجاح. سنفتقدك!',
                      style: GoogleFonts.cairo(),
                      textAlign: TextAlign.right,
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      auth.errorMessage ?? 'فشل في حذف الحساب.',
                      style: GoogleFonts.cairo(),
                      textAlign: TextAlign.right,
                    ),
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('نعم، احذف الحساب', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCopyDeviceInfo(BuildContext context, String? uid) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_installation_id') ?? 'غير متوفر';
    final packageInfo = await PackageInfo.fromPlatform();
    
    String os = 'Unknown';
    if (kIsWeb) {
      os = 'Web';
    } else if (Platform.isAndroid) {
      os = 'Android';
    } else if (Platform.isIOS) {
      os = 'iOS';
    } else if (Platform.isWindows) {
      os = 'Windows';
    }

    final String infoText = """
--- Quizzly Device Support Info ---
User UID: ${uid ?? 'Not Logged In'}
Device Installation ID: $deviceId
OS: $os
App Version: ${packageInfo.version} (${packageInfo.buildNumber})
-----------------------------------
""";

    await Clipboard.setData(ClipboardData(text: infoText));
    
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ معلومات الجهاز الفنية إلى الحافظة بنجاح.',
          style: GoogleFonts.cairo(),
          textAlign: TextAlign.right,
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showTextSizeSelectionDialog(BuildContext context, SettingsService settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentValue = settings.textSize;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'حجم خط النصوص',
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextSizeOption(
                  context: context,
                  settings: settings,
                  value: 'smaller',
                  title: 'أصغر (85%)',
                  scaleFactor: 0.85,
                  isSelected: currentValue == 'smaller',
                  isDark: isDark,
                ),
                _buildTextSizeOption(
                  context: context,
                  settings: settings,
                  value: 'default',
                  title: 'الحجم الافتراضي (100%)',
                  scaleFactor: 1.0,
                  isSelected: currentValue == 'default',
                  isDark: isDark,
                ),
                _buildTextSizeOption(
                  context: context,
                  settings: settings,
                  value: 'larger',
                  title: 'أكبر (115%)',
                  scaleFactor: 1.15,
                  isSelected: currentValue == 'larger',
                  isDark: isDark,
                ),
                _buildTextSizeOption(
                  context: context,
                  settings: settings,
                  value: 'very_large',
                  title: 'كبير جداً (135%)',
                  scaleFactor: 1.35,
                  isSelected: currentValue == 'very_large',
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextSizeOption({
    required BuildContext context,
    required SettingsService settings,
    required String value,
    required String title,
    required double scaleFactor,
    required bool isSelected,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryBlue.withValues(alpha: isDark ? 0.15 : 0.08)
            : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? (isDark ? const Color(0xFF60A5FA) : AppColors.primaryBlue)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () {
          settings.setTextSize(value);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected
                          ? (isDark ? const Color(0xFF60A5FA) : AppColors.primaryBlue)
                          : (isDark ? Colors.white : AppColors.textPrimary),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: isDark ? const Color(0xFF60A5FA) : AppColors.primaryBlue,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'هذا مثال لنص السؤال او الشرح كما سيظهر في التطبيق',
                  style: GoogleFonts.cairo(
                    fontSize: 13 * scaleFactor,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
