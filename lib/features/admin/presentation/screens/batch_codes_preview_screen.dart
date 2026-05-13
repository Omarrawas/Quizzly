import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:intl/intl.dart' as intl;
import 'package:qr_flutter/qr_flutter.dart';

class BatchCodesPreviewScreen extends StatefulWidget {
  final String batchName;
  final int durationDays;
  final int quantity;

  const BatchCodesPreviewScreen({
    super.key,
    required this.batchName,
    required this.durationDays,
    required this.quantity,
  });

  @override
  State<BatchCodesPreviewScreen> createState() =>
      _BatchCodesPreviewScreenState();
}

class _BatchCodesPreviewScreenState extends State<BatchCodesPreviewScreen> {
  final DatabaseService _dbService = DatabaseService();
  String _filter = 'all';

  // ── Duration picker dialog ──────────────────────────────
  Future<void> _showDurationDialog(String codeId, int currentDays) async {
    int selected = currentDays;
    final options = [7, 14, 30, 60, 90, 120, 180, 365];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('تعديل المدة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('اختر مدة الاشتراك بالأيام:',
                  style: GoogleFonts.cairo(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.map((days) {
                  final isSelected = selected == days;
                  return GestureDetector(
                    onTap: () => setInner(() => selected = days),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryBlue
                            : AppColors.cardLightBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$days يوم',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.primaryBlue,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await _dbService.updateCodeDuration(codeId, selected);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تحديث المدة إلى $selected يوم',
                          style: GoogleFonts.cairo()),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
              child: Text('حفظ', style: GoogleFonts.cairo(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Toggle activation ───────────────────────────────────
  Future<void> _toggleActivation(
      String codeId, bool currentlyUsed) async {
    final action = currentlyUsed ? 'إعادة تنشيط' : 'تعطيل يدوي';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$action الكود',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Text(
          currentlyUsed
              ? 'هل تريد إعادة الكود إلى حالة "نشط"؟'
              : 'هل تريد تعيين الكود كـ"مستخدم" (تعطيله يدويًا)؟',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  currentlyUsed ? AppColors.iconGreen : Colors.orange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(currentlyUsed ? 'تنشيط' : 'تعطيل',
                style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dbService.toggleCodeActivation(codeId,
          markAsUsed: !currentlyUsed);
    }
  }

  // ── Delete single code ──────────────────────────────────
  Future<void> _deleteCode(String codeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('حذف الكود',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Text('هل أنت متأكد من حذف الكود "$codeId"؟',
            style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text('حذف', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dbService.deleteCode(codeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف الكود', style: GoogleFonts.cairo()),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // ── Show Preview Ticket ──────────────────────────────
  Future<void> _showPreviewDialog(Map<String, dynamic> data) async {
    final String code = data['code']?.toString() ?? 'N/A';
    final List<String> subjectIds = (data['subjectIds'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final int duration = (data['durationDays'] as int?) ?? widget.durationDays;
    final String batchName = data['batchName']?.toString() ?? widget.batchName;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        content: Container(
          width: 320,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ticket Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Image.asset('assets/images/logo.png', height: 40),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quizzly Activation',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        Text(
                          'معاينة كود التفعيل',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Ticket Content (QR & Code)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // QR Code Container
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          QrImageView(
                            data: code,
                            version: QrVersions.auto,
                            size: 180,
                            errorCorrectionLevel: QrErrorCorrectLevel.H,
                          ),
                          Container(
                            width: 35,
                            height: 35,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Image.asset('assets/images/logo.png'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Code Text
                    Text(
                      code,
                      style: GoogleFonts.sourceCodePro(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Batch: $batchName • $duration Days',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Separator (Dash Line)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: List.generate(
                    15,
                    (index) => Expanded(
                      child: Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        color: AppColors.borderLight,
                      ),
                    ),
                  ),
                ),
              ),

              // Subjects List
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المحتوى المفعل:',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<String>>(
                      future: _fetchSubjectNames(subjectIds),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ));
                        }
                        final names = snapshot.data ?? ['خطأ في التحميل'];
                        return Column(
                          children: names.map((name) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, 
                                  size: 14, color: Colors.green),
                                const SizedBox(width: 8),
                                Expanded(child: Text(name, 
                                  style: GoogleFonts.cairo(fontSize: 13))),
                              ],
                            ),
                          )).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Action
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('إغلاق', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<String>> _fetchSubjectNames(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection(DatabaseService.colSubjects)
          .where(FieldPath.documentId, whereIn: ids)
          .get();
      return snap.docs.map((d) => d.get('name') as String? ?? 'بدون اسم').toList();
    } catch (e) {
      return ['خطأ في تحميل البيانات'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(widget.batchName,
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              '${widget.quantity} كود • ${widget.durationDays} يوم',
              style:
                  GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // ── Filter Bar ──────────────────────────────────
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _FilterChip(
                  label: 'الكل',
                  icon: Icons.apps_rounded,
                  selected: _filter == 'all',
                  color: AppColors.primaryBlue,
                  onTap: () => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'نشط',
                  icon: Icons.check_circle_outline_rounded,
                  selected: _filter == 'active',
                  color: AppColors.iconGreen,
                  onTap: () => setState(() => _filter = 'active'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'مستخدم',
                  icon: Icons.person_rounded,
                  selected: _filter == 'used',
                  color: Colors.orange,
                  onTap: () => setState(() => _filter = 'used'),
                ),
              ],
            ),
          ),

          // ── Codes List ──────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  _dbService.streamActivationCodesByBatch(widget.batchName),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('خطأ: ${snapshot.error}',
                          style: GoogleFonts.cairo(color: Colors.red)));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs;
                final allDocs = docs;

                if (_filter == 'active') {
                  docs = docs
                      .where((d) =>
                          d.get('isUsed') == false)
                      .toList();
                } else if (_filter == 'used') {
                  docs = docs
                      .where((d) =>
                          d.get('isUsed') == true)
                      .toList();
                }

                final usedCount = allDocs
                    .where((d) =>
                        d.get('isUsed') == true)
                    .length;
                final activeCount = allDocs.length - usedCount;

                return Column(
                  children: [
                    // Stats row
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          _StatBadge(
                              label: 'نشط',
                              count: activeCount,
                              color: AppColors.iconGreen,
                              bgColor: AppColors.cardLightGreen),
                          const SizedBox(width: 10),
                          _StatBadge(
                              label: 'مستخدم',
                              count: usedCount,
                              color: Colors.orange,
                              bgColor: AppColors.cardLightOrange),
                          const SizedBox(width: 10),
                          _StatBadge(
                              label: 'الإجمالي',
                              count: allDocs.length,
                              color: AppColors.primaryBlue,
                              bgColor: AppColors.cardLightBlue),
                        ],
                      ),
                    ),

                    if (docs.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded,
                                  size: 56,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              Text('لا توجد أكواد تطابق الفلتر',
                                  style: GoogleFonts.cairo(
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data =
                                doc.data() as Map<String, dynamic>;
                            final docId = doc.id;
                            return _CodeTile(
                              data: data,
                              docId: docId,
                              index: index + 1,
                              onToggle: () => _toggleActivation(
                                  docId, data['isUsed'] == true),
                              onEditDuration: () => _showDurationDialog(
                                  docId,
                                  (data['durationDays'] as int?) ??
                                      widget.durationDays),
                              onDelete: () => _deleteCode(docId),
                              onPreview: () => _showPreviewDialog(data),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Code Tile ────────────────────────────────────────────

class _CodeTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final int index;
  final VoidCallback onToggle;
  final VoidCallback onEditDuration;
  final VoidCallback onDelete;
  final VoidCallback onPreview;

  const _CodeTile({
    required this.data,
    required this.docId,
    required this.index,
    required this.onToggle,
    required this.onEditDuration,
    required this.onDelete,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUsed = data['isUsed'] == true;
    final code = data['code'] as String? ?? docId;
    final usedBy = data['usedBy'] as String?;
    final usedAt = (data['usedAt'] as Timestamp?)?.toDate();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final durationDays = (data['durationDays'] as int?) ?? 0;
    final List subjectIds = data['subjectIds'] as List? ?? [];
    final int subjectsCount = subjectIds.length;

    String typeLabel = 'كود مادة';
    Color typeColor = AppColors.primaryBlue;

    if (subjectsCount > 1) {
      typeLabel = 'كود باقة ($subjectsCount مواد)';
      typeColor = Colors.purple;
    }

    DateTime? expiresAt;
    if (isUsed && usedAt != null) {
      expiresAt = usedAt.add(Duration(days: durationDays));
    }
    final isExpired =
        expiresAt != null && expiresAt.isBefore(DateTime.now());

    final Color statusColor = isExpired
        ? Colors.red
        : isUsed
            ? Colors.orange
            : AppColors.iconGreen;

    final String statusLabel =
        isExpired ? 'منتهي' : isUsed ? 'مستخدم' : 'نشط';

    final IconData statusIcon = isExpired
        ? Icons.cancel_rounded
        : isUsed
            ? Icons.person_rounded
            : Icons.check_circle_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: statusColor.withValues(alpha: 0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top: code info ────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Index circle
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Code & meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            code,
                            style: GoogleFonts.sourceCodePro(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تم نسخ: $code',
                                      style: GoogleFonts.cairo()),
                                  duration:
                                      const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                              );
                            },
                            child: Icon(Icons.copy_rounded,
                                size: 18,
                                color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 12),
                          // Type Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: typeColor.withValues(alpha: 0.3),
                                  width: 0.8),
                            ),
                            child: Text(
                              typeLabel,
                              style: GoogleFonts.cairo(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: typeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Duration
                      Row(
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 12,
                              color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Text('$durationDays يوم',
                              style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                      if (isUsed && usedBy != null) ...[
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded,
                                size: 12,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(usedBy,
                                  style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                        if (usedAt != null)
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded,
                                  size: 12,
                                  color: AppColors.textSecondary),
                              const SizedBox(width: 3),
                              Text(
                                'استُخدم: ${intl.DateFormat('yyyy/MM/dd').format(usedAt)}',
                                style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                              if (expiresAt != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '• ينتهي: ${intl.DateFormat('yyyy/MM/dd').format(expiresAt)}',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    color: isExpired
                                        ? Colors.red
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                      ] else if (createdAt != null)
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 12,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 3),
                            Text(
                              'أُنشئ: ${intl.DateFormat('yyyy/MM/dd').format(createdAt)}',
                              style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusLabel,
                          style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ───────────────────────────────────
          Divider(
              height: 1,
              color: AppColors.borderLight.withValues(alpha: 0.5)),

          // ── Action buttons row ────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Wrap(
              alignment: WrapAlignment.start,
              children: [
                // Preview
                _ActionBtn(
                  icon: Icons.visibility_outlined,
                  label: 'معاينة',
                  color: AppColors.primaryBlue,
                  onTap: onPreview,
                ),
                // Toggle activation
                _ActionBtn(
                  icon: isUsed
                      ? Icons.lock_open_rounded
                      : Icons.person_add_disabled_rounded,
                  label: isUsed ? 'إعادة تنشيط' : 'تعطيل يدوي',
                  color:
                      isUsed ? AppColors.iconGreen : Colors.orange,
                  onTap: onToggle,
                ),
                // Edit duration
                _ActionBtn(
                  icon: Icons.timer_outlined,
                  label: 'تعديل المدة',
                  color: AppColors.primaryBlue,
                  onTap: onEditDuration,
                ),
                // Delete
                _ActionBtn(
                  icon: Icons.delete_outline_rounded,
                  label: 'حذف',
                  color: Colors.red,
                  onTap: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small action button ───────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding:
              const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, size: 14, color: color),
        label: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : AppColors.borderLight,
              width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color:
                    selected ? color : AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat Badge ────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color bgColor;

  const _StatBadge({
    required this.label,
    required this.count,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text('$count',
                style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style:
                    GoogleFonts.cairo(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}
