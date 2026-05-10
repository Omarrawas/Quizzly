import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SubjectCard extends StatelessWidget {
  final Map<String, dynamic> subject;
  final VoidCallback onTap;
  final int index;

  const SubjectCard({
    super.key,
    required this.subject,
    required this.onTap,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final name = subject['name'] ?? 'مادة غير معروفة';
    final code = subject['code'] ?? 'N/A';
    final status = subject['status'] ?? 'active';

    final vibrantColors = [
      (const Color(0xFF4F46E5), const Color(0xFF818CF8)), // Indigo
      (const Color(0xFFE11D48), const Color(0xFFFB7185)), // Rose
      (const Color(0xFF0D9488), const Color(0xFF2DD4BF)), // Teal
      (const Color(0xFFD97706), const Color(0xFFFBBF24)), // Amber
      (const Color(0xFF0284C7), const Color(0xFF38BDF8)), // Sky
      (const Color(0xFF7C3AED), const Color(0xFFA78BFA)), // Violet
    ];
    final (colorMain, colorLight) = vibrantColors[index % vibrantColors.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorMain, colorLight],
            begin: Alignment.bottomRight,
            end: Alignment.topLeft,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colorMain.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon & Action arrow
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Title
            Text(
              name,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Subtitle (Code + Status info)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    code,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Spacer(),
                if (status == 'active' || status == 'demo')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status == 'demo' ? 'ديمو' : 'مفعّل',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
