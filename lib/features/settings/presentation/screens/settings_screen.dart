import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/settings/domain/services/settings_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(
            Icons.menu_rounded,
            color: AppColors.textPrimary,
            size: 24,
          ),
        ),
        title: Text(
          'الإعدادات',
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
      ),
      body: Consumer<SettingsService>(
        builder: (context, settings, child) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              // ── Video Settings
              _buildSectionHeader('إعدادات الفيديو', Icons.videocam_rounded),
              _buildSwitchTile(
                title: 'تحميل أثناء التشغيل',
                subtitle: 'تحميل الفيديوهات تلقائياً أثناء تشغيلها',
                value: settings.loadWhilePlaying,
                onChanged: settings.setLoadWhilePlaying,
              ),
              _buildSelectionTile(
                title: 'عدد التحميلات المتزامنة',
                subtitle: 'الحد الأقصى لعدد التحميلات التي تعمل في نفس الوقت: ${settings.concurrentDownloads}',
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
              ),
              _buildSelectionTile(
                title: 'مقدار القفز في الفيديو',
                subtitle: 'مقدار القفز للأمام أو للخلف عند الضغط على أزرار القفز: ${settings.skipDuration} ثواني',
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
              ),
              const Divider(height: 32, indent: 20, endIndent: 20, color: AppColors.borderLight),

              // ── Data Management
              _buildSectionHeader('إدارة البيانات', Icons.storage_rounded),
              _buildActionTile(
                title: 'إعادة تحميل بيانات الأكواد',
                subtitle: 'جلب أحدث بيانات الأكواد من الخادم',
                icon: Icons.refresh_rounded,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('جاري إعادة تحميل البيانات...'))
                  );
                },
              ),
              const Divider(height: 32, indent: 20, endIndent: 20, color: AppColors.borderLight),

              // ── Auto Update settings
              _buildSectionHeader('إعدادات التحديث التلقائي', Icons.update_rounded),
              _buildSelectionTile(
                title: 'فترة التحقق من التحديثات',
                subtitle: 'التحقق التلقائي من التحديثات كل ${settings.autoUpdateInterval} دقائق',
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
              ),
              const Divider(height: 32, indent: 20, endIndent: 20, color: AppColors.borderLight),

              // ── Notes settings
              _buildSectionHeader('إعدادات الملاحظات', Icons.note_alt_rounded),
              _buildSelectionTile(
                title: 'مدة عرض الملاحظات',
                subtitle: 'مدة عرض ملاحظات الأسئلة وشرح الأسئلة وملاحظات الفيديو: ${settings.notesDisplayDuration} ثواني',
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
              ),
              const Divider(height: 32, indent: 20, endIndent: 20, color: AppColors.borderLight),

              // ── Display settings
              _buildSectionHeader('إعدادات العرض', Icons.desktop_windows_rounded),
              _buildSwitchTile(
                title: 'تثبيت آخر مادة مفتوحة في الأعلى',
                subtitle: 'عرض آخر مادة تم فتحها في أعلى قائمة المواد',
                value: settings.pinLastSubject,
                onChanged: settings.setPinLastSubject,
              ),
              const Divider(height: 32, indent: 20, endIndent: 20, color: AppColors.borderLight),

              // ── User Data
              _buildSectionHeader('بيانات المستخدم', Icons.person_rounded),
              _buildSwitchTile(
                title: 'عرض حلولي والموضع الأخير',
                subtitle: 'عند الإيقاف: لا يتم استعادة موضعك الأخير في كل ورقة/علامة ولا يتم استعادة حلولك',
                value: settings.showMySolutions,
                onChanged: settings.setShowMySolutions,
              ),
              _buildActionTile(
                title: 'حذف بيانات المستخدم لمادة محددة',
                subtitle: 'اختر مادة ونوع البيانات المراد حذفها',
                icon: Icons.delete_outline_rounded,
                onTap: () {},
              ),
              _buildActionTile(
                title: 'حذف الحساب',
                subtitle: 'سيتم حذف حسابك وجميع البيانات المرتبطة به نهائياً. لا يمكن التراجع عن هذا الإجراء.',
                icon: Icons.person_off_rounded,
                isDestructive: true,
                onTap: () {},
              ),
              _buildActionTile(
                title: 'نسخ معلومات الجهاز',
                subtitle: 'نسخ طراز الجهاز والنظام والمعرّفات للدعم الفني',
                icon: Icons.copy_rounded,
                hasArrow: false,
                onTap: () {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ معلومات الجهاز بنجاح'))
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
        content: RadioGroup<T>(
          groupValue: currentValue,
          onChanged: (val) {
            if (val != null) onSelected(val);
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((opt) => RadioListTile<T>(
              title: Text(labelBuilder(opt), style: GoogleFonts.cairo()),
              value: opt,
            )).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Icon(icon, color: AppColors.primaryBlue, size: 22),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.primaryBlue.withValues(alpha: 0.5),
      activeThumbColor: AppColors.primaryBlue,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.cairo(
          fontSize: 12,
          color: AppColors.textSecondary,
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
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.cairo(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_back_ios_rounded, size: 14, color: AppColors.primaryBlue),
          const SizedBox(width: 4),
          Text(
            trailingText,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
            ),
          ),
        ],
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
  }) {
    final color = isDestructive ? const Color(0xFFDC2626) : AppColors.textPrimary;
    
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.cairo(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      leading: hasArrow ? const Icon(Icons.arrow_back_ios_rounded, size: 14, color: AppColors.textSecondary) : null,
      trailing: Icon(icon, color: isDestructive ? color : AppColors.primaryBlue, size: 24),
    );
  }
}
