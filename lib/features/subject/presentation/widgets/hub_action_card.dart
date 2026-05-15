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
  final bool showBadge;

  const HubAction({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.iconBackground,
    this.badgeCount = 0,
    this.showBadge = true,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
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
            if (action.showBadge && action.badgeCount > 0)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: action.iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${action.badgeCount}',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: action.iconColor,
                      ),
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
                      color: isDark ? Colors.white : AppColors.textPrimary,
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

