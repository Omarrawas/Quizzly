import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/admin/presentation/screens/batch_codes_preview_screen.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:barcode/barcode.dart';
// qr_flutter removed as it's unused here (PDF uses pw.BarcodeWidget)

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

      // Fetch all unique subject names for these codes
      final allSubjectIds = codes
          .expand((c) => (c['subjectIds'] as List? ?? []))
          .map((e) => e.toString())
          .toSet()
          .toList();

      final Map<String, String> subjectNamesMap = {};
      if (allSubjectIds.isNotEmpty) {
        // Handle Firestore whereIn limit (10)
        for (int i = 0; i < allSubjectIds.length; i += 10) {
          final chunk = allSubjectIds.sublist(
            i,
            (i + 10).clamp(0, allSubjectIds.length),
          );
          final snap = await FirebaseFirestore.instance
              .collection('subjects')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (var d in snap.docs) {
            subjectNamesMap[d.id] = d.get('name')?.toString() ?? 'N/A';
          }
        }
      }

      final pdf = pw.Document();

      // We'll use 3x7 grid for codes (21 per page)
      const codesPerPage = 21;

      for (int i = 0; i < codes.length; i += codesPerPage) {
        final pageCodes = codes.sublist(
          i,
          (i + codesPerPage).clamp(0, codes.length),
        );

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(10),
            theme: pw.ThemeData.withFont(
              base: arabicFont,
              bold: arabicFontBold,
            ),
            build: (pw.Context context) {
              return pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.GridView(
                  crossAxisCount: 3,
                  childAspectRatio: 0.65, // Adjusted to fit details
                  children: pageCodes
                      .map(
                        (code) {
                          final ids = (code['subjectIds'] as List? ?? [])
                              .map((e) => e.toString())
                              .toList();
                          final names = ids
                              .map((id) => subjectNamesMap[id] ?? '...')
                              .toList();
                          return _buildQrCell(code, arabicFontBold, logoImage, names);
                        },
                      )
                      .toList(),
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
    List<String> subjectNames,
  ) {
    final String code = codeData['code']?.toString() ?? 'N/A';
    final int subjectsCount = subjectNames.length;
    final String typeLabel = subjectsCount > 1
        ? 'كود باقة ($subjectsCount مواد)'
        : 'كود مادة';
    final String batchName = codeData['batchName']?.toString() ?? '-';
    final int duration = (codeData['durationDays'] as int?) ?? 0;

    return pw.Container(
      margin: const pw.EdgeInsets.all(3),
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'Quizzly Activation',
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.blue900,
              font: boldFont,
            ),
          ),
          pw.SizedBox(height: 1),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
            child: pw.Text(
              typeLabel,
              style: pw.TextStyle(
                fontSize: 5.5,
                font: boldFont,
                color: PdfColors.blue800,
              ),
            ),
          ),
          pw.SizedBox(height: 2),
          // Subjects List (Small)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4),
            child: pw.Column(
              children: subjectNames.take(3).map((name) => pw.Text(
                name,
                style: const pw.TextStyle(fontSize: 4.5, color: PdfColors.black),
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
              )).toList(),
            ),
          ),
          pw.SizedBox(height: 2),
          // QR with Logo
          pw.Directionality(
            textDirection: pw.TextDirection.ltr,
            child: pw.Stack(
              alignment: pw.Alignment.center,
              children: [
                pw.Container(
                  color: PdfColors.white,
                  padding: const pw.EdgeInsets.all(1),
                  child: pw.BarcodeWidget(
                    data: code,
                    barcode: pw.Barcode.qrCode(
                      errorCorrectLevel: BarcodeQRCorrectionLevel.high,
                    ),
                    width: 50,
                    height: 50,
                    color: PdfColors.black,
                    drawText: false,
                  ),
                ),
                pw.Container(
                  width: 9,
                  height: 9,
                  padding: const pw.EdgeInsets.all(0.5),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(1.5)),
                  ),
                  child: pw.Image(logo),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Directionality(
            textDirection: pw.TextDirection.ltr,
            child: pw.Text(
              code,
              style: pw.TextStyle(
                fontSize: 8.5,
                font: boldFont,
                letterSpacing: 0.5,
                color: PdfColors.black,
              ),
            ),
          ),
          pw.SizedBox(height: 1.5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Batch: $batchName',
                style: const pw.TextStyle(fontSize: 4.5, color: PdfColors.grey800),
              ),
              pw.Text(
                '$duration Days',
                style: const pw.TextStyle(fontSize: 4.5, color: PdfColors.grey800),
              ),
            ],
          ),
        ],
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
          if (snapshot.hasError)
            return Center(child: Text('خطأ: ${snapshot.error}'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

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

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
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
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    title: Text(
                      name,
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${intl.DateFormat('yyyy/MM/dd').format(createdAt ?? DateTime.now())} • $quantity كود • $duration يوم',
                      style: GoogleFonts.cairo(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.print_rounded,
                            color: Colors.green,
                          ),
                          onPressed: () => _printBatch(name),
                          tooltip: 'طباعة الأكواد',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
                          ),
                          onPressed: () => _deleteBatch(name),
                          tooltip: 'حذف المجموعة',
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
