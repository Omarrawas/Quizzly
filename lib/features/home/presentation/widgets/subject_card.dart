import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';

class SubjectCard extends StatelessWidget {
  final Map<String, dynamic> subject;
  final VoidCallback onTap;

  const SubjectCard({
    super.key,
    required this.subject,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = subject['name'] ?? 'مادة غير معروفة';
    final code = subject['code'] ?? '';
    final status = subject['status'] ?? 'locked'; // active, demo, locked
    
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
                  color: _getIconBackground(status),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.book_rounded,
                  size: 36,
                  color: _getIconColor(status),
                ),
              ),
              const SizedBox(width: 16),

              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.cairo(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'كود المادة: $code',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildStatusBadge(status),
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

  Widget _buildStatusBadge(String status) {
    switch (status) {
      case 'demo':
        return _badge('ديمو', const Color(0xFF16A34A), const Color(0xFFDCFCE7));
      case 'active':
        return _badge('مفعّل', AppColors.primaryBlue, const Color(0xFFDBEAFE));
      case 'locked':
      default:
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

  Color _getIconBackground(String status) {
    switch (status) {
      case 'demo':
        return const Color(0xFFF0FDF4);
      case 'active':
        return const Color(0xFFEFF6FF);
      case 'locked':
      default:
        return const Color(0xFFF9FAFB);
    }
  }

  Color _getIconColor(String status) {
    switch (status) {
      case 'demo':
        return const Color(0xFF16A34A);
      case 'active':
        return AppColors.primaryBlue;
      case 'locked':
      default:
        return const Color(0xFF9CA3AF);
    }
  }
}
