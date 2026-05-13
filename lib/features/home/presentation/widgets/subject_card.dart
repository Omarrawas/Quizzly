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
    
    final university = subject['universityName'] ?? 'الجامعة غير محددة';
    final college = subject['collegeName'] ?? 'الكلية غير محددة';
    final department = subject['departmentName'] ?? 'القسم غير محدد';
    final year = subject['yearName'] ?? 'السنة الدراسية غير محددة';
    final semester = subject['semesterName'] ?? 'الفصل غير محدد';

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
        margin: const EdgeInsets.only(bottom: 20),
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
            )
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon, Status, and Action Arrow
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                if (status == 'active' || status == 'demo')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          status == 'demo' ? 'ديمو' : 'مفعّل',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Subject Name & Code
            Text(
              name,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                subject['activationType'] == 'code' 
                    ? 'تفعيل بواسطة كود'
                    : (subject['activationType'] == 'free' || subject['price'] == 0 ? 'تفعيل مجاني' : (code == 'N/A' ? 'تفعيل مدفوع' : 'كود المادة: $code')),
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
            const SizedBox(height: 16),
            
            // Detailed Information Rows
            _buildInfoRow(Icons.account_balance_rounded, '$university  •  $college'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.category_rounded, '$department  •  $year'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.calendar_month_rounded, semester),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.cairo(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
