import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quizzly/core/theme/app_colors.dart';

class ReportsManagementScreen extends StatefulWidget {
  final String? subjectId;
  const ReportsManagementScreen({super.key, this.subjectId});

  @override
  State<ReportsManagementScreen> createState() => _ReportsManagementScreenState();
}

class _ReportsManagementScreenState extends State<ReportsManagementScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _showResolved = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'بلاغات المستخدمين',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
      ),
      body: Column(
        children: [
          // Premium Segmented Control Tabs
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showResolved = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_showResolved ? (isDark ? const Color(0xFF334155) : Colors.white) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: !_showResolved
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          'البلاغات الواردة',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: !_showResolved ? AppColors.primaryBlue : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showResolved = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _showResolved ? (isDark ? const Color(0xFF334155) : Colors.white) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _showResolved
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          'البلاغات المعالجة',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _showResolved ? AppColors.primaryBlue : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Stream Builder for Reports List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.subjectId != null
                  ? _db.collection('question_reports')
                      .where('subjectId', isEqualTo: widget.subjectId)
                      .snapshots()
                  : _db.collection('question_reports')
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('حدث خطأ: ${snapshot.error}', style: GoogleFonts.cairo()));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allReports = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);
                
                // Sort client-side by createdAt descending
                allReports.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['createdAt'] as Timestamp?;
                  final bTime = bData['createdAt'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });
                
                // Client-side filter based on status
                final reports = allReports.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'pending';
                  final isResolved = status == 'resolved';
                  return _showResolved ? isResolved : !isResolved;
                }).toList();

                if (reports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showResolved ? Icons.playlist_add_check_rounded : Icons.mark_email_read_outlined, 
                          size: 64, 
                          color: AppColors.textSecondary.withValues(alpha: 0.3)
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showResolved ? 'لا توجد بلاغات معالجة' : 'لا توجد بلاغات واردة حالياً',
                          style: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      questionNumber: report['questionNumber']?.toString() ?? report['questionId'] ?? 'N/A',
                      questionText: report['questionText'] ?? '',
                      tagLabel: report['tagLabel'] ?? '',
                      topicNames: (report['topicNames'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
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
          ),
        ],
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
  final String questionNumber;
  final String questionText;
  final String tagLabel;
  final List<String> topicNames;
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
    required this.questionNumber,
    required this.questionText,
    required this.tagLabel,
    required this.topicNames,
    required this.type,
    required this.details,
    required this.userEmail,
    required this.date,
    required this.status,
    required this.onDelete,
    required this.onResolve,
  });

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .trim();
  }

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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: Colors.white10) : null,
        boxShadow: isDark ? [] : [
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
                  'سؤال #$questionNumber',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
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
                if (tagLabel.isNotEmpty || topicNames.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (tagLabel.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(tagLabel, style: GoogleFonts.cairo(fontSize: 11, color: Colors.purple)),
                        ),
                      for (final topic in topicNames)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(topic, style: GoogleFonts.cairo(fontSize: 11, color: Colors.teal)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (questionText.isNotEmpty) ...[
                  Text(
                    'نص السؤال:',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _stripHtml(questionText),
                    style: GoogleFonts.cairo(fontSize: 14, color: isDark ? Colors.white : AppColors.textPrimary),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'تفاصيل البلاغ:',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  details.isEmpty ? '(لا توجد تفاصيل)' : details,
                  style: GoogleFonts.cairo(fontSize: 14, color: isDark ? Colors.white70 : AppColors.textPrimary),
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
