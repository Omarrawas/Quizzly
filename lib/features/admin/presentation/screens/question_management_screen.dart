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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.questionId != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'تعديل السؤال' : 'إضافة سؤال جديد',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 220,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
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
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: textController,
                    style: GoogleFonts.cairo(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'اكتب نص السؤال هنا...',
                      hintStyle: GoogleFonts.cairo(color: Colors.grey),
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(20),
                    ),
                    maxLines: null,
                    minLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            if (selectedTypeId == 'mcq' || selectedTypeId == 'checkbox' || selectedTypeId == 'tf') ...[
              Column(
                children: options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final opt = entry.value;
                  final controller = optionControllers[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        if (selectedTypeId == 'checkbox')
                          Checkbox(
                            value: correctOptionIds.contains(opt['id']),
                            onChanged: (v) {
                              setState(() {
                                if (v ?? false) {
                                  if (!correctOptionIds.contains(opt['id'])) {
                                    correctOptionIds.add(opt['id'] ?? '');
                                  }
                                } else {
                                  correctOptionIds.remove(opt['id'] ?? '');
                                }
                              });
                            },
                          )
                        else
                          Radio<String>(
                            value: opt['id'] ?? '',
                            // ignore: deprecated_member_use
                            groupValue: correctOptionIds.isNotEmpty ? correctOptionIds.first : null,
                            // ignore: deprecated_member_use
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => correctOptionIds = [v]);
                              }
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ),
                        if (options.length > 1 && selectedTypeId != 'tf')
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.red),
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
              ),
              if (selectedTypeId != 'tf')
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 20),
                  label: Text('إضافة خيار جديد', style: GoogleFonts.cairo()),
                  onPressed: () => setState(() {
                    final newId = DateTime.now().millisecondsSinceEpoch.toString();
                    options.add({'id': newId, 'text': ''});
                    optionControllers.add(TextEditingController());
                  }),
                ),
            ] else if (selectedTypeId == 'essay')
              TextField(
                controller: essayAnswerController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'الإجابة النموذجية (مقالي)',
                  labelStyle: GoogleFonts.cairo(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            
            const SizedBox(height: 24),
            Text('شرح الإجابة (اختياري)', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.grey[600])),
            const SizedBox(height: 8),
            TextField(
              controller: explanationController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'اكتب الشرح هنا (اختياري)',
                hintStyle: GoogleFonts.cairo(fontSize: 14),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
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
            
            const SizedBox(height: 16),
            const Divider(),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text('إعدادات متقدمة', style: GoogleFonts.cairo(fontSize: 14, color: AppColors.primaryBlue)),
                tilePadding: EdgeInsets.zero,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Difficulty>(
                          value: selectedDifficulty,
                          decoration: InputDecoration(labelText: 'الصعوبة', labelStyle: GoogleFonts.cairo()),
                          items: Difficulty.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name, style: GoogleFonts.cairo()))).toList(),
                          onChanged: (v) => setState(() => selectedDifficulty = v!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<CognitiveLevel>(
                          value: selectedLevel,
                          decoration: InputDecoration(labelText: 'المستوى المعرفي', labelStyle: GoogleFonts.cairo()),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // --- Enabled Switch ---
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('حالة السؤال:', style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: isEnabled,
                      activeThumbColor: AppColors.primaryBlue,
                      onChanged: (v) => setState(() => isEnabled = v),
                    ),
                  ),
                  Text(isEnabled ? 'مفعل' : 'معطل', style: GoogleFonts.cairo(fontSize: 12, color: isEnabled ? Colors.green : Colors.grey)),
                ],
              ),
              
              // --- Action Buttons ---
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () async {
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
                          // The snackbar on parent screen handles the success message, 
                          // but since we popped, we should probably let parent know, or just rely on streams.
                        }
                      } catch (e) {
                        if (mounted) _showStatusSnackBar('حدث خطأ: $e', isError: true);
                      }
                    },
                    child: Text(isEdit ? 'حفظ التعديلات' : 'إضافة السؤال', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
