import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quizzly/core/services/firebase_storage_service.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/core/widgets/rich_text_editor.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/admin/domain/services/pdf_parsing_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';

class QuestionManagementScreen extends StatefulWidget {
  final String? sectionId;
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
  State<QuestionManagementScreen> createState() =>
      _QuestionManagementScreenState();
}

class _QuestionManagementScreenState extends State<QuestionManagementScreen> {
  final DatabaseService _dbService = DatabaseService();

  late String selectedTypeId;
  late TextEditingController textController;
  late TextEditingController translationTextController;
  late TextEditingController essayAnswerController;
  late TextEditingController explanationController;
  late TextEditingController explanationImageUrlController;
  late TextEditingController explanationAudioUrlController;
  late TextEditingController explanationPdfUrlController;
  late TextEditingController explanationVideoUrlController;
  late TextEditingController timeController;
  late bool isEnabled;
  late Difficulty selectedDifficulty;

  List<Map<String, String>> options = [];
  List<String> correctOptionIds = [];
  List<TextEditingController> optionControllers = [];
  final Map<String, int> _optionVersions = {};
  final Map<String, bool> _isFormattingOption = {};

  // Visibility states for translation and explanation fields
  bool _showTranslation = false;
  bool _showExplanation = false;
  bool _isSolvingWithAI = false;
  bool _isGeneratingOptions = false;

  // Primary fintech color
  static const Color _primaryFintechColor = Color(0xFF6E56FF);

  // Topic selection
  List<String> selectedTopicIds = [];
  List<String> selectedTopicNames = [];
  List<Map<String, dynamic>> availableLessons = [];

  final List<Map<String, dynamic>> questionTypes = [
    {
      'id': 'mcq',
      'label': 'خيارات متعددة',
      'icon': Icons.radio_button_checked_rounded,
    },
    {
      'id': 'checkbox',
      'label': 'مربعات اختيار',
      'icon': Icons.check_box_rounded,
    },
    {'id': 'tf', 'label': 'صح/خطأ', 'icon': Icons.rule_rounded},
    {'id': 'essay', 'label': 'مقالي', 'icon': Icons.short_text_rounded},
  ];

