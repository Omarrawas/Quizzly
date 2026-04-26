import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';

class QuestionManagementScreen extends StatefulWidget {
  final String sectionId;
  final String subjectId;
  final String? lessonId;
  final String? lessonName;
  final String? questionId;
  final Map<String, dynamic>? currentData;

  const QuestionManagementScreen({
    super.key,
    required this.sectionId,
    required this.subjectId,
    this.lessonId,
    this.lessonName,
    this.questionId,
    this.currentData,
  });

  @override
  State<QuestionManagementScreen> createState() => _QuestionManagementScreenState();
}

class _QuestionManagementScreenState extends State<QuestionManagementScreen> {
  final DatabaseService _dbService = DatabaseService();

  late String selectedTypeId;
  late TextEditingController textController;
  late TextEditingController essayAnswerController;
  late TextEditingController explanationController;
  late TextEditingController explanationImageUrlController;
  late TextEditingController timeController;
  late bool isEnabled;
  late Difficulty selectedDifficulty;
  late CognitiveLevel selectedLevel;
  
  List<Map<String, String>> options = [];
  List<String> correctOptionIds = [];
  List<TextEditingController> optionControllers = [];

  final List<Map<String, dynamic>> questionTypes = [
    {'id': 'mcq', 'label': 'خيارات متعددة', 'icon': Icons.radio_button_checked_rounded},
    {'id': 'checkbox', 'label': 'مربعات اختيار', 'icon': Icons.check_box_rounded},
    {'id': 'tf', 'label': 'صح/خطأ', 'icon': Icons.rule_rounded},
    {'id': 'essay', 'label': 'مقالي', 'icon': Icons.short_text_rounded},
  ];

  @override
  void initState() {
    super.initState();
    final currentData = widget.currentData;
    
    selectedTypeId = currentData?['type'] ?? 'mcq';
    textController = TextEditingController(text: currentData?['text']);
    essayAnswerController = TextEditingController(text: currentData?['essayAnswer']);
    explanationController = TextEditingController(text: currentData?['explanation']);
    explanationImageUrlController = TextEditingController(text: currentData?['explanationImageUrl']);
    timeController = TextEditingController(text: currentData?['estimatedTime']?.toString() ?? '60');
    isEnabled = currentData?['isEnabled'] ?? true;
    
    selectedDifficulty = Difficulty.values.firstWhere((e) => e.name == currentData?['difficulty'], orElse: () => Difficulty.medium);
    selectedLevel = CognitiveLevel.values.firstWhere((e) => e.name == currentData?['cognitiveLevel'], orElse: () => CognitiveLevel.understanding);
    
    options = (currentData?['options'] as List? ?? [])
        .map((e) => {'id': e['id'].toString(), 'text': e['text'].toString()})
        .toList();
    
    if (options.isEmpty) {
      if (selectedTypeId == 'tf') {
        options = [{'id': 'true', 'text': 'صح'}, {'id': 'false', 'text': 'خطأ'}];
      } else if (selectedTypeId == 'mcq' || selectedTypeId == 'checkbox') {
        options = [{'id': '1', 'text': ''}];
      }
    }
    
    correctOptionIds = (currentData?['correctOptionIds'] as List?)?.map((e) => e.toString()).toList() ?? 
        (currentData?['correctOptionId'] != null ? [currentData!['correctOptionId'].toString()] : []);
    
    if (correctOptionIds.isEmpty && options.isNotEmpty) {
      correctOptionIds = [options[0]['id']!];
    }

    optionControllers = options.map((opt) => TextEditingController(text: opt['text'])).toList();
  }

