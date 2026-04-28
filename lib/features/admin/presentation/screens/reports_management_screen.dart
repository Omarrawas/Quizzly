import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quizzly/core/theme/app_colors.dart';

class ReportsManagementScreen extends StatefulWidget {
  const ReportsManagementScreen({super.key});

  @override
  State<ReportsManagementScreen> createState() => _ReportsManagementScreenState();
}

class _ReportsManagementScreenState extends State<ReportsManagementScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'بلاغات المستخدمين',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('question_reports').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data?.docs ?? [];

          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mark_email_read_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد بلاغات حالياً',
                    style: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index].data() as Map<String, dynamic>;
              final reportId = reports[index].id;
              final timestamp = report['createdAt'] as Timestamp?;
              final dateStr = timestamp != null 
                  ? intl.DateFormat('yyyy/MM/dd - hh:mm a').format(timestamp.toDate())
                  : 'غير متوفر';

              return _ReportCard(
                reportId: reportId,
                questionId: report['questionId'] ?? 'N/A',
                type: report['type'] ?? 'غير محدد',
                details: report['details'] ?? '',
                userEmail: report['userEmail'] ?? 'anonymous',
                date: dateStr,
                status: report['status'] ?? 'pending',
                onDelete: () => _deleteReport(reportId),
                onResolve: () => _resolveReport(reportId),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteReport(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('حذف البلاغ', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من حذف هذا البلاغ؟', style: GoogleFonts.cairo()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء', style: GoogleFonts.cairo())),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('حذف', style: GoogleFonts.cairo(color: Colors.red)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await _db.collection('question_reports').doc(id).delete();
    }
  }

  Future<void> _resolveReport(String id) async {
    await _db.collection('question_reports').doc(id).update({'status': 'resolved'});
  }
}

class _ReportCard extends StatelessWidget {
  final String reportId;
  final String questionId;
  final String type;
  final String details;
  final String userEmail;
  final String date;
  final String status;
  final VoidCallback onDelete;
  final VoidCallback onResolve;

  const _ReportCard({
    required this.reportId,
    required this.questionId,
    required this.type,
    required this.details,
    required this.userEmail,
    required this.date,
    required this.status,
    required this.onDelete,
    required this.onResolve,
  });

  Color _getTypeColor() {
    switch (type) {
      case 'خطأ في الإجابة': return Colors.red;
      case 'خطأ إملائي': return Colors.orange;
      case 'استفسار عن السؤال': return Colors.blue;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isResolved = status == 'resolved';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getTypeColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    type,
                    style: GoogleFonts.cairo(
                      color: _getTypeColor(),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  'سؤال #$questionId',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'التفاصيل:',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  details.isEmpty ? '(لا توجد تفاصيل)' : details,
                  style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textPrimary),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        userEmail,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      date,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  label: Text('حذف', style: GoogleFonts.cairo(color: Colors.red, fontSize: 13)),
                ),
                const Spacer(),
                if (!isResolved)
                  ElevatedButton.icon(
                    onPressed: onResolve,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text('تمت المعالجة', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
                      const SizedBox(width: 4),
                      Text(
                        'تمت مراجعتها',
                        style: GoogleFonts.cairo(color: const Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