  @override
  void initState() {
    super.initState();
    final currentData = widget.currentData;

    selectedTypeId = currentData?['type'] ?? 'mcq';
    textController = TextEditingController(text: currentData?['text']);
    translationTextController = TextEditingController(
      text: currentData?['translationText'] ?? '',
    );
    essayAnswerController = TextEditingController(
      text: currentData?['essayAnswer'],
    );
    explanationController = TextEditingController(
      text: currentData?['explanation'],
    );
    explanationImageUrlController = TextEditingController(
      text: currentData?['explanationImageUrl'],
    );
    explanationAudioUrlController = TextEditingController(
      text: currentData?['explanationAudioUrl'] ?? '',
    );
    explanationPdfUrlController = TextEditingController(
      text: currentData?['explanationPdfUrl'] ?? '',
    );
    explanationVideoUrlController = TextEditingController(
      text: currentData?['explanationVideoUrl'] ?? '',
    );
    timeController = TextEditingController(
      text: currentData?['estimatedTime']?.toString() ?? '60',
    );
    isEnabled = currentData?['isEnabled'] ?? true;

    selectedDifficulty = Difficulty.values.firstWhere(
      (e) => e.name == currentData?['difficulty'],
      orElse: () => Difficulty.medium,
    );

    options = (currentData?['options'] as List? ?? [])
        .map((e) => {'id': e['id'].toString(), 'text': e['text'].toString()})
        .toList();

    if (options.isEmpty) {
      if (selectedTypeId == 'tf') {
        options = [
          {'id': 'true', 'text': 'صح'},
          {'id': 'false', 'text': 'خطأ'},
        ];
      } else if (selectedTypeId == 'mcq' || selectedTypeId == 'checkbox') {
        options = [
          {'id': '1', 'text': ''},
        ];
      }
    }

    correctOptionIds =
        (currentData?['correctOptionIds'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        (currentData?['correctOptionId'] != null
            ? [currentData!['correctOptionId'].toString()]
            : []);

    if (correctOptionIds.isEmpty && options.isNotEmpty) {
      correctOptionIds = [options[0]['id']!];
    }

    optionControllers = options
        .map((opt) => TextEditingController(text: opt['text']))
        .toList();

    // Initialize topics
    if (widget.questionId != null) {
      selectedTopicIds = List<String>.from(currentData?['topicIds'] ?? []);
      selectedTopicNames = List<String>.from(currentData?['topicNames'] ?? []);
    } else if (widget.lessonId != null) {
      selectedTopicIds = [widget.lessonId!];
      selectedTopicNames = [widget.lessonName ?? 'درس غير معروف'];
    }

    _showTranslation = translationTextController.text.trim().isNotEmpty &&
        translationTextController.text.trim() != '<p></p>' &&
        translationTextController.text.trim() != '<p><br></p>';

    _showExplanation = (explanationController.text.trim().isNotEmpty &&
            explanationController.text.trim() != '<p></p>' &&
            explanationController.text.trim() != '<p><br></p>') ||
        explanationImageUrlController.text.isNotEmpty ||
        explanationAudioUrlController.text.isNotEmpty ||
        explanationPdfUrlController.text.isNotEmpty ||
        explanationVideoUrlController.text.isNotEmpty;

    _loadAvailableLessons();
  }

  Future<void> _loadAvailableLessons() async {
    try {
      // Get all topics for this subject to build the hierarchy
      final snapshot = await _dbService
          .getAllTopicsForSubject(widget.subjectId, sectionId: widget.sectionId)
          .first;
      if (mounted) {
        final allDocs = snapshot.docs;
        // Create a map for quick name lookup
        final Map<String, String> nameMap = {
          for (var doc in allDocs)
            doc.id: (doc.data() as Map<String, dynamic>)['name'] ?? '',
        };

        setState(() {
          // Filter for lessons and sort by creation order
          final lessonDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['type'] == 'lesson';
          }).toList();

          // Sort docs by createdAt locally (ascending = oldest to newest)
          lessonDocs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime =
                (aData['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final bTime =
                (bData['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return aTime.compareTo(bTime);
          });

          availableLessons = lessonDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final parentId = data['parentId'];
            final parentName = (parentId != null) ? nameMap[parentId] : null;

            // Format as "Chapter Name - Lesson Name"
            final fullName = parentName != null
                ? '$parentName - ${data['name']}'
                : data['name'] ?? '';

            return {'id': doc.id, 'name': fullName};
          }).toList();

          // Optional: Update current selected names if they are just lesson names
          if (widget.lessonId != null &&
              selectedTopicIds.contains(widget.lessonId)) {
            final idx = selectedTopicIds.indexOf(widget.lessonId!);
            final lessonData = availableLessons.firstWhere(
              (l) => l['id'] == widget.lessonId,
              orElse: () => <String, dynamic>{},
            );
            if (lessonData.isNotEmpty) {
              selectedTopicNames[idx] = lessonData['name'];
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading lessons: $e');
    }
  }

  @override
  void dispose() {
    textController.dispose();
    translationTextController.dispose();
    essayAnswerController.dispose();
    explanationController.dispose();
    explanationImageUrlController.dispose();
    explanationAudioUrlController.dispose();
    explanationPdfUrlController.dispose();
    explanationVideoUrlController.dispose();
    timeController.dispose();
    for (var c in optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _showStatusSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child, Widget? action}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? []
            : [
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              action ?? const SizedBox.shrink(),
            ],
          ),
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
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: isDark ? Colors.white : Colors.black87,
              ),
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
              Text(
                'مفعل',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: isEnabled,
                  activeThumbColor: AppColors.primaryBlue,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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

  final List<String> _pendingImageDeletions = [];

  Future<void> _saveQuestion(bool isEdit) async {
    if (textController.text.trim().isEmpty) {
      _showStatusSnackBar('يرجى كتابة نص السؤال', isError: true);
      return;
    }

    final Map<String, dynamic> questionData = {
      'text': textController.text.trim(),
      'translationText': _showTranslation ? translationTextController.text.trim() : '',
      'type': selectedTypeId,
      'subjectId': widget.subjectId,
      'explanation': _showExplanation ? explanationController.text.trim() : '',
      'explanationImageUrl': _showExplanation ? explanationImageUrlController.text.trim() : '',
      'explanationAudioUrl': _showExplanation ? explanationAudioUrlController.text.trim() : '',
      'explanationPdfUrl': _showExplanation ? explanationPdfUrlController.text.trim() : '',
      'explanationVideoUrl': _showExplanation ? explanationVideoUrlController.text.trim() : '',
      'difficulty': selectedDifficulty.name,
      'primaryTopicId': selectedTopicIds.isNotEmpty
          ? selectedTopicIds.first
          : (widget.lessonId ?? 'global'),
      'topicIds': selectedTopicIds,
      'topicNames': selectedTopicNames,
      'topicWeights': {for (var id in selectedTopicIds) id: 1.0},
      'discriminationIndex': 0.5,
      'isFrequentlyWrong': false,
      'parentId': widget.sectionId ?? 'global',
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
      String? returnedId;
      if (isEdit) {
        await _dbService.updateDoc(
          DatabaseService.colQuestions,
          widget.questionId!,
          questionData,
        );
        returnedId = widget.questionId;
      } else {
        final ref = await _dbService.addQuestion(
          widget.sectionId ?? 'global',
          questionData,
        );
        returnedId = ref.id;
      }

      // After successful save, delete images that were removed in the editor
      if (_pendingImageDeletions.isNotEmpty) {
        final storageService = FirebaseStorageService();
        for (final url in _pendingImageDeletions) {
          await storageService.deleteFileByUrl(url);
        }
      }

      if (mounted) {
        navigator.pop(returnedId);
      }
    } catch (e) {
      if (mounted) _showStatusSnackBar('حدث خطأ: $e', isError: true);
    }
  }

  Future<void> _solveQuestion() async {
    final text = textController.text.trim();
    if (text.isEmpty) {
      _showStatusSnackBar('يرجى كتابة نص السؤال أولاً ليتمكن الذكاء الاصطناعي من حله', isError: true);
      return;
    }

    setState(() => _isSolvingWithAI = true);

    try {
      final optionsList = options.map((o) => (o['text'] ?? '').trim()).where((t) => t.isNotEmpty).toList();
      final solution = await PDFParsingService().solveQuestionWithAI(text, optionsList);
      
      setState(() {
        explanationController.text = solution;
        _isSolvingWithAI = false;
      });
      _showStatusSnackBar('تم توليد حل السؤال بنجاح!', isError: false);
    } catch (e) {
      setState(() => _isSolvingWithAI = false);
      _showStatusSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  Future<void> _generateOptions() async {
    final text = textController.text.trim();
    if (text.isEmpty) {
      _showStatusSnackBar('يرجى كتابة نص السؤال أولاً ليتمكن الذكاء الاصطناعي من توليد الخيارات', isError: true);
      return;
    }
    if (correctOptionIds.isEmpty) {
      _showStatusSnackBar('يرجى تحديد الإجابة الصحيحة أولاً ليتمكن النظام من توليد الخيارات البديلة لها', isError: true);
      return;
    }

    final correctOpt = options.firstWhere((o) => o['id'] == correctOptionIds.first, orElse: () => {});
    final correctAnswer = (correctOpt['text'] ?? '').trim();
    if (correctAnswer.isEmpty) {
      _showStatusSnackBar('يرجى كتابة نص الإجابة الصحيحة أولاً لتوليد خيارات مشابهة لها', isError: true);
      return;
    }

    setState(() => _isGeneratingOptions = true);

    try {
      final wrongOptions = await PDFParsingService().generateOptionsWithAI(text, correctAnswer);
      
      setState(() {
        final correctId = correctOptionIds.first;
        
        options = [{'id': correctId, 'text': correctAnswer}];
        for (var c in optionControllers) {
          c.dispose();
        }
        optionControllers = [TextEditingController(text: correctAnswer)];
        
        for (int i = 0; i < wrongOptions.length; i++) {
          final newId = (DateTime.now().millisecondsSinceEpoch + i + 1).toString();
          options.add({'id': newId, 'text': wrongOptions[i]});
          optionControllers.add(TextEditingController(text: wrongOptions[i]));
        }
        
        _isGeneratingOptions = false;
      });
      _showStatusSnackBar('تم توليد الخيارات البديلة بنجاح!', isError: false);
    } catch (e) {
      setState(() => _isGeneratingOptions = false);
      _showStatusSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  Future<void> _formatOptionText(int index) async {
    final opt = options[index];
    final text = (opt['text'] ?? '').trim();
    final cleanText = text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    if (cleanText.isEmpty) {
      _showStatusSnackBar('يرجى كتابة نص الخيار أولاً ليتمكن الذكاء الاصطناعي من تنسيقه', isError: true);
      return;
    }

    setState(() {
      _isFormattingOption[opt['id']!] = true;
    });

    try {
      final formattedText = await PDFParsingService().formatOptionWithAI(cleanText);
      
      setState(() {
        opt['text'] = formattedText;
        _optionVersions[opt['id']!] = (_optionVersions[opt['id']!] ?? 0) + 1;
        _isFormattingOption[opt['id']!] = false;
      });
      _showStatusSnackBar('تم تنسيق الخيار بالمعادلات بنجاح!', isError: false);
    } catch (e) {
      setState(() {
        _isFormattingOption[opt['id']!] = false;
      });
      _showStatusSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  bool _isUploadingFile = false;
  String? _uploadingFileType; // 'image', 'audio', 'pdf'

  Future<void> _pickAndUploadFile(String fileType) async {
    try {
      FileType pickerType;
      List<String>? allowedExtensions;
      String folderName;

      if (fileType == 'image') {
        pickerType = FileType.image;
        folderName = 'explanation_images';
      } else if (fileType == 'audio') {
        pickerType = FileType.audio;
        folderName = 'explanation_audios';
      } else if (fileType == 'pdf') {
        pickerType = FileType.custom;
        allowedExtensions = ['pdf'];
        folderName = 'explanation_pdfs';
      } else if (fileType == 'video') {
        pickerType = FileType.video;
        folderName = 'explanation_videos';
      } else {
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: pickerType,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes == null) {
          _showStatusSnackBar(
            'لا يمكن قراءة بيانات الملف المختار',
            isError: true,
          );
          return;
        }

        setState(() {
          _isUploadingFile = true;
          _uploadingFileType = fileType;
        });

        final storageService = FirebaseStorageService();
        final url = await storageService.uploadFile(
          fileBytes: file.bytes!,
          fileExtension:
              file.extension ??
              (fileType == 'pdf'
                  ? 'pdf'
                  : (fileType == 'audio' ? 'mp3' : 'png')),
          folderName: folderName,
        );

        setState(() {
          _isUploadingFile = false;
          _uploadingFileType = null;
        });

        if (url != null) {
          setState(() {
            if (fileType == 'image') {
              explanationImageUrlController.text = url;
            } else if (fileType == 'audio') {
              explanationAudioUrlController.text = url;
            } else if (fileType == 'pdf') {
              explanationPdfUrlController.text = url;
            } else if (fileType == 'video') {
              explanationVideoUrlController.text = url;
            }
          });
          _showStatusSnackBar('تم رفع الملف بنجاح!', isError: false);
        } else {
          _showStatusSnackBar(
            'فشل رفع الملف إلى الخادم الرئيسي',
            isError: true,
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploadingFile = false;
        _uploadingFileType = null;
      });
      _showStatusSnackBar('حدث خطأ أثناء رفع الملف: $e', isError: true);
    }
  }

  Widget _buildAttachmentCard({
    required String title,
    required IconData icon,
    required String url,
    required String fileType,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasAttachment = url.isNotEmpty;
    final isUploadingThisType =
        _isUploadingFile && _uploadingFileType == fileType;

    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasAttachment
              ? color
              : (isDark ? Colors.white10 : Colors.grey.shade300),
          width: hasAttachment ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isUploadingThisType
              ? null
              : () {
                  if (hasAttachment) {
                    _showAttachmentOptionsDialog(title, url, fileType);
                  } else {
                    _pickAndUploadFile(fileType);
                  }
                },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 12.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isUploadingThisType)
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                else
                  Icon(
                    hasAttachment ? Icons.check_circle_rounded : icon,
                    color: hasAttachment
                        ? color
                        : (isDark ? Colors.white30 : Colors.grey.shade400),
                    size: 28,
                  ),
                const SizedBox(height: 8),
                Text(
                  hasAttachment ? 'تم الإرفاق' : title,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: hasAttachment
                        ? color
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAttachmentOptionsDialog(String title, String url, String fileType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.open_in_new_rounded,
                color: AppColors.primaryBlue,
              ),
              title: Text('عرض/استعراض الملف', style: GoogleFonts.cairo()),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  _showStatusSnackBar('تعذر فتح الملف: $e', isError: true);
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.delete_forever_rounded,
                color: Colors.red,
              ),
              title: Text(
                'حذف المرفق',
                style: GoogleFonts.cairo(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  if (fileType == 'image') {
                    explanationImageUrlController.clear();
                  } else if (fileType == 'audio') {
                    explanationAudioUrlController.clear();
                  } else if (fileType == 'pdf') {
                    explanationPdfUrlController.clear();
                  } else if (fileType == 'video') {
                    explanationVideoUrlController.clear();
                  }
                });
                _showStatusSnackBar('تم حذف المرفق بنجاح', isError: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.questionId != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      Text(
                        'نوع السؤال',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 220,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey[50],
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.grey[300]!,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedTypeId,
                            isExpanded: true,
                            dropdownColor: isDark
                                ? const Color(0xFF131A26)
                                : Colors.white,
                            onChanged: (val) {
                              setState(() {
                                final oldType = selectedTypeId;
                                selectedTypeId = val!;

                                if (selectedTypeId == 'tf') {
                                  options = [
                                    {'id': 'true', 'text': 'صح'},
                                    {'id': 'false', 'text': 'خطأ'},
                                  ];
                                  for (var c in optionControllers) {
                                    c.dispose();
                                  }
                                  optionControllers.clear();
                                  optionControllers.addAll(
                                    options.map(
                                      (o) => TextEditingController(
                                        text: o['text'],
                                      ),
                                    ),
                                  );
                                  correctOptionIds = ['true'];
                                } else if (selectedTypeId == 'essay') {
                                  options = [];
                                  for (var c in optionControllers) {
                                    c.dispose();
                                  }
                                  optionControllers.clear();
                                  correctOptionIds = [];
                                } else if (oldType == 'tf' ||
                                    oldType == 'essay') {
                                  options = [
                                    {'id': '1', 'text': ''},
                                  ];
                                  for (var c in optionControllers) {
                                    c.dispose();
                                  }
                                  optionControllers.clear();
                                  optionControllers.add(
                                    TextEditingController(),
                                  );
                                  correctOptionIds = ['1'];
                                }
                              });
                            },
                            items: questionTypes
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type['id'] as String,
                                    child: Row(
                                      children: [
                                        Icon(
                                          type['icon'] as IconData,
                                          size: 20,
                                          color: AppColors.primaryBlue,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          type['label'] as String,
                                          style: GoogleFonts.cairo(
                                            fontSize: 14,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'نص السؤال',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RichTextEditor(
                        initialHtml: textController.text,
                        placeholder: 'اكتب نص السؤال هنا',
                        height: 200,
                        onContentChanged: (html) {
                          textController.text = html;
                        },
                        onImageDeleted: (url) =>
                            _pendingImageDeletions.add(url),
                      ),
                      if (_showTranslation) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ترجمة السؤال (اختياري)',
                              style: GoogleFonts.tajawal(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                              tooltip: 'حذف الترجمة',
                              onPressed: () {
                                setState(() {
                                  _showTranslation = false;
                                  translationTextController.clear();
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        RichTextEditor(
                          initialHtml: translationTextController.text,
                          placeholder: 'ترجمة نص السؤال بالعربية...',
                          height: 150,
                          onContentChanged: (html) {
                            translationTextController.text = html;
                          },
                          onImageDeleted: (url) =>
                              _pendingImageDeletions.add(url),
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showTranslation = true;
                            });
                          },
                          icon: const Icon(Icons.translate_rounded, size: 20, color: _primaryFintechColor),
                          label: Text(
                            'إضافة ترجمة للسؤال',
                            style: GoogleFonts.tajawal(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _primaryFintechColor,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _primaryFintechColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (selectedTypeId != 'essay')
                  _buildSection(
                    title: 'الخيارات والإجابة',
                    action: (selectedTypeId == 'mcq' || selectedTypeId == 'checkbox')
                        ? (_isGeneratingOptions
                            ? const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _primaryFintechColor),
                                ),
                              )
                            : TextButton.icon(
                                onPressed: _generateOptions,
                                icon: const Icon(Icons.auto_awesome_rounded, size: 14, color: _primaryFintechColor),
                                label: Text(
                                  'توليد الخيارات بالذكاء الاصطناعي',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _primaryFintechColor,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                              ))
                        : null,
                    child: selectedTypeId == 'checkbox'
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _buildOptionsList(isDark),
                          )
                        : RadioGroup<String>(
                            groupValue: correctOptionIds.isNotEmpty
                                ? correctOptionIds.first
                                : null,
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => correctOptionIds = [v]);
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _buildOptionsList(isDark),
                            ),
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                _buildSection(
                  title: 'معلومات إضافية',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_showExplanation) ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showExplanation = true;
                            });
                          },
                          icon: const Icon(Icons.add_comment_rounded, size: 20, color: _primaryFintechColor),
                          label: Text(
                            'إضافة شرح ومرفقات للسؤال',
                            style: GoogleFonts.tajawal(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _primaryFintechColor,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _primaryFintechColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'شرح الإجابة (اختياري)',
                              style: GoogleFonts.tajawal(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                              tooltip: 'حذف الشرح والمرفقات',
                              onPressed: () {
                                setState(() {
                                  _showExplanation = false;
                                  explanationController.clear();
                                  explanationImageUrlController.clear();
                                  explanationAudioUrlController.clear();
                                  explanationPdfUrlController.clear();
                                  explanationVideoUrlController.clear();
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // AI Solver Bar
                        if (_isSolvingWithAI)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: CircularProgressIndicator(color: _primaryFintechColor),
                            ),
                          )
                        else ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _solveQuestion,
                              icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
                              label: Text(
                                'حل وتوليد الشرح بالذكاء الاصطناعي',
                                style: GoogleFonts.tajawal(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryFintechColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        RichTextEditor(
                          initialHtml: explanationController.text,
                          placeholder: 'اكتب الشرح هنا...',
                          height: 150,
                          onContentChanged: (html) {
                            explanationController.text = html;
                          },
                          onImageDeleted: (url) =>
                              _pendingImageDeletions.add(url),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'مرفقات الشرح (صورة، صوت، فيديو أو PDF)',
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width:
                                  (MediaQuery.of(context).size.width - 48 - 12) /
                                  2,
                              child: _buildAttachmentCard(
                                title: 'صورة توضيحية',
                                icon: Icons.image_rounded,
                                url: explanationImageUrlController.text,
                                fileType: 'image',
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            SizedBox(
                              width:
                                  (MediaQuery.of(context).size.width - 48 - 12) /
                                  2,
                              child: _buildAttachmentCard(
                                title: 'مقطع صوتي',
                                icon: Icons.audiotrack_rounded,
                                url: explanationAudioUrlController.text,
                                fileType: 'audio',
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                            SizedBox(
                              width:
                                  (MediaQuery.of(context).size.width - 48 - 12) /
                                  2,
                              child: _buildAttachmentCard(
                                title: 'مقطع فيديو',
                                icon: Icons.videocam_rounded,
                                url: explanationVideoUrlController.text,
                                fileType: 'video',
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                            SizedBox(
                              width:
                                  (MediaQuery.of(context).size.width - 48 - 12) /
                                  2,
                              child: _buildAttachmentCard(
                                title: 'ملف PDF',
                                icon: Icons.picture_as_pdf_rounded,
                                url: explanationPdfUrlController.text,
                                fileType: 'pdf',
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<Difficulty>(
                              initialValue: selectedDifficulty,
                              dropdownColor: isDark
                                  ? const Color(0xFF131A26)
                                  : Colors.white,
                              decoration: InputDecoration(
                                labelText: 'الصعوبة',
                                labelStyle: GoogleFonts.cairo(),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: Difficulty.values
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(
                                        _translateDifficulty(e),
                                        style: GoogleFonts.cairo(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => selectedDifficulty = v!),
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      Text(
                        'المواضيع المرتبطة',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...selectedTopicIds.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final name = selectedTopicNames[idx];
                            return Chip(
                              label: Text(
                                name,
                                style: GoogleFonts.cairo(fontSize: 12),
                              ),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () => setState(() {
                                selectedTopicIds.removeAt(idx);
                                selectedTopicNames.removeAt(idx);
                              }),
                              backgroundColor: AppColors.primaryBlue.withValues(
                                alpha: 0.1,
                              ),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            );
                          }),
                          ActionChip(
                            label: Text(
                              'إضافة موضوع',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            avatar: const Icon(
                              Icons.add,
                              size: 14,
                              color: AppColors.primaryBlue,
                            ),
                            onPressed: _showTopicSelectionDialog,
                            backgroundColor: Colors.transparent,
                            side: const BorderSide(
                              color: AppColors.primaryBlue,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
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

  void _showTopicSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              'اختر المواضيع',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            content: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: availableLessons.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد مواضيع متاحة',
                        style: GoogleFonts.cairo(),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: availableLessons.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final lesson = availableLessons[index];
                        final isSelected = selectedTopicIds.contains(
                          lesson['id'],
                        );
                        return CheckboxListTile(
                          title: Text(
                            lesson['name'],
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          value: isSelected,
                          activeColor: AppColors.primaryBlue,
                          onChanged: (val) {
                            setState(() {
                              if (val ?? false) {
                                if (!selectedTopicIds.contains(lesson['id'])) {
                                  selectedTopicIds.add(lesson['id']);
                                  selectedTopicNames.add(lesson['name']);
                                }
                              } else {
                                final idx = selectedTopicIds.indexOf(
                                  lesson['id'],
                                );
                                if (idx != -1) {
                                  selectedTopicIds.removeAt(idx);
                                  selectedTopicNames.removeAt(idx);
                                }
                              }
                            });
                            setDialogState(() {}); // Update dialog UI
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
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _translateDifficulty(Difficulty d) {
    switch (d) {
      case Difficulty.easy:
        return 'سهل';
      case Difficulty.medium:
        return 'متوسط';
      case Difficulty.hard:
        return 'صعب';
    }
  }

  List<Widget> _buildOptionsList(bool isDark) {
    return [
      ...options.asMap().entries.map((entry) {
        final index = entry.key;
        final opt = entry.value;
        final isCorrect = correctOptionIds.contains(opt['id']);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isCorrect
                ? Colors.green.withValues(alpha: 0.1)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.02)
                      : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCorrect
                  ? Colors.green
                  : (isDark ? Colors.white10 : Colors.grey.shade300),
              width: isCorrect ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الخيار ${index + 1}',
                      style: GoogleFonts.tajawal(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white60 : Colors.grey.shade700,
                      ),
                    ),
                    _isFormattingOption[opt['id']] == true
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primaryFintechColor,
                            ),
                          )
                        : TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _formatOptionText(index),
                            icon: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 14,
                              color: _primaryFintechColor,
                            ),
                            label: Text(
                              'معالجة بالذكاء الاصطناعي',
                              style: GoogleFonts.tajawal(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _primaryFintechColor,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 0.5),
              Row(
                children: [
                  if (selectedTypeId == 'checkbox')
                    Checkbox(
                      value: isCorrect,
                      activeColor: Colors.green,
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
                      activeColor: Colors.green,
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: RichTextEditor(
                        key: ValueKey('${opt['id']}_${_optionVersions[opt['id']] ?? 0}'),
                        initialHtml: opt['text'],
                        placeholder: 'الخيار ${index + 1}',
                        height: 100,
                        isCompact: true,
                        onContentChanged: (html) {
                          opt['text'] = html;
                        },
                        onImageDeleted: (url) => _pendingImageDeletions.add(url),
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
            ],
          ),
        );
      }),
      if (selectedTypeId != 'tf')
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 20),
            label: Text(
              'إضافة خيار جديد',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryBlue,
              side: const BorderSide(color: AppColors.primaryBlue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => setState(() {
              final newId = DateTime.now().millisecondsSinceEpoch.toString();
              options.add({'id': newId, 'text': ''});
              optionControllers.add(TextEditingController());
            }),
          ),
        ),
    ];
  }
}
