import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/admin/presentation/screens/batch_codes_preview_screen.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
// qr_flutter removed as it's unused here (PDF uses pw.BarcodeWidget)

class ManageActivationCodesScreen extends StatefulWidget {
  const ManageActivationCodesScreen({super.key});

  @override
  State<ManageActivationCodesScreen> createState() => _ManageActivationCodesScreenState();
}

class _ManageActivationCodesScreenState extends State<ManageActivationCodesScreen> {
  final DatabaseService _dbService = DatabaseService();

  Future<void> _printBatch(String batchName) async {
    try {
      final codes = await _dbService.getActivationCodesByBatch(batchName);
      if (codes.isEmpty) return;

      final pdf = pw.Document();
      
      // We'll use 3x7 grid for codes (21 per page)
      const codesPerPage = 21;
      
      for (int i = 0; i < codes.length; i += codesPerPage) {
        final pageCodes = codes.sublist(i, (i + codesPerPage).clamp(0, codes.length));
        
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.GridView(
                  crossAxisCount: 3,
                  childAspectRatio: 0.8,
                  children: pageCodes.map((code) => _buildQrCell(code)).toList(),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الطباعة: $e')),
        );
      }
    }
  }

  pw.Widget _buildQrCell(Map<String, dynamic> code) {
    return pw.Container(
      margin: const pw.EdgeInsets.all(5),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'Quizzly Activation',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.blue900, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.BarcodeWidget(
            data: code['code'],
            barcode: pw.Barcode.qrCode(),
            width: 80,
            height: 80,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            code['code'],
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 1),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Batch: ${code['batchName']}',
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
          ),
          pw.Text(
            'Duration: ${code['durationDays']} Days',
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBatch(String batchName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Text('هل أنت متأكد من حذف المجموعة "$batchName" وجميع أكوادها؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المجموعة بنجاح')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة مجموعات الأكواد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _dbService.getBatches(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final batches = snapshot.data!.docs;
          if (batches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.vpn_key_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('لا توجد مجموعات أكواد حالياً', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.inventory_2_rounded, color: AppColors.primaryBlue),
                    ),
                    title: Text(name, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${intl.DateFormat('yyyy/MM/dd').format(createdAt ?? DateTime.now())} • $quantity كود • $duration يوم',
                      style: GoogleFonts.cairo(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.print_rounded, color: Colors.green),
                          onPressed: () => _printBatch(name),
                          tooltip: 'طباعة الأكواد',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
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
