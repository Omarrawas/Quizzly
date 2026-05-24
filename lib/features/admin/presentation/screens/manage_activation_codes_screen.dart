import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/admin/presentation/screens/batch_codes_preview_screen.dart';
import 'package:quizzly/features/admin/presentation/widgets/generate_codes_dialog.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ManageActivationCodesScreen extends StatefulWidget {
  const ManageActivationCodesScreen({super.key});

  @override
  State<ManageActivationCodesScreen> createState() =>
      _ManageActivationCodesScreenState();
}

class _ManageActivationCodesScreenState
    extends State<ManageActivationCodesScreen> {
  final DatabaseService _dbService = DatabaseService();

  Future<void> _printBatch(String batchName) async {
    try {
      final codes = await _dbService.getActivationCodesByBatch(batchName);
      if (codes.isEmpty) return;

      // Load fonts and logo for PDF
      final arabicFont = pw.Font.ttf(
        await rootBundle.load("assets/fonts/Cairo-Regular.ttf"),
      );
      final arabicFontBold = pw.Font.ttf(
        await rootBundle.load("assets/fonts/Cairo-Bold.ttf"),
      );
      final logoImage = pw.MemoryImage(
        (await rootBundle.load("assets/images/logo.png")).buffer.asUint8List(),
      );

      final pdf = pw.Document();

      // 3x3 grid (9 per page) to allow for HUGE, detailed vertical tickets
      // This ensures nothing gets clipped and matches the preview perfectly
      const codesPerPage = 9;

      for (int i = 0; i < codes.length; i += codesPerPage) {
        final pageCodes = codes.sublist(
          i,
          (i + codesPerPage).clamp(0, codes.length),
        );

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            theme: pw.ThemeData.withFont(
              base: arabicFont,
              bold: arabicFontBold,
            ),
            build: (pw.Context context) {
              // Creating a manual grid with fixed sizes to ensure vertical ticket look
              const int cols = 3;
              final List<List<Map<String, dynamic>>> rows = [];
              for (int j = 0; j < pageCodes.length; j += cols) {
                rows.add(pageCodes.sublist(
                  j,
                  (j + cols).clamp(0, pageCodes.length),
                ));
              }

              return pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  children: rows.map((rowCodes) {
                    return pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: rowCodes.map((code) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 15),
                          child: pw.SizedBox(
                            width: 180, // Fixed width
                            height: 240, // Height reduced to fit 3rd row
                            child: _buildQrCell(code, arabicFontBold, logoImage),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        );
      }

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Batch_$batchName.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في الطباعة: $e')));
      }
    }
  }

  pw.Widget _buildQrCell(
    Map<String, dynamic> codeData,
    pw.Font boldFont,
    pw.ImageProvider logo,
  ) {
    final String code = codeData['code']?.toString() ?? 'N/A';
    final int creditValue = (codeData['creditValue'] as int?) ?? 0;
    final String batchName = codeData['batchName']?.toString() ?? '-';
    final int duration = (codeData['durationDays'] as int?) ?? 0;

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        border: pw.Border.all(color: PdfColors.blue200, width: 0.8),
      ),
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(12),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // Branding - Moved inside to save vertical space
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Image(logo, width: 14, height: 14),
                pw.SizedBox(width: 6),
                pw.Text('Quizzly Activation',
                    style: pw.TextStyle(fontSize: 9, font: boldFont, color: PdfColors.blue900)),
              ],
            ),
            
            // Amount
            pw.Text(
              '$creditValue ل.س',
              style: pw.TextStyle(fontSize: 22, font: boldFont, color: PdfColors.blue800),
            ),
            
            // QR
            pw.Stack(
              alignment: pw.Alignment.center,
              children: [
                pw.BarcodeWidget(
                  data: code,
                  barcode: pw.Barcode.qrCode(),
                  width: 95, // Increased since we have more space now
                  height: 95,
                  color: PdfColors.black,
                  drawText: false,
                ),
                pw.Container(
                  width: 18,
                  height: 18,
                  padding: const pw.EdgeInsets.all(1),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Image(logo),
                ),
              ],
            ),
            
            // Code & Batch Info
            pw.Column(
              children: [
                pw.Text(
                  code,
                  style: pw.TextStyle(fontSize: 18, font: boldFont, letterSpacing: 2.5),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Batch: $batchName • $duration Days',
                  style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBatch(String batchName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تأكيد الحذف',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'هل أنت متأكد من حذف المجموعة "$batchName" وجميع أكوادها؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dbService.deleteActivationBatch(batchName);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حذف المجموعة بنجاح')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'إدارة مجموعات الأكواد',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _dbService.getBatches(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final batches = snapshot.data!.docs;
          if (batches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.vpn_key_outlined,
                    size: 64,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد مجموعات أكواد حالياً',
                    style: GoogleFonts.cairo(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: batches.length,
            itemBuilder: (context, index) {
              final data = batches[index].data() as Map<String, dynamic>;
              final name = data['name'] ?? 'بدون اسم';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final quantity = (data['quantity'] as int?) ?? 0;
              final duration = (data['durationDays'] as int?) ?? 0;
              final creditValue = (data['creditValue'] as int?) ?? 0;

              return _BatchCard(
                key: ValueKey(name),
                name: name,
                createdAt: createdAt,
                quantity: quantity,
                duration: duration,
                creditValue: creditValue,
                onPrint: () => _printBatch(name),
                onDelete: () => _deleteBatch(name),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BatchCodesPreviewScreen(
                      batchName: name,
                      durationDays: duration,
                      quantity: quantity,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const GenerateCodesDialog(),
          );
        },
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'توليد أكواد جديدة',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Batch Card with live stats ────────────────────────────────────────────────
class _BatchCard extends StatelessWidget {
  final String name;
  final DateTime? createdAt;
  final int quantity;
  final int duration;
  final int creditValue;
  final VoidCallback onPrint;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _BatchCard({
    super.key,
    required this.name,
    required this.createdAt,
    required this.quantity,
    required this.duration,
    required this.creditValue,
    required this.onPrint,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('activation_codes')
          .where('batchName', isEqualTo: name)
          .snapshots(),
      builder: (context, snap) {
        int activeCount = 0;
        int usedCount = 0;
        DateTime? earliestExpiry;

        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;
            final isUsed = d['isUsed'] == true;
            if (isUsed) {
              usedCount++;
              // Expiry = usedAt + durationDays
              final usedAt = (d['usedAt'] as Timestamp?)?.toDate();
              final days = (d['durationDays'] as int?) ?? duration;
              if (usedAt != null) {
                final exp = usedAt.add(Duration(days: days));
                if (earliestExpiry == null || exp.isBefore(earliestExpiry)) {
                  earliestExpiry = exp;
                }
              }
            } else {
              activeCount++;
            }
          }
        }

        final totalCount = activeCount + usedCount;
        final hasData = snap.hasData;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ──────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.payments_rounded,
                            color: AppColors.primaryBlue, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_rounded,
                                    size: 11, color: AppColors.textSecondary),
                                const SizedBox(width: 3),
                                Text(
                                  intl.DateFormat('yyyy/MM/dd')
                                      .format(createdAt ?? DateTime.now()),
                                  style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                                const SizedBox(width: 10),
                                Icon(Icons.monetization_on_outlined,
                                    size: 11, color: AppColors.primaryBlue),
                                const SizedBox(width: 3),
                                Text(
                                  '$creditValue ل.س',
                                  style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryBlue),
                                ),
                                const SizedBox(width: 10),
                                Icon(Icons.timer_outlined,
                                    size: 11, color: AppColors.textSecondary),
                                const SizedBox(width: 3),
                                Text(
                                  '$duration يوم',
                                  style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Actions
                      IconButton(
                        icon: const Icon(Icons.print_rounded,
                            color: Colors.green, size: 20),
                        onPressed: onPrint,
                        tooltip: 'طباعة',
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.red, size: 20),
                        onPressed: onDelete,
                        tooltip: 'حذف',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Stats row ────────────────────────────────
                  if (!hasData)
                    const Center(
                        child:
                            SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                  else
                    Row(
                      children: [
                        _StatPill(
                          label: 'الكلي',
                          value: totalCount.toString(),
                          icon: Icons.format_list_numbered_rounded,
                          color: AppColors.primaryBlue,
                          bg: AppColors.primaryBlue.withValues(alpha: 0.1),
                        ),
                        const SizedBox(width: 8),
                        _StatPill(
                          label: 'نشط',
                          value: activeCount.toString(),
                          icon: Icons.check_circle_outline_rounded,
                          color: const Color(0xFF22C55E),
                          bg: const Color(0xFF22C55E).withValues(alpha: 0.1),
                        ),
                        const SizedBox(width: 8),
                        _StatPill(
                          label: 'مستخدم',
                          value: usedCount.toString(),
                          icon: Icons.person_rounded,
                          color: Colors.orange,
                          bg: Colors.orange.withValues(alpha: 0.1),
                        ),
                        if (earliestExpiry != null) ...[
                          const SizedBox(width: 8),
                          _StatPill(
                            label: 'أقرب انتهاء',
                            value: intl.DateFormat('MM/dd').format(earliestExpiry),
                            icon: Icons.event_rounded,
                            color: earliestExpiry.isBefore(DateTime.now())
                                ? Colors.red
                                : Colors.purple,
                            bg: (earliestExpiry.isBefore(DateTime.now())
                                    ? Colors.red
                                    : Colors.purple)
                                .withValues(alpha: 0.1),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bg;

  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 3),
            Text(value,
                style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: GoogleFonts.cairo(
                    fontSize: 9, color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}
