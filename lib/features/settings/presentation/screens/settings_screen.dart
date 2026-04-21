import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Mock states for switches
  bool _loadWhilePlaying = false;
  bool _pinLastSubject = false;
  bool _showMySolutions = true;

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
            Icons.menu_rounded, // in the image it had a menu, but back arrow is fine too. Let's use menu as mockup but pops.
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
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // ── Video Settings
          _buildSectionHeader('إعدادات الفيديو', Icons.videocam_rounded),
          _buildSwitchTile(
            title: 'تحميل أثناء التشغيل',
            subtitle: 'تحميل الفيديوهات تلقائياً أثناء تشغيلها',
            value: _loadWhilePlaying,
            onChanged: (v) => setState(() => _loadWhilePlaying = v),
          ),
          _buildSelectionTile(
            title: 'عدد التحميلات المتزامنة',
            subtitle: 'الحد الأقصى لعدد التحميلات التي تعمل في نفس الوقت: 1',
            trailingText: '1',
            icon: Icons.download_rounded,
          ),
          _buildSelectionTile(
            title: 'مقدار القفز في الفيديو',
            subtitle: 'مقدار القفز للأمام أو للخلف عند الضغط على أزرار القفز: 10 ثواني',
            trailingText: '10 ث',
            icon: Icons.fast_forward_rounded,
          ),
          const Divider(height: 32, indent: 20, endIndent: 20, color: AppColors.borderLight),

          // ── Data Management
          _buildSectionHeader('إدارة البيانات', Icons.storage_rounded),
          _buildActionTile(
            title: 'إعادة تحميل بيانات الأكواد',
            subtitle: 'جلب أحدث بيانات الأكواد من الخادم',
            icon: Icons.refresh_rounded,
          ),
          const Divider(height: 32, indent: 20, endIndent: 20, color: AppColors.borderLight),

          // ── Auto Update settings
          _buildSectionHeader('إعدادات التحديث التلقائي', Icons.update_rounded),
          _buildSelectionTile(
            title: 'فترة التحقق من التحديثات',
            subtitle: 'التحقق التلقائي من التحديثات كل 10 دقائق',
            trailingText: '10 د',
            icon: Icons.access_time_rounded,
          ),
          const Divider(height: 32, indent: 20, endIndent: 20, color: AppColors.borderLight),

          // ── Notes settings
          _buildSectionHeader('إعدادات الملاحظات', Icons.note_alt_rounded),
          _buildSelectionTile(
            title: 'مدة عرض الملاحظات',
            subtitle: 'مدة عرض ملاحظات الأسئلة وشرح الأسئلة وملاحظات الفيديو: 5 ثواني',
            trailingText: '5 ث',
            icon: Icons.speaker_notes_rounded,
          ),
          const Divider(height: 32, indent: 20, endIndent: 20, color: AppColors.borderLight),

          // ── Display settings
          _buildSectionHeader('إعدادات العرض', Icons.desktop_windows_rounded),
          _buildSwitchTile(
            title: 'تثبيت آخر مادة مفتوحة في الأعلى',
            subtitle: 'عرض آخر مادة تم فتحها في أعلى قائمة المواد',
            value: _pinLastSubject,
            onChanged: (v) => setState(() => _pinLastSubject = v),
          ),
          const Divider(height: 32, indent: 20, endIndent: 20, color: AppColors.borderLight),

          // ── User Data
          _buildSectionHeader('بيانات المستخدم', Icons.person_rounded),
          _buildSwitchTile(
            title: 'عرض حلولي والموضع الأخير',
            subtitle: 'عند الإيقاف: لا يتم استعادة موضعك الأخير في كل ورقة/علامة ولا يتم استعادة حلولك',
            value: _showMySolutions,
            onChanged: (v) => setState(() => _showMySolutions = v),
          ),
          _buildActionTile(
            title: 'حذف بيانات المستخدم لمادة محددة',
            subtitle: 'اختر مادة ونوع البيانات المراد حذفها',
            icon: Icons.delete_outline_rounded,
          ),
          _buildActionTile(
            title: 'حذف الحساب',
            subtitle: 'سيتم حذف حسابك وجميع البيانات المرتبطة به نهائياً. لا يمكن التراجع عن هذا الإجراء.',
            icon: Icons.person_off_rounded,
            isDestructive: true,
          ),
          _buildActionTile(
            title: 'نسخ معلومات الجهاز',
            subtitle: 'نسخ طراز الجهاز والنظام والمعرّفات للدعم الفني',
            icon: Icons.copy_rounded,
            hasArrow: false,
          ),
          const SizedBox(height: 40),
        ],
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
  }) {
    return ListTile(
      onTap: () {},
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
    bool isDestructive = false,
    bool hasArrow = true,
  }) {
    final color = isDestructive ? const Color(0xFFDC2626) : AppColors.textPrimary;
    
    return ListTile(
      onTap: () {},
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
