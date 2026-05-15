import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/core/theme/theme_service.dart';
import 'package:quizzly/features/settings/domain/services/settings_service.dart';

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
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
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

              // ── Video Settings
              _buildSectionHeader('إعدادات الفيديو', Icons.videocam_rounded, isDark),
              _buildSwitchTile(
                title: 'تحميل أثناء التشغيل',
                subtitle: 'تحميل الفيديوهات تلقائياً أثناء تشغيلها',
                value: settings.loadWhilePlaying,
                onChanged: settings.setLoadWhilePlaying,
                isDark: isDark,
              ),
              _buildSelectionTile(
                title: 'عدد التحميلات المتزامنة',
                subtitle: 'الحد الأقصى لعدد التحميلات المتزامنة: ${settings.concurrentDownloads}',
                trailingText: '${settings.concurrentDownloads}',
                icon: Icons.download_rounded,
                onTap: () => _showSingleSelectionDialog(
                  context,
                  'عدد التحميلات المتزامنة',
                  [1, 2, 3, 4, 5],
                  settings.concurrentDownloads,
                  settings.setConcurrentDownloads,
                  (v) => v.toString(),
                ),
                isDark: isDark,
              ),
              _buildSelectionTile(
                title: 'مقدار القفز في الفيديو',
                subtitle: 'مقدار القفز للأمام أو للخلف: ${settings.skipDuration} ثواني',
                trailingText: '${settings.skipDuration} ث',
                icon: Icons.fast_forward_rounded,
                onTap: () => _showSingleSelectionDialog(
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

              // ── Data Management
              _buildSectionHeader('إدارة البيانات', Icons.storage_rounded, isDark),
              _buildActionTile(
                title: 'إعادة تحميل بيانات الأكواد',
                subtitle: 'جلب أحدث بيانات الأكواد من الخادم',
                icon: Icons.refresh_rounded,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('جاري إعادة تحميل البيانات...'))
                  );
                },
                isDark: isDark,
              ),
              _buildDivider(isDark),

              // ── Auto Update settings
              _buildSectionHeader('إعدادات التحديث التلقائي', Icons.update_rounded, isDark),
              _buildSelectionTile(
                title: 'فترة التحقق من التحديثات',
                subtitle: 'التحقق التلقائي كل ${settings.autoUpdateInterval} دقائق',
                trailingText: '${settings.autoUpdateInterval} د',
                icon: Icons.access_time_rounded,
                onTap: () => _showSingleSelectionDialog(
                  context,
                  'فترة التحقق من التحديثات',
                  [5, 10, 30, 60, 120],
                  settings.autoUpdateInterval,
                  settings.setAutoUpdateInterval,
                  (v) => '$v دقيقة',
                ),
                isDark: isDark,
              ),
              _buildDivider(isDark),

              // ── Notes settings
              _buildSectionHeader('إعدادات الملاحظات', Icons.note_alt_rounded, isDark),
              _buildSelectionTile(
                title: 'مدة عرض الملاحظات',
                subtitle: 'مدة عرض ملاحظات الأسئلة وشرح الأسئلة: ${settings.notesDisplayDuration} ثواني',
                trailingText: '${settings.notesDisplayDuration} ث',
                icon: Icons.speaker_notes_rounded,
                onTap: () => _showSingleSelectionDialog(
                  context,
                  'مدة عرض الملاحظات',
                  [3, 5, 10, 15],
                  settings.notesDisplayDuration,
                  settings.setNotesDisplayDuration,
                  (v) => '$v ثانية',
                ),
                isDark: isDark,
              ),
              _buildDivider(isDark),

              // ── Display settings
              _buildSectionHeader('إعدادات العرض', Icons.desktop_windows_rounded, isDark),
              _buildSwitchTile(
                title: 'تثبيت آخر مادة مفتوحة في الأعلى',
                subtitle: 'عرض آخر مادة تم فتحها في أعلى القائمة',
                value: settings.pinLastSubject,
                onChanged: settings.setPinLastSubject,
                isDark: isDark,
              ),
              _buildDivider(isDark),

              // ── User Data
              _buildSectionHeader('بيانات المستخدم', Icons.person_rounded, isDark),
              _buildSwitchTile(
                title: 'عرض حلولي والموضع الأخير',
                subtitle: 'مزامنة حلولك وموضعك الأخير في المواد',
                value: settings.showMySolutions,
                onChanged: settings.setShowMySolutions,
                isDark: isDark,
              ),
              _buildActionTile(
                title: 'حذف بيانات مادة محددة',
                subtitle: 'إزالة سجلات الحلول لمادة معينة',
                icon: Icons.delete_outline_rounded,
                onTap: () {},
                isDark: isDark,
              ),
              _buildActionTile(
                title: 'حذف الحساب',
                subtitle: 'سيتم حذف حسابك وجميع البيانات نهائياً',
                icon: Icons.person_off_rounded,
                isDestructive: true,
                onTap: () {},
                isDark: isDark,
              ),
              _buildActionTile(
                title: 'نسخ معلومات الجهاز',
                subtitle: 'نسخ المعرّفات التقنية للدعم الفني',
                icon: Icons.copy_rounded,
                hasArrow: false,
                onTap: () {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ معلومات الجهاز بنجاح'))
                  );
                },
                isDark: isDark,
              ),
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
}