  @override
  void dispose() {
    textController.dispose();
    essayAnswerController.dispose();
    explanationController.dispose();
    explanationImageUrlController.dispose();
    timeController.dispose();
    for (var c in optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _showStatusSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isEdit) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300, width: 1),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              isEdit ? 'تعديل السؤال' : 'إضافة سؤال جديد',
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('مفعل', style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold)),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: isEnabled,
                  activeColor: AppColors.primaryBlue,
                  onChanged: (v) => setState(() => isEnabled = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isEdit) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, Colors.blueAccent],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () => _saveQuestion(isEdit),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.check, color: Colors.white),
        label: Text(
          isEdit ? 'حفظ التعديلات' : 'إضافة السؤال',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _saveQuestion(bool isEdit) async {
    if (textController.text.trim().isEmpty) {
      _showStatusSnackBar('يرجى كتابة نص السؤال', isError: true);
      return;
    }
    
    final Map<String, dynamic> questionData = {
      'text': textController.text.trim(),
      'type': selectedTypeId == 'checkbox' ? 'mcq' : selectedTypeId,
      'subjectId': widget.subjectId,
      'explanation': explanationController.text.trim(),
      'explanationImageUrl': explanationImageUrlController.text.trim(),
      'difficulty': selectedDifficulty.name,
      'cognitiveLevel': selectedLevel.name,
      'estimatedTime': int.tryParse(timeController.text) ?? 60,
      'primaryTopicId': widget.lessonId,
      'topicIds': widget.lessonId != null ? [widget.lessonId!] : [],
      'topicNames': widget.lessonName != null ? [widget.lessonName!] : [],
      'topicWeights': widget.lessonId != null ? {widget.lessonId!: 1.0} : {},
      'discriminationIndex': 0.5,
      'isFrequentlyWrong': false,
      'parentId': widget.sectionId,
      'isEnabled': isEnabled,
    };
    
    if (selectedTypeId != 'essay') {
      questionData['options'] = options;
      questionData['correctOptionIds'] = correctOptionIds;
      if (correctOptionIds.isNotEmpty) {
        questionData['correctOptionId'] = correctOptionIds.first;
      }
    } else {
      questionData['essayAnswer'] = essayAnswerController.text.trim();
    }
    
    final navigator = Navigator.of(context);
    try {
      if (isEdit) {
        await _dbService.updateDoc(DatabaseService.colQuestions, widget.questionId!, questionData);
      } else {
        await _dbService.addQuestion(widget.sectionId, questionData);
      }
      if (mounted) {
        navigator.pop();
      }
    } catch (e) {
      if (mounted) _showStatusSnackBar('حدث خطأ: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.questionId != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, isEdit),
                
                _buildSection(
                  title: 'إعدادات السؤال',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('نوع السؤال', style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Container(
                        width: 220,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedTypeId,
                            isExpanded: true,
                            onChanged: (val) {
                              setState(() {
                                final oldType = selectedTypeId;
                                selectedTypeId = val!;
                                
                                if (selectedTypeId == 'tf') {
                                  options = [{'id': 'true', 'text': 'صح'}, {'id': 'false', 'text': 'خطأ'}];
                                  for (var c in optionControllers) { c.dispose(); }
                                  optionControllers.clear();
                                  optionControllers.addAll(options.map((o) => TextEditingController(text: o['text'])));
                                  correctOptionIds = ['true'];
                                } else if (selectedTypeId == 'essay') {
                                  options = [];
                                  for (var c in optionControllers) { c.dispose(); }
                                  optionControllers.clear();
                                  correctOptionIds = [];
                                } else if (oldType == 'tf' || oldType == 'essay') {
                                  options = [{'id': '1', 'text': ''}];
                                  for (var c in optionControllers) { c.dispose(); }
                                  optionControllers.clear();
                                  optionControllers.add(TextEditingController());
                                  correctOptionIds = ['1'];
                                }
                              });
                            },
                            items: questionTypes.map((type) => DropdownMenuItem(
                              value: type['id'] as String,
                              child: Row(
                                children: [
                                  Icon(type['icon'] as IconData, size: 20, color: AppColors.primaryBlue),
                                  const SizedBox(width: 12),
                                  Text(type['label'] as String, style: GoogleFonts.cairo(fontSize: 14)),
                                ],
                              ),
                            )).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                  Text('نص السؤال', style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: textController,
                    style: GoogleFonts.cairo(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'اكتب نص السؤال هنا...',
                      hintStyle: GoogleFonts.cairo(color: Colors.grey),
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
                      contentPadding: const EdgeInsets.all(20),
                    ),
                    maxLines: null,
                    minLines: 3,
                  ),
                ],
              ),
            ),
            
            if (selectedTypeId != 'essay')
              _buildSection(
                title: 'الخيارات والإجابة',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...options.asMap().entries.map((entry) {
                      final index = entry.key;
                      final opt = entry.value;
                      final controller = optionControllers[index];
                      final isCorrect = correctOptionIds.contains(opt['id']);
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isCorrect ? Colors.green.withValues(alpha: 0.1) : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCorrect ? Colors.green : (isDark ? Colors.white10 : Colors.grey.shade300),
                            width: isCorrect ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (selectedTypeId == 'checkbox')
                              Checkbox(
                                value: isCorrect,
                                activeColor: Colors.green,
                                onChanged: (v) {
                                  setState(() {
                                    if (v ?? false) {
                                      if (!correctOptionIds.contains(opt['id'])) correctOptionIds.add(opt['id'] ?? '');
                                    } else {
                                      correctOptionIds.remove(opt['id'] ?? '');
                                    }
                                  });
                                },
                              )
                            else
                              Radio<String>(
                                value: opt['id'] ?? '',
                                groupValue: correctOptionIds.isNotEmpty ? correctOptionIds.first : null,
                                activeColor: Colors.green,
                                onChanged: (v) {
                                  if (v != null) setState(() => correctOptionIds = [v]);
                                },
                              ),
                            Expanded(
                              child: TextField(
                                onChanged: (v) => opt['text'] = v,
                                controller: controller,
                                style: GoogleFonts.cairo(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'الخيار ${index + 1}',
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                                ),
                              ),
                            ),
                            if (options.length > 1 && selectedTypeId != 'tf')
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => setState(() {
                                  options.removeAt(index);
                                  optionControllers.removeAt(index).dispose();
                                  correctOptionIds.remove(opt['id']);
                                }),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    if (selectedTypeId != 'tf')
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add, size: 20),
                          label: Text('إضافة خيار جديد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryBlue,
                            side: const BorderSide(color: AppColors.primaryBlue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onPressed: () => setState(() {
                            final newId = DateTime.now().millisecondsSinceEpoch.toString();
                            options.add({'id': newId, 'text': ''});
                            optionControllers.add(TextEditingController());
                          }),
                        ),
                      ),
                  ],
                ),
              )
            else
              _buildSection(
                title: 'الإجابة النموذجية',
                child: TextField(
                  controller: essayAnswerController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'اكتب الإجابة النموذجية للسؤال المقالي...',
                    hintStyle: GoogleFonts.cairo(color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

            _buildSection(
              title: 'معلومات إضافية',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('شرح الإجابة (اختياري)', style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: explanationController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'اكتب الشرح هنا...',
                      hintStyle: GoogleFonts.cairo(fontSize: 14),
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primaryBlue),
                        onPressed: () async {
                          final controller = TextEditingController();
                          final url = await showDialog<String>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('رابط الصورة', style: GoogleFonts.cairo()),
                              content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'https://...')),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                                TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('موافق')),
                              ],
                            ),
                          );
                          if (url != null && url.isNotEmpty) {
                            setState(() => explanationImageUrlController.text = url);
                          }
                        },
                      ),
                    ),
                  ),
                  if (explanationImageUrlController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.image_outlined, size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(child: Text('تم إرفاق صورة للشرح', style: GoogleFonts.cairo(fontSize: 12, color: Colors.green))),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                            onPressed: () => setState(() => explanationImageUrlController.clear()),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Difficulty>(
                          initialValue: selectedDifficulty,
                          decoration: InputDecoration(labelText: 'الصعوبة', labelStyle: GoogleFonts.cairo(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          items: Difficulty.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name, style: GoogleFonts.cairo()))).toList(),
                          onChanged: (v) => setState(() => selectedDifficulty = v!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<CognitiveLevel>(
                          initialValue: selectedLevel,
                          decoration: InputDecoration(labelText: 'المستوى المعرفي', labelStyle: GoogleFonts.cairo(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          items: CognitiveLevel.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name, style: GoogleFonts.cairo()))).toList(),
                          onChanged: (v) => setState(() => selectedLevel = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: timeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'الوقت المقدر (بالثواني)',
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSubmitButton(isEdit),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
  ),
);
  }
}
