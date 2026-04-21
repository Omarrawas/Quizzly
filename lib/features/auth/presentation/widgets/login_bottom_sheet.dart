import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/home/presentation/screens/home_screen.dart';

class LoginBottomSheet extends StatelessWidget {
  const LoginBottomSheet({super.key});

  void _onStart(BuildContext context) {
    // For now, navigate directly to HomeScreen
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 32,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),

          // Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.cardLightRed,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.manage_accounts_rounded,
              color: AppColors.iconRed,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            'تسجيل الدخول بجوجل',
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ بسرعة عبر جوجل أو Apple أو رابط البريد.',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Benefits list
          _buildBenefitItem('استخدم حسابك الحالي للدخول بسرعة.'),
          _buildBenefitItem('تحافظ على تجربة مرتبطة بحسابك.'),
          _buildBenefitItem('تسجيل الدخول عبر Apple متاح أيضاً.'),

          const SizedBox(height: 40),

          // Start Button
          ElevatedButton(
            onPressed: () => _onStart(context),
            child: const Text('ابدأ'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.iconRed,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void showLoginBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const LoginBottomSheet(),
  );
}
