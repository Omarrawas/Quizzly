import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';

class CreateTrainingSessionScreen extends StatefulWidget {
  final String subjectName;

  const CreateTrainingSessionScreen({
    super.key,
    required this.subjectName,
  });

  @override
  State<CreateTrainingSessionScreen> createState() => _CreateTrainingSessionScreenState();
}

class _CreateTrainingSessionScreenState extends State<CreateTrainingSessionScreen> {
  // للتبسيط، نستخدم controllers وعدة متغيرات حالة للواجهة
  final TextEditingController _nameController = TextEditingController(text: 'جلسة تدريب جديدة');
  final TextEditingController _maxQuestionsController = TextEditingController();
  final TextEditingController _maxTimeController = TextEditingController();

  bool _randomize = false;
  bool _examMode = false;

  // حالة الأكورديون (Expansion Panels)
  bool _examsExpanded = false;
  bool _bankExpanded = false;
  bool _tagsExpanded = false;
  bool _filtersExpanded = false;

  // القيم الافتراضية للملخص (Mock data)
  final int _totalSubjectQuestions = 330;
  final int _selectedExams = 1; // كمثال للإحصائيات في الصورة
  final int _availableQuestions = 100;
  int get _finalQuestionCount {
    if (_maxQuestionsController.text.isNotEmpty) {
      return int.tryParse(_maxQuestionsController.text) ?? _availableQuestions;
    }
    return _availableQuestions;
  }

  void _resetForm() {
    setState(() {
      _nameController.text = 'جلسة تدريب جديدة';
      _maxQuestionsController.clear();
      _maxTimeController.clear();
      _randomize = false;
      _examMode = false;
    });
  }

  void _createSession() {
    // Show success dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0FDF4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 30),
                ),
                const SizedBox(height: 16),
                Text(
                  'تم إنشاء الجلسة بنجاح',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'تم إنشاء جلسة تدريب تحتوي على $_finalQuestionCount سؤال',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(context, true); // Return to training list with true
                        },
                        child: Text(
                          'لاحقاً',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(context, true); // Return to training list
                          // TODO: Navigate directly to QuizScreen
                        },
                        child: Text(
                          'ابدأ',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Text Fields
            _buildTextField(
              label: 'اسم الجلسة',
              controller: _nameController,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'الحد الأقصى لعدد الأسئلة',
              hint: 'اتركه فارغاً للحصول على جميع الأسئلة',
              controller: _maxQuestionsController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'الوقت الأقصى للجلسة (بالدقائق)',
              hint: 'مثال: 60',
              controller: _maxTimeController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // ── Checkboxes
            _buildCheckboxRow('ترتيب الأسئلة عشوائياً', _randomize, (v) {
              setState(() => _randomize = v ?? false);
            }),
            _buildCheckboxRow('إخفاء المعلومات الإضافية (وضع الامتحان)', _examMode, (v) {
              setState(() => _examMode = v ?? false);
            }),
            const SizedBox(height: 24),

            // ── Accordions
            _buildAccordion(
              title: 'الامتحانات',
              isExpanded: _examsExpanded,
              onTap: () => setState(() => _examsExpanded = !_examsExpanded),
              hasCheckbox: true,
              body: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('قائمة الامتحانات هنا...'),
              ),
            ),
            _buildAccordion(
              title: 'بنك الأسئلة',
              isExpanded: _bankExpanded,
              onTap: () => setState(() => _bankExpanded = !_bankExpanded),
              hasCheckbox: true,
              body: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('خيارات بنك الأسئلة هنا...'),
              ),
            ),
            _buildAccordion(
              title: 'الوسوم',
              isExpanded: _tagsExpanded,
              onTap: () => setState(() => _tagsExpanded = !_tagsExpanded),
              hasCheckbox: true,
              body: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('قائمة الوسوم هنا...'),
              ),
            ),
            _buildAccordion(
              title: 'الفلاتر',
              isExpanded: _filtersExpanded,
              onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
              body: Column(
                children: [
                  _buildSubFilterCheckbox('من قائمة: المفضلة'),
                  _buildSubFilterCheckbox('من قائمة: مهم'),
                  _buildSubFilterCheckbox('من الأسئلة المصححة فقط'),
                  _buildSubFilterCheckbox('من الإجابات الخاطئة فقط'),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Summary Box
            _buildSummaryBox(),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      automaticallyImplyLeading: false,
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(
          Icons.arrow_forward_ios_rounded,
          color: AppColors.textPrimary,
          size: 20,
        ),
      ),
      title: Text(
        'إعداد جلسة تدريب',
        style: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFF1F5F9)),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    String? hint,
    required TextEditingController controller,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: GoogleFonts.cairo(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryBlue),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxRow(String title, bool value, void Function(bool?) onChanged) {
    return Theme(
      data: ThemeData(
        unselectedWidgetColor: AppColors.borderLight,
        checkboxTheme: CheckboxThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      child: CheckboxListTile(
        title: Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primaryBlue,
        checkColor: Colors.white,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }

  Widget _buildAccordion({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    bool hasCheckbox = false,
    required Widget body,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (hasCheckbox)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: false, // مكدس للتوضيح
                        onChanged: (v) {},
                        activeColor: AppColors.primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Column(
              children: [
                const Divider(height: 1),
                body,
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSubFilterCheckbox(String title) {
    return _buildCheckboxRow(title, false, (v) {});
  }

  Widget _buildSummaryBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // خلفية رمادية فاتحة
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'حالة الجلسة',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // Rows
          _buildSummaryRow('الأوراق المحددة', '$_selectedExams امتحان'),
          const SizedBox(height: 8),
          _buildSummaryRow('إجمالي أسئلة المادة', '$_totalSubjectQuestions أسئلة'),
          const SizedBox(height: 8),
          _buildSummaryRow('إجمالي الأسئلة المتاحة', '$_availableQuestions أسئلة'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.borderLight, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'العدد النهائي للأسئلة:',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$_finalQuestionCount أسئلة',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'نسبة التغطية:',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${((_finalQuestionCount / _totalSubjectQuestions) * 100).toStringAsFixed(0)}% ($_finalQuestionCount من $_totalSubjectQuestions)',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: TextButton(
              onPressed: _resetForm,
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.borderLight),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'إعادة تعيين',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _createSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'إنشاء',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
