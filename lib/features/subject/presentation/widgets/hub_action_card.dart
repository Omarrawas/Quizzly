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
//  Widget: بطاقة الزر مع الـ Badge
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Main Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon Circle
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: action.iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    action.icon,
                    size: 36,
                    color: action.iconColor,
                  ),
                ),
                const SizedBox(height: 14),
                // Label
                Text(
                  action.label,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // ── Badge in top-right corner (RTL: top-start)
          if (action.badgeCount > 0)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  action.badgeCount > 99 ? '99+' : '${action.badgeCount}',
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
