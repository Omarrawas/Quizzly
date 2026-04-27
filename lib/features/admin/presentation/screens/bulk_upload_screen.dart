import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/bulk_upload_service.dart';

class BulkUploadScreen extends StatefulWidget {
  final String subjectId;
  const BulkUploadScreen({super.key, required this.subjectId});

  @override
  State<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen> {
  final BulkUploadService _uploadService = BulkUploadService();
  
  bool _isProcessing = false;
  ParsedQuestionResult? _result;

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _isProcessing = true;
          _result = null;
        });

        final bytes = result.files.single.bytes!;
        final extension = result.files.single.extension?.toLowerCase();
        
        final parsedResult = (extension == 'xlsx' || extension == 'xls')
            ? await _uploadService.parseAndValidateExcel(bytes, widget.subjectId)
            : await _uploadService.parseAndValidateCsv(bytes, widget.subjectId);

        setState(() {
          _result = parsedResult;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء قراءة الملف: $e')));
    }
  }

  Future<void> _saveQuestions() async {
    if (_result == null || _result!.questions.isEmpty) return;

    setState(() => _isProcessing = true);
    
    try {
      await _uploadService.saveQuestions(_result!.questions, widget.subjectId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الأسئلة بنجاح!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الحفظ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('رفع أسئلة جماعي (Excel)', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.file_upload_outlined, size: 48, color: AppColors.primaryBlue),
                  const SizedBox(height: 16),
                  Text('قم برفع ملف Excel (.xlsx) يحتوي على الأسئلة', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _pickFile,
                    child: _isProcessing 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('اختيار ملف'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            if (_result != null) ...[
              Text('المعاينة (Preview)', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              if (_result!.errors.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تم العثور على أخطاء:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.red)),
                      const SizedBox(height: 4),
                      ..._result!.errors.map((e) => Text('سطر ${e.row}: ${e.message}', style: GoogleFonts.cairo(fontSize: 12, color: Colors.red))),
                    ],
                  ),
                ),
              
              Text('عدد الأسئلة الصالحة: ${_result!.questions.length}', style: GoogleFonts.cairo(color: Colors.green, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              Expanded(
                child: ListView.builder(
                  itemCount: _result!.questions.length,
                  itemBuilder: (context, index) {
                    final q = _result!.questions[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text(q.text, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('النوع: ${q.type.name} | الصعوبة: ${q.difficulty?.name ?? "غير محدد"}'),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _result!.questions.isEmpty || _isProcessing ? null : _saveQuestions,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.all(16)),
                child: const Text('حفظ الأسئلة في قاعدة البيانات', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
