import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';

class MyDataScreen extends StatelessWidget {
  const MyDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(
            Icons.arrow_forward_ios_rounded,
            color: isDark ? Colors.white : AppColors.textPrimary,
            size: 20,
          ),
        ),
        title: Text(
          'بياناتي',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildInfoCard(isDark),
          const SizedBox(height: 16),
          _buildMigrationCard(isDark),
          const SizedBox(height: 16),
          _buildExportCard(isDark),
          const SizedBox(height: 16),
          _buildImportCard(isDark),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return _buildCardWrapper(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_rounded, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'معلومات',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'يمكنك تصدير بياناتك كملف JSON أو مزامنتها مع السيرفر. المزامنة التلقائية تقارن الإصدارات وتحدد ما إذا كان يجب الرفع أو السحب.',
            style: GoogleFonts.cairo(
              fontSize: 13, 
              color: isDark ? Colors.white70 : AppColors.textSecondary
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'أمثلة على البيانات المتزامنة:',
            style: GoogleFonts.cairo(
              fontSize: 13, 
              fontWeight: FontWeight.bold, 
              color: isDark ? Colors.white : AppColors.textPrimary
            ),
          ),
          const SizedBox(height: 8),
          _buildBulletPoint(Icons.favorite_rounded, 'المفضلة (الأسئلة والفيديوهات)', isDark),
          _buildBulletPoint(Icons.note_alt_rounded, 'الملاحظات الشخصية', isDark),
          _buildBulletPoint(Icons.check_circle_rounded, 'الإجابات والتقييمات', isDark),
          _buildBulletPoint(Icons.visibility_rounded, 'حالة المشاهدة والدراسة', isDark),
          _buildBulletPoint(Icons.play_circle_filled_rounded, 'موضع التشغيل في الفيديوهات', isDark),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primaryBlue),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 13, 
              color: isDark ? Colors.white60 : AppColors.textSecondary
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMigrationCard(bool isDark) {
    return _buildCardWrapper(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'الانتقال من بيتا القديم',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'انقل أكواد التفعيل ونسخة احتياطية اختيارية من تطبيق بيتا الكلاسيكي عبر معالج خطوة بخطوة.',
            style: GoogleFonts.cairo(
              fontSize: 13, 
              color: isDark ? Colors.white70 : AppColors.textSecondary
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 20),
              label: Text(
                'بدء معالج الانتقال',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildExportCard(bool isDark) {
    return _buildCardWrapper(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.file_download_outlined, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'تصدير البيانات',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'قم بتصدير بياناتك إلى ملف، أو رفعها إلى سيرفر BetaPlus للنسخ الاحتياطي.',
            style: GoogleFonts.cairo(
              fontSize: 13, 
              color: isDark ? Colors.white70 : AppColors.textSecondary
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.insert_drive_file_outlined, color: Colors.white, size: 20),
              label: Text(
                'تصدير إلى ملف',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'احفظ بياناتك كملف JSON على جهازك.',
              style: GoogleFonts.cairo(
                fontSize: 11, 
                color: isDark ? Colors.white38 : AppColors.textSecondary
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.cloud_upload_outlined, color: AppColors.primaryBlue, size: 20),
              label: Text(
                'تصدير إلى سيرفر BetaPlus',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: isDark ? Colors.white10 : AppColors.borderLight),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'ارفع بياناتك إلى سيرفر BetaPlus للنسخ الاحتياطي السحابي.',
              style: GoogleFonts.cairo(
                fontSize: 11, 
                color: isDark ? Colors.white38 : AppColors.textSecondary
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportCard(bool isDark) {
    return _buildCardWrapper(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.file_upload_outlined, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'استيراد البيانات',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'استورد البيانات من ملف، أو قم بتنزيلها من سيرفر BetaPlus.',
            style: GoogleFonts.cairo(
              fontSize: 13, 
              color: isDark ? Colors.white70 : AppColors.textSecondary
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.insert_drive_file_outlined, color: Colors.white, size: 20),
              label: Text(
                'استيراد من ملف',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'استورد البيانات من ملف JSON على جهازك.',
              style: GoogleFonts.cairo(
                fontSize: 11, 
                color: isDark ? Colors.white38 : AppColors.textSecondary
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.cloud_download_outlined, color: AppColors.primaryBlue, size: 20),
              label: Text(
                'استيراد من سيرفر BetaPlus',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: isDark ? Colors.white10 : AppColors.borderLight),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardWrapper({required Widget child, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
