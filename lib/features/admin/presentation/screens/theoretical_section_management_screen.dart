import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/admin/presentation/screens/bulk_upload_screen.dart';
import 'package:quizzly/features/admin/domain/services/bulk_upload_service.dart';


class TheoreticalSectionManagementScreen extends StatefulWidget {
  final String sectionId;
  final String sectionName;
  final String subjectId;
  final List<String> breadcrumbs;
  final String? lessonId;
  final String? lessonName;

  const TheoreticalSectionManagementScreen({
    super.key,
    required this.sectionId,
    required this.sectionName,
    required this.subjectId,
    required this.breadcrumbs,
    this.lessonId,
    this.lessonName,
  });

  @override
  State<TheoreticalSectionManagementScreen> createState() => _TheoreticalSectionManagementScreenState();
}

class _TheoreticalSectionManagementScreenState extends State<TheoreticalSectionManagementScreen> {
  final DatabaseService _dbService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.lessonName != null ? 'أسئلة: ${widget.lessonName}' : widget.sectionName,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'تصدير الأسئلة (CSV)',
            onPressed: _exportCSV,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'رفع أسئلة (CSV)',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => BulkUploadScreen(subjectId: widget.subjectId)));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBreadcrumbs(isDark),
          Expanded(child: _buildQuestionsList(isDark)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddQuestionDialog(context),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('إضافة سؤال', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBreadcrumbs(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: widget.breadcrumbs.asMap().entries.map((entry) {
            return Row(
              children: [
                if (entry.key > 0) Icon(Icons.chevron_left_rounded, size: 16, color: Colors.grey[400]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.value,
                    style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildQuestionsList(bool isDark) {
    Query query = FirebaseFirestore.instance
        .collection(DatabaseService.colQuestions)
        .where('subjectId', isEqualTo: widget.subjectId);

    if (widget.lessonId != null) {
      query = query.where('topicIds', arrayContains: widget.lessonId);
    } else {
      query = query.where('parentId', isEqualTo: widget.sectionId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.limit(50).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) {
          return _emptyState('حدث خطأ أثناء جلب الأسئلة: ${snapshot.error}', isDark, isError: true);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyState('لا توجد أسئلة في هذا القسم حالياً', isDark);
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            return _buildQuestionCard(id, data, isDark, key: ValueKey(id));
          },
        );
      },
    );
  }

  Widget _buildQuestionCard(String id, Map<String, dynamic> data, bool isDark, {Key? key}) {
    final String typeStr = data['type'] == 'mcq' ? 'أتمتة' : (data['type'] == 'tf' ? 'صح/خطأ' : 'مقالي');
    final Color typeColor = data['type'] == 'mcq' ? Colors.blue : (data['type'] == 'tf' ? Colors.teal : Colors.orange);
    final questionText = data['text'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
      ),
      child: ExpansionTile(
        key: PageStorageKey(id),
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(typeStr, style: GoogleFonts.cairo(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                questionText,
                style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 10),
                if (data['options'] != null) ...[
                  Text('الخيارات:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  ...(data['options'] as List).map((opt) {
                    final isCorrect = (data['correctOptionIds'] as List?)?.contains(opt['id']) ?? (opt['id'] == data['correctOptionId']);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCorrect ? Colors.green.withValues(alpha: 0.05) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isCorrect ? Colors.green.withValues(alpha: 0.3) : Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          Icon(isCorrect ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, 
                               size: 16, color: isCorrect ? Colors.green : Colors.grey),
                          const SizedBox(width: 10),
                          Expanded(child: Text(opt['text'] ?? '', style: GoogleFonts.cairo(fontSize: 12))),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    _buildMetaChip(Icons.bar_chart_rounded, data['difficulty'] ?? 'N/A', Colors.blue),
                    const SizedBox(width: 8),
                    _buildMetaChip(Icons.psychology_rounded, _translateCognitiveLevel(data['cognitiveLevel']), Colors.orange),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit_note_rounded, size: 20),
                      label: Text('تعديل', style: GoogleFonts.cairo()),
                      onPressed: () => _showEditQuestionDialog(id, data),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                      label: Text('حذف', style: GoogleFonts.cairo(color: Colors.red)),
                      onPressed: () => _confirmDelete(id, questionText),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _translateCognitiveLevel(String? c) {
    switch (c) {
      case 'recall': return 'تذكر';
      case 'application': return 'تطبيق';
      case 'understanding':
      default: return 'فهم واستيعاب';
    }
  }

  Widget _buildMetaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _showAddQuestionDialog(BuildContext context) {
    _showQuestionDialog();
  }

  void _showEditQuestionDialog(String id, Map<String, dynamic> currentData) {
    _showQuestionDialog(id: id, currentData: currentData);
  }

  void _showQuestionDialog({String? id, Map<String, dynamic>? currentData}) {
    final bool isEdit = id != null;
    
    final List<Map<String, dynamic>> questionTypes = [
      {'id': 'mcq', 'label': 'خيارات متعددة', 'icon': Icons.radio_button_checked_rounded},
      {'id': 'checkbox', 'label': 'مربعات اختيار', 'icon': Icons.check_box_rounded},
      {'id': 'tf', 'label': 'صح/خطأ', 'icon': Icons.rule_rounded},
      {'id': 'essay', 'label': 'مقالي', 'icon': Icons.short_text_rounded},
    ];

    String selectedTypeId = currentData?['type'] ?? 'mcq';
    final textController = TextEditingController(text: currentData?['text']);
    final essayAnswerController = TextEditingController(text: currentData?['essayAnswer']);
    final explanationController = TextEditingController(text: currentData?['explanation']);
    final explanationImageUrlController = TextEditingController(text: currentData?['explanationImageUrl']);
    final timeController = TextEditingController(text: currentData?['estimatedTime']?.toString() ?? '60');
    bool isEnabled = currentData?['isEnabled'] ?? true;
    
    Difficulty selectedDifficulty = Difficulty.values.firstWhere((e) => e.name == currentData?['difficulty'], orElse: () => Difficulty.medium);
    CognitiveLevel selectedLevel = CognitiveLevel.values.firstWhere((e) => e.name == currentData?['cognitiveLevel'], orElse: () => CognitiveLevel.understanding);
    
    List<Map<String, String>> options = (currentData?['options'] as List? ?? [])
        .map((e) => {'id': e['id'].toString(), 'text': e['text'].toString()})
        .toList();
    
    if (options.isEmpty) {
      if (selectedTypeId == 'tf') {
        options = [{'id': 'true', 'text': 'صح'}, {'id': 'false', 'text': 'خطأ'}];
      } else if (selectedTypeId == 'mcq' || selectedTypeId == 'checkbox') {
        options = [{'id': '1', 'text': ''}];
      }
    }
    
    List<String> correctOptionIds = (currentData?['correctOptionIds'] as List?)?.map((e) => e.toString()).toList() ?? 
        (currentData?['correctOptionId'] != null ? [currentData!['correctOptionId'].toString()] : []);
    
    if (correctOptionIds.isEmpty && options.isNotEmpty) {
      correctOptionIds = [options[0]['id']!];
    }

    final List<TextEditingController> optionControllers = options.map((opt) => TextEditingController(text: opt['text'])).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: min(800, MediaQuery.of(context).size.width * 0.95),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
            ),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Header (Fixed) ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(isEdit ? Icons.edit_note_rounded : Icons.add_task_rounded, color: AppColors.primaryBlue),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          isEdit ? 'تعديل السؤال' : 'إضافة سؤال جديد',
                          style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // --- Scrollable Body (Flexible) ---
                  Flexible(
                    child: SingleChildScrollView(
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
                                      setDialogState(() {
                                        final oldType = selectedTypeId;
                                        selectedTypeId = val!;
                                        
                                        if (selectedTypeId == 'tf') {
                                          options = [{'id': 'true', 'text': 'صح'}, {'id': 'false', 'text': 'خطأ'}];
                                          optionControllers.forEach((c) => c.dispose());
                                          optionControllers.clear();
                                          optionControllers.addAll(options.map((o) => TextEditingController(text: o['text'])));
                                          correctOptionIds = ['true'];
                                        } else if (selectedTypeId == 'essay') {
                                          options = [];
                                          optionControllers.forEach((c) => c.dispose());
                                          optionControllers.clear();
                                          correctOptionIds = [];
                                        } else if (oldType == 'tf' || oldType == 'essay') {
                                          options = [{'id': '1', 'text': ''}];
                                          optionControllers.forEach((c) => c.dispose());
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
                                            setDialogState(() {
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
                                          groupValue: correctOptionIds.isNotEmpty ? correctOptionIds.first : null,
                                          onChanged: (v) {
                                            if (v != null) {
                                              setDialogState(() => correctOptionIds = [v]);
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
                                          onPressed: () => setDialogState(() {
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
                                onPressed: () => setDialogState(() {
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
                                icon: Icon(Icons.add_photo_alternate_outlined, color: AppColors.primaryBlue),
                                onPressed: () async {
                                  final controller = TextEditingController();
                                  final url = await showDialog<String>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('رابط الصورة', style: GoogleFonts.cairo()),
                                      content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'https://...')),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
                                        TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text('موافق')),
                                      ],
                                    ),
                                  );
                                  if (url != null && url.isNotEmpty) {
                                    setDialogState(() => explanationImageUrlController.text = url);
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
                                    onPressed: () => setDialogState(() => explanationImageUrlController.clear()),
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
                                        initialValue: selectedDifficulty,
                                        decoration: InputDecoration(labelText: 'الصعوبة', labelStyle: GoogleFonts.cairo()),
                                        items: Difficulty.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name, style: GoogleFonts.cairo()))).toList(),
                                        onChanged: (v) => setDialogState(() => selectedDifficulty = v!),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: DropdownButtonFormField<CognitiveLevel>(
                                        initialValue: selectedLevel,
                                        decoration: InputDecoration(labelText: 'المستوى المعرفي', labelStyle: GoogleFonts.cairo()),
                                        items: CognitiveLevel.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name, style: GoogleFonts.cairo()))).toList(),
                                        onChanged: (v) => setDialogState(() => selectedLevel = v!),
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
                  ),
                  
                  // --- Footer (Fixed & Guaranteed Visible) ---
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                    child: Row(
                      children: [
                        // --- Enabled Switch ---
                        Text('حالة السؤال:', style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: isEnabled,
                            activeThumbColor: AppColors.primaryBlue,
                            onChanged: (v) => setDialogState(() => isEnabled = v),
                          ),
                        ),
                        Text(isEnabled ? 'مفعل' : 'معطل', style: GoogleFonts.cairo(fontSize: 12, color: isEnabled ? Colors.green : Colors.grey)),
                        
                        const Spacer(),
                        
                        // --- Action Buttons ---
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
                            if (textController.text.trim().isEmpty) return;
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
                              // Backwards compatibility
                              if (correctOptionIds.isNotEmpty) {
                                questionData['correctOptionId'] = correctOptionIds.first;
                              }
                            } else {
                              questionData['essayAnswer'] = essayAnswerController.text.trim();
                            }
                            
                            final navigator = Navigator.of(context);
                            try {
                              if (isEdit) {
                                await _dbService.updateDoc(DatabaseService.colQuestions, id, questionData);
                              } else {
                                await _dbService.addQuestion(widget.sectionId, questionData);
                              }
                              if (mounted) {
                                navigator.pop();
                                _showStatusSnackBar(isEdit ? 'تم تحديث السؤال بنجاح' : 'تم إضافة السؤال بنجاح', isError: false);
                              }
                            } catch (e) {
                              if (mounted) _showStatusSnackBar('حدث خطأ: $e', isError: true);
                            }
                          },
                          child: Text(isEdit ? 'حفظ التعديلات' : 'إضافة السؤال', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      },
    ).then((_) {
      textController.dispose();
      essayAnswerController.dispose();
      explanationController.dispose();
      explanationImageUrlController.dispose();
      timeController.dispose();
      for (var c in optionControllers) {
        c.dispose();
      }
    });
  }

  void _confirmDelete(String id, String text) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تأكيد الحذف', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('هل أنت متأكد من حذف هذا السؤال؟\n${text.substring(0, text.length > 50 ? 50 : text.length)}...', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              try {
                await _dbService.deleteDoc(DatabaseService.colQuestions, id);
                if (mounted) {
                  navigator.pop();
                  _showStatusSnackBar('تم حذف السؤال بنجاح', isError: false);
                }
              } catch (e) {
                if (mounted) _showStatusSnackBar('فشل الحذف: $e', isError: true);
              }
            },
            child: Text('حذف', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCSV() async {
    try {
      final topicsSnap = await FirebaseFirestore.instance.collection(DatabaseService.colTopics).where('subjectId', isEqualTo: widget.subjectId).get();
      Map<String, String> topicIdToName = {};
      for (var doc in topicsSnap.docs) {
        topicIdToName[doc.id] = doc.data()['name'] ?? '';
      }
      final questionsSnap = await FirebaseFirestore.instance.collection(DatabaseService.colQuestions).where('parentId', isEqualTo: widget.sectionId).get();
      final List<QuizQuestion> questions = questionsSnap.docs.map((doc) => QuizQuestion.fromFirestore(doc)).toList();
      
      if (!mounted) return;

      if (questions.isEmpty) {
        _showStatusSnackBar('لا توجد أسئلة لتصديرها', isError: true);
        return;
      }
      
      final csvContent = BulkUploadService.generateTemplate(questions: questions, topicIdToName: topicIdToName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'questions_${widget.sectionName}_$timestamp';
      
      Uint8List bytes = Uint8List.fromList(utf8.encode(csvContent));
      
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        ext: 'csv',
        mimeType: MimeType.csv,
      );

      if (mounted) {
        _showStatusSnackBar('تم حفظ ملف CSV بنجاح', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showStatusSnackBar('فشل التصدير: $e', isError: true);
      }
    }
  }

  void _showStatusSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      ),
    );
  }

  Widget _emptyState(String message, bool isDark, {bool isError = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.quiz_outlined,
              size: 48,
              color: isError ? Colors.red.withValues(alpha: 0.5) : (isDark ? Colors.white24 : Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.cairo(color: isError ? Colors.red : AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
