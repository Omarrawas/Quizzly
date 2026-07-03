import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/widgets/tex_view_widget.dart';
import 'package:quizzly/features/admin/domain/services/pdf_parsing_service.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';

class QuestionPreviewEditDialog extends StatefulWidget {
  final ExtractedQuestion question;
  final String subjectId;
  final String sectionId;

  const QuestionPreviewEditDialog({
    super.key,
    required this.question,
    required this.subjectId,
    required this.sectionId,
  });

  @override
  State<QuestionPreviewEditDialog> createState() => _QuestionPreviewEditDialogState();
}

class _QuestionPreviewEditDialogState extends State<QuestionPreviewEditDialog> {
  bool _isEditing = false;

  // Form fields state
  late TextEditingController _textController;
  late String _selectedType;
  late List<TextEditingController> _optionControllers;
  late List<String> _optionIds;
  late List<String> _correctOptionIds;
  late TextEditingController _explanationController;

  // Topic selection state
  List<String> _selectedTopicIds = [];
  List<String> _selectedTopicNames = [];
  List<Map<String, dynamic>> _availableLessons = [];
  bool _isLoadingTopics = true;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.question.text);
    _selectedType = widget.question.type;
    _optionControllers = widget.question.options
        .map((opt) => TextEditingController(text: opt.text))
        .toList();
    _optionIds = widget.question.options.map((opt) => opt.id).toList();
    _correctOptionIds = List.from(widget.question.correctOptionIds);
    _explanationController = TextEditingController(text: widget.question.explanation);
    
    _selectedTopicIds = List.from(widget.question.topicIds ?? []);
    _selectedTopicNames = List.from(widget.question.topicNames ?? []);

    _loadAvailableLessons();
  }

  Future<void> _loadAvailableLessons() async {
    try {
      final snapshot = await DatabaseService()
          .getAllTopicsForSubject(widget.subjectId, sectionId: widget.sectionId)
          .first;
      final allDocs = snapshot.docs;
      final Map<String, String> nameMap = {
        for (var doc in allDocs)
          doc.id: (doc.data() as Map<String, dynamic>)['name'] ?? '',
      };

      // Filter for lessons and sort by creation order
      final lessonDocs = allDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['type'] == 'lesson';
      }).toList();

      lessonDocs.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aTime = (aData['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final bTime = (bData['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return aTime.compareTo(bTime);
      });

      if (mounted) {
        setState(() {
          _availableLessons = lessonDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final parentId = data['parentId'];
            final parentName = (parentId != null) ? nameMap[parentId] : null;

            // Format as "Chapter Name - Lesson Name"
            final fullName = parentName != null
                ? '$parentName - ${data['name']}'
                : data['name'] ?? '';

            return {'id': doc.id, 'name': fullName};
          }).toList();
          _isLoadingTopics = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading lessons in dialog: $e');
      if (mounted) {
        setState(() => _isLoadingTopics = false);
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _explanationController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _resetEditFields() {
    _textController.text = widget.question.text;
    _selectedType = widget.question.type;
    _explanationController.text = widget.question.explanation ?? '';
    
    // Clear and re-populate option controllers
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    
    _optionControllers = widget.question.options
        .map((opt) => TextEditingController(text: opt.text))
        .toList();
    _optionIds = widget.question.options.map((opt) => opt.id).toList();
    _correctOptionIds = List.from(widget.question.correctOptionIds);
    
    _selectedTopicIds = List.from(widget.question.topicIds ?? []);
    _selectedTopicNames = List.from(widget.question.topicNames ?? []);
  }

  void _saveAndPop() {
    final List<ExtractedQuestionOption> finalOptions = [];
    if (_selectedType != 'essay') {
      for (int i = 0; i < _optionIds.length; i++) {
        finalOptions.add(ExtractedQuestionOption(
          id: _optionIds[i],
          text: _optionControllers[i].text,
        ));
      }
    }

    final updatedQuestion = ExtractedQuestion(
      text: _textController.text,
      type: _selectedType,
      options: finalOptions,
      correctOptionIds: _correctOptionIds,
      topicIds: _selectedTopicIds,
      topicNames: _selectedTopicNames,
      explanation: _explanationController.text.trim(),
    );

    Navigator.of(context).pop(updatedQuestion);
  }

  void _showTopicSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: const Color(0xFF222329),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF2D2E36)),
              ),
              title: Text(
                'اختر المواضيع',
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: _availableLessons.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد مواضيع متاحة',
                          style: GoogleFonts.tajawal(color: Colors.white30),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _availableLessons.length,
                        separatorBuilder: (c, i) => const Divider(color: Color(0xFF2D2E36), height: 1),
                        itemBuilder: (context, index) {
                          final lesson = _availableLessons[index];
                          final isSelected = _selectedTopicIds.contains(lesson['id']);
                          return CheckboxListTile(
                            title: Text(
                              lesson['name'],
                              style: GoogleFonts.tajawal(
                                fontSize: 13,
                                color: isSelected ? const Color(0xFF7DFFA2) : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            value: isSelected,
                            activeColor: const Color(0xFF6E56FF),
                            checkColor: Colors.white,
                            onChanged: (val) {
                              setState(() {
                                if (val ?? false) {
                                  if (!_selectedTopicIds.contains(lesson['id'])) {
                                    _selectedTopicIds.add(lesson['id']);
                                    _selectedTopicNames.add(lesson['name']);
                                  }
                                } else {
                                  final idx = _selectedTopicIds.indexOf(lesson['id']);
                                  if (idx != -1) {
                                    _selectedTopicIds.removeAt(idx);
                                    _selectedTopicNames.removeAt(idx);
                                  }
                                }
                              });
                              setDialogState(() {}); // update dialog UI
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'تم',
                    style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6E56FF),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    String typeStr = 'اختيار';
    Color typeColor = Colors.blue;
    switch (type) {
      case 'mcq':
        typeStr = 'اختيار';
        typeColor = Colors.blue;
        break;
      case 'tf':
        typeStr = 'صح/خطأ';
        typeColor = Colors.teal;
        break;
      case 'checkbox':
        typeStr = 'مربعات اختيار';
        typeColor = Colors.purple;
        break;
      case 'essay':
        typeStr = 'مقالي';
        typeColor = Colors.orange;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: typeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        typeStr,
        style: GoogleFonts.tajawal(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: typeColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Strictly matching Dark Fintech colors in global rules
    const Color cardColor = Color(0xFF222329);
    const Color borderColor = Color(0xFF2D2E36);
    const Color primaryColor = Color(0xFF6E56FF);
    const Color secondaryColor = Color(0xFF7DFFA2);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 600),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'تعديل السؤال الجديد' : 'معاينة السؤال الجديد',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildTypeBadge(_selectedType),
                ],
              ),
              const SizedBox(height: 16),
              
              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_isEditing) ...[
                        // Preview Mode Question Text
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF18191D),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: TexViewWidget(
                            text: _textController.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Preview Mode Options
                        if (_selectedType != 'essay') ...[
                          Text(
                            'الخيارات:',
                            style: GoogleFonts.tajawal(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(_optionIds.length, (index) {
                            final optId = _optionIds[index];
                            final optText = _optionControllers[index].text;
                            final isCorrect = _correctOptionIds.contains(optId);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isCorrect
                                    ? secondaryColor.withValues(alpha: 0.08)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCorrect ? secondaryColor : borderColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isCorrect ? secondaryColor : borderColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      optId,
                                      style: GoogleFonts.tajawal(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isCorrect ? Colors.black : Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TexViewWidget(
                                      text: optText,
                                      fontSize: 13,
                                      color: isCorrect ? secondaryColor : Colors.white70,
                                    ),
                                  ),
                                  if (isCorrect)
                                    const Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: secondaryColor,
                                      size: 16,
                                    ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                        ],

                        // Preview Mode Explanation
                        Text(
                          'شرح الحل:',
                          style: GoogleFonts.tajawal(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF18191D),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: TexViewWidget(
                            text: _explanationController.text.isNotEmpty ? _explanationController.text : 'لا يوجد شرح حل.',
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Preview Mode Topics
                        Text(
                          'المواضيع المرتبطة:',
                          style: GoogleFonts.tajawal(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _selectedTopicIds.isEmpty
                            ? Text(
                                'لا توجد مواضيع مرتبطة بهذا السؤال.',
                                style: GoogleFonts.tajawal(color: Colors.white30, fontSize: 12),
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(_selectedTopicIds.length, (idx) {
                                  return Chip(
                                    label: Text(
                                      _selectedTopicNames[idx],
                                      style: GoogleFonts.tajawal(fontSize: 11, color: Colors.white),
                                    ),
                                    backgroundColor: const Color(0xFF18191D),
                                    side: const BorderSide(color: borderColor),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  );
                                }),
                              ),
                      ] else ...[
                        // Edit Mode Question Text
                        TextFormField(
                          controller: _textController,
                          maxLines: 4,
                          style: GoogleFonts.tajawal(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'نص السؤال',
                            labelStyle: GoogleFonts.tajawal(color: Colors.white54, fontSize: 12),
                            fillColor: const Color(0xFF18191D),
                            filled: true,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: primaryColor),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Edit Mode Type Dropdown
                        Text(
                          'نوع السؤال:',
                          style: GoogleFonts.tajawal(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF18191D),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedType,
                              dropdownColor: cardColor,
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                              isExpanded: true,
                              items: [
                                DropdownMenuItem(
                                  value: 'mcq',
                                  child: Text('اختيار من متعدد', style: GoogleFonts.tajawal(color: Colors.white)),
                                ),
                                DropdownMenuItem(
                                  value: 'tf',
                                  child: Text('صح / خطأ', style: GoogleFonts.tajawal(color: Colors.white)),
                                ),
                                DropdownMenuItem(
                                  value: 'checkbox',
                                  child: Text('خيارات متعددة (مربعات اختيار)', style: GoogleFonts.tajawal(color: Colors.white)),
                                ),
                                DropdownMenuItem(
                                  value: 'essay',
                                  child: Text('سؤال مقالي', style: GoogleFonts.tajawal(color: Colors.white)),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedType = val;
                                    if (val == 'tf') {
                                      _optionIds = ['A', 'B'];
                                      for (var c in _optionControllers) {
                                        c.dispose();
                                      }
                                      _optionControllers = [
                                        TextEditingController(text: 'صح'),
                                        TextEditingController(text: 'خطأ'),
                                      ];
                                      _correctOptionIds = ['A'];
                                    } else if (val == 'essay') {
                                      _optionIds = [];
                                      for (var c in _optionControllers) {
                                        c.dispose();
                                      }
                                      _optionControllers = [];
                                      _correctOptionIds = [];
                                    } else {
                                      if (_optionIds.isEmpty) {
                                        _optionIds = ['A', 'B', 'C', 'D'];
                                        _optionControllers = List.generate(
                                          4,
                                          (i) => TextEditingController(
                                            text: 'الخيار ${String.fromCharCode(65 + i)}',
                                          ),
                                        );
                                        _correctOptionIds = ['A'];
                                      }
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Edit Mode Options Text Fields
                        if (_selectedType != 'essay') ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'الخيارات (حدد الخيارات الصحيحة):',
                                style: GoogleFonts.tajawal(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_selectedType != 'tf')
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      final nextId = String.fromCharCode(65 + _optionIds.length);
                                      _optionIds.add(nextId);
                                      _optionControllers.add(TextEditingController());
                                    });
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 14, color: secondaryColor),
                                  label: Text(
                                    'إضافة خيار',
                                    style: GoogleFonts.tajawal(color: secondaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(_optionIds.length, (index) {
                            final optId = _optionIds[index];
                            final isCorrect = _correctOptionIds.contains(optId);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isCorrect
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked_rounded,
                                      color: isCorrect ? secondaryColor : Colors.white30,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        if (_selectedType == 'checkbox') {
                                          if (isCorrect) {
                                            _correctOptionIds.remove(optId);
                                          } else {
                                            _correctOptionIds.add(optId);
                                          }
                                        } else {
                                          _correctOptionIds = [optId];
                                        }
                                      });
                                    },
                                  ),
                                  Container(
                                    width: 24,
                                    height: 24,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF18191D),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      optId,
                                      style: GoogleFonts.tajawal(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _optionControllers[index],
                                      style: GoogleFonts.tajawal(color: Colors.white, fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'أدخل نص الخيار...',
                                        hintStyle: GoogleFonts.tajawal(color: Colors.white24, fontSize: 12),
                                        fillColor: const Color(0xFF18191D),
                                        filled: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: borderColor),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: primaryColor),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_optionIds.length > 2 && _selectedType != 'tf')
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF4C6A), size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _optionControllers[index].dispose();
                                          _optionControllers.removeAt(index);
                                          _optionIds.removeAt(index);
                                          
                                          final Set<String> updatedCorrectOptionIds = {};
                                          for (int i = 0; i < _optionIds.length; i++) {
                                            final oldId = _optionIds[i];
                                            final newId = String.fromCharCode(65 + i);
                                            
                                            if (_correctOptionIds.contains(oldId)) {
                                              updatedCorrectOptionIds.add(newId);
                                            }
                                            _optionIds[i] = newId;
                                          }
                                          _correctOptionIds = updatedCorrectOptionIds.toList();
                                        });
                                      },
                                    ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                        ],

                        // Edit Mode Explanation
                        TextFormField(
                          controller: _explanationController,
                          maxLines: 4,
                          style: GoogleFonts.tajawal(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'شرح الحل وطريقة حل السؤال',
                            labelStyle: GoogleFonts.tajawal(color: Colors.white54, fontSize: 12),
                            fillColor: const Color(0xFF18191D),
                            filled: true,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: primaryColor),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Edit Mode Topics
                        Text(
                          'المواضيع المرتبطة:',
                          style: GoogleFonts.tajawal(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _isLoadingTopics
                                  ? const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        ..._selectedTopicIds.asMap().entries.map((entry) {
                                          final idx = entry.key;
                                          final name = _selectedTopicNames[idx];
                                          return Chip(
                                            label: Text(
                                              name,
                                              style: GoogleFonts.tajawal(fontSize: 11, color: Colors.white),
                                            ),
                                            deleteIcon: const Icon(Icons.close, size: 12, color: Colors.white70),
                                            onDeleted: () => setState(() {
                                              _selectedTopicIds.removeAt(idx);
                                              _selectedTopicNames.removeAt(idx);
                                            }),
                                            backgroundColor: primaryColor.withValues(alpha: 0.15),
                                            side: const BorderSide(color: borderColor),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          );
                                        }),
                                        ActionChip(
                                          label: Text(
                                            'إضافة موضوع',
                                            style: GoogleFonts.tajawal(
                                              fontSize: 11,
                                              color: secondaryColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          avatar: const Icon(
                                            Icons.add,
                                            size: 12,
                                            color: secondaryColor,
                                          ),
                                          onPressed: _showTopicSelectionDialog,
                                          backgroundColor: Colors.transparent,
                                          side: const BorderSide(color: secondaryColor),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Action Buttons Footer
              Row(
                children: [
                  if (!_isEditing) ...[
                    // Cancel
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'إلغاء',
                          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Edit
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _isEditing = true),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: Text(
                          'تعديل قبل الحفظ',
                          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Save
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saveAndPop,
                        icon: const Icon(Icons.save_rounded, size: 16),
                        label: Text(
                          'حفظ مباشر',
                          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Cancel Edit
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _resetEditFields();
                            _isEditing = false;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'إلغاء التعديل',
                          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Back to Preview
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                          });
                        },
                        icon: const Icon(Icons.remove_red_eye_rounded, size: 16),
                        label: Text(
                          'الرجوع للمعاينة',
                          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Direct Save from Edit mode
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saveAndPop,
                        icon: const Icon(Icons.save_rounded, size: 16),
                        label: Text(
                          'حفظ مباشر',
                          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
