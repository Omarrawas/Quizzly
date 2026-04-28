import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';

/// بيانات كل زر في شبكة لوحة تحكم المادة
class HubAction {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBackground;
  final int badgeCount;

  const HubAction({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.iconBackground,
    this.badgeCount = 0,
  });
}

// ─────────────────────────────────────────
//  Widget: بطاقة الزر مع الـ Badge (التصميم المربع المحدث)
// ─────────────────────────────────────────
class HubActionCard extends StatelessWidget {
  final HubAction action;
  final VoidCallback onTap;

  const HubActionCard({
    super.key,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ── Badge in top-left (RTL: top-start)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF60A5FA).withValues(alpha: 0.6), // Light blue from image
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${action.badgeCount}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1D4ED8), // Darker blue from image
                  ),
                ),
              ),
            ),

            // ── Main Content (Icon and Label)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon Circle
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: action.iconBackground,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: action.iconBackground.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      action.icon,
                      size: 32,
                      color: action.iconColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Label
                  Text(
                    action.label,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
