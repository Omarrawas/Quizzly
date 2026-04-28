import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  
  GenerationMode _mode = GenerationMode.single;
  
  // Selection
  String? _selectedSubjectId;
  String? _selectedSemesterId;
  final List<String> _selectedSubjectIds = [];
  
  bool _isSaving = false;

  @override
  void dispose() {
    _batchNameController.dispose();
    _quantityController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    List<String> finalSubjectIds = [];

    if (_mode == GenerationMode.single) {
      if (_selectedSubjectId != null) finalSubjectIds.add(_selectedSubjectId!);
    } else if (_mode == GenerationMode.bundle) {
      finalSubjectIds.addAll(_selectedSubjectIds);
    } else if (_mode == GenerationMode.semester) {
      if (_selectedSemesterId != null) {
        // Fetch subjects for this semester
        final snap = await FirebaseFirestore.instance
            .collection(DatabaseService.colSubjects)
            .where('parentId', isEqualTo: _selectedSemesterId)
            .get();
        finalSubjectIds = snap.docs.map((d) => d.id).toList();
      }
    }

    if (!_formKey.currentState!.validate() || finalSubjectIds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى اختيار مادة واحدة على الأقل وتعبئة الحقول')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _dbService.generateBulkCodes(
        subjectIds: finalSubjectIds,
        batchName: _batchNameController.text.trim(),
        quantity: int.parse(_quantityController.text),
        durationDays: int.parse(_durationController.text),
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم توليد ${_quantityController.text} كود بنجاح')),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'توليد أكواد تفعيل',
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
                // Mode Toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildModeButton('مادة', GenerationMode.single),
                      _buildModeButton('فصل', GenerationMode.semester),
                      _buildModeButton('مجموعة', GenerationMode.bundle),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Selection UI based on mode
                _buildSelectionUI(isDark),
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

  Widget _buildModeButton(String label, GenerationMode mode) {
    final isSelected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _mode = mode;
          _selectedSubjectId = null;
          _selectedSemesterId = null;
          _selectedSubjectIds.clear();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionUI(bool isDark) {
    if (_mode == GenerationMode.single) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('اختر المادة'),
          const SizedBox(height: 8),
          _buildSubjectDropdown(),
        ],
      );
    } else if (_mode == GenerationMode.semester) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('اختر الفصل (سيفعل جميع مواده)'),
          const SizedBox(height: 8),
          _buildSemesterDropdown(),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('اختر مجموعة مواد'),
          const SizedBox(height: 8),
          _buildSubjectMultiSelect(),
        ],
      );
    }
  }

  Widget _buildSubjectDropdown() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection(DatabaseService.colSubjects).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final docs = snapshot.data!.docs;
        return _buildDropdown(
          value: _selectedSubjectId,
          items: docs,
          onChanged: (val) => setState(() => _selectedSubjectId = val),
        );
      },
    );
  }

  Widget _buildSemesterDropdown() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection(DatabaseService.colSemesters).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final docs = snapshot.data!.docs;
        return _buildDropdown(
          value: _selectedSemesterId,
          items: docs,
          onChanged: (val) => setState(() => _selectedSemesterId = val),
        );
      },
    );
  }

  Widget _buildSubjectMultiSelect() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection(DatabaseService.colSubjects).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final docs = snapshot.data!.docs;
        
        return Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final id = doc.id;
              final isSelected = _selectedSubjectIds.contains(id);
              
              return CheckboxListTile(
                value: isSelected,
                title: Text(data['name'] ?? '', style: GoogleFonts.cairo(fontSize: 13)),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedSubjectIds.add(id);
                    } else {
                      _selectedSubjectIds.remove(id);
                    }
                  });
                },
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<QueryDocumentSnapshot> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          items: items.map((d) => DropdownMenuItem(
            value: d.id,
            child: Text(d.get('name') ?? '', style: GoogleFonts.cairo(fontSize: 14)),
          )).toList(),
          onChanged: onChanged,
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
