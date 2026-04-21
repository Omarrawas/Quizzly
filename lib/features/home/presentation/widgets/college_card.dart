import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/home/data/models/college_model.dart';

class CollegeCard extends StatelessWidget {
  final CollegeModel college;
  final VoidCallback onTap;

  const CollegeCard({
    super.key,
    required this.college,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _getIconBackground(),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  college.icon,
                  size: 36,
                  color: _getIconColor(),
                ),
              ),
              const SizedBox(width: 16),

              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      college.name,
                      style: GoogleFonts.cairo(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      college.subtitle,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${college.subjectCount} مواد',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildStatusBadge(),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow Icon
              Icon(
                Icons.arrow_back_ios_rounded,
                size: 16,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    switch (college.status) {
      case SubscriptionStatus.demo:
        return _badge('ديمو', const Color(0xFF16A34A), const Color(0xFFDCFCE7));
      case SubscriptionStatus.active:
        return _badge('مفعّل', AppColors.primaryBlue, const Color(0xFFDBEAFE));
      case SubscriptionStatus.locked:
        return _badge('مقفل', const Color(0xFF9CA3AF), const Color(0xFFF3F4F6));
    }
  }

  Widget _badge(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: textColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getIconBackground() {
    switch (college.status) {
      case SubscriptionStatus.demo:
        return const Color(0xFFF0FDF4);
      case SubscriptionStatus.active:
        return const Color(0xFFEFF6FF);
      case SubscriptionStatus.locked:
        return const Color(0xFFF9FAFB);
    }
  }

  Color _getIconColor() {
    switch (college.status) {
      case SubscriptionStatus.demo:
        return const Color(0xFF16A34A);
      case SubscriptionStatus.active:
        return AppColors.primaryBlue;
      case SubscriptionStatus.locked:
        return const Color(0xFF9CA3AF);
    }
  }
}
