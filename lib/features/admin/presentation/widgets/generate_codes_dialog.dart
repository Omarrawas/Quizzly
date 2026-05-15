import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';

enum GenerationMode { single, semester, bundle }

class GenerateCodesDialog extends StatefulWidget {
  const GenerateCodesDialog({super.key});

  @override
  State<GenerateCodesDialog> createState() => _GenerateCodesDialogState();
}

class _GenerateCodesDialogState extends State<GenerateCodesDialog> {
  final _dbService = DatabaseService();
  final _formKey = GlobalKey<FormState>();
  
  final _batchNameController = TextEditingController();
  final _quantityController = TextEditingController(text: '10');
  final _durationController = TextEditingController(text: '180');
  
  int _selectedCreditValue = 5000;
  
  bool _isSaving = false;

  @override
  void dispose() {
    _batchNameController.dispose();
    _quantityController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _dbService.generateBulkCodes(
        creditValue: _selectedCreditValue,
        batchName: _batchNameController.text.trim(),
        quantity: int.parse(_quantityController.text),
        durationDays: int.parse(_durationController.text),
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم توليد ${_quantityController.text} كود برصيد $_selectedCreditValue بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التوليد: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'توليد أرصدة (شحن)',
        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLabel('قيمة الرصيد (ل.س)'),
                const SizedBox(height: 8),
                _buildCreditDropdown(),
                const SizedBox(height: 16),
                
                _buildLabel('اسم المجموعة (Batch)'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _batchNameController,
                  hint: 'مثال: دفعة الفصل الأول 2026',
                  icon: Icons.label_important_rounded,
                  validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('الكمية'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _quantityController,
                            hint: 'عدد الأكواد',
                            icon: Icons.numbers_rounded,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'مطلوب';
                              final n = int.tryParse(v);
                              if (n == null || n < 1) return 'غير صالح';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('المدة (يوم)'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _durationController,
                            hint: 'مدة التفعيل',
                            icon: Icons.timer_rounded,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'مطلوب';
                              final n = int.tryParse(v);
                              if (n == null || n < 1) return 'غير صالح';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _generate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSaving 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text('توليد الآن', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildCreditDropdown() {
    final List<int> values = [5000, 10000, 15000, 20000, 25000, 30000, 40000, 50000, 75000, 100000];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: _selectedCreditValue,
          items: values.map((v) => DropdownMenuItem(
            value: v,
            child: Text('$v ل.س', style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
          )).toList(),
          onChanged: (val) => setState(() => _selectedCreditValue = val!),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(label, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.cairo(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.primaryBlue),
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
