import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/home/data/models/college_model.dart';
import 'package:quizzly/features/home/domain/services/college_service.dart';

// ─────────────────────────────────────────
//  STEP 1: Choose Activation Method
// ─────────────────────────────────────────
class ActivationStep1Sheet extends StatelessWidget {
  final VoidCallback onContinueWithoutCode;
  final VoidCallback onAddCode;

  const ActivationStep1Sheet({
    super.key,
    required this.onContinueWithoutCode,
    required this.onAddCode,
  });

  @override
  Widget build(BuildContext context) {
    return _SheetWrapper(
      title: 'كيف تريد المتابعة؟',
      subtitle: 'اختر طريقة الوصول إلى المحتوى',
      child: Column(
        children: [
          _MethodCard(
            icon: Icons.play_circle_rounded,
            iconColor: const Color(0xFF16A34A),
            iconBg: const Color(0xFFDCFCE7),
            title: 'المتابعة بدون كود',
            subtitle: 'استعرض المحتوى التجريبي المتاح مجاناً',
            onTap: onContinueWithoutCode,
          ),
          const SizedBox(height: 14),
          _MethodCard(
            icon: Icons.vpn_key_rounded,
            iconColor: AppColors.primaryBlue,
            iconBg: const Color(0xFFDBEAFE),
            title: 'إضافة كود',
            subtitle: 'أدخل كود التفعيل للوصول إلى المحتوى الكامل',
            onTap: onAddCode,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  STEP 2: Enter Code
// ─────────────────────────────────────────
class ActivationStep2Sheet extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(String code) onNext;

  const ActivationStep2Sheet({
    super.key,
    required this.onBack,
    required this.onNext,
  });

  @override
  State<ActivationStep2Sheet> createState() => _ActivationStep2SheetState();
}

class _ActivationStep2SheetState extends State<ActivationStep2Sheet> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _hasText = _controller.text.trim().isNotEmpty);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetWrapper(
      title: 'أدخل كود التفعيل',
      subtitle: 'أدخل الكود الخاص بك أو امسح رمز QR',
      onBack: widget.onBack,
      child: Column(
        children: [
          // Text Field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textDirection: TextDirection.ltr,
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      letterSpacing: 1.2,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX',
                      hintStyle: GoogleFonts.cairo(
                        fontSize: 13,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                    ),
                  ),
                ),
                // QR Icon
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppColors.iconBlue,
                    size: 28,
                  ),
                  padding: const EdgeInsets.only(left: 8),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'الكود عبارة عن معرّف فريد (GUID) مكوّن من 36 حرفاً',
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _hasText
                ? () => widget.onNext(_controller.text.trim())
                : null,
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: AppColors.borderLight,
              disabledForegroundColor: AppColors.textSecondary,
            ),
            child: const Text('التالي'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  STEP 3: Select Colleges to Activate
// ─────────────────────────────────────────
class ActivationStep3Sheet extends StatefulWidget {
  final String code;
  final VoidCallback onBack;
  final VoidCallback onActivated;

  const ActivationStep3Sheet({
    super.key,
    required this.code,
    required this.onBack,
    required this.onActivated,
  });

  @override
  State<ActivationStep3Sheet> createState() => _ActivationStep3SheetState();
}

class _ActivationStep3SheetState extends State<ActivationStep3Sheet> {
  final Map<String, bool> _selected = {};

  bool get _hasSelection => _selected.values.any((v) => v);

  @override
  Widget build(BuildContext context) {
    return _SheetWrapper(
      title: 'اختر ما تريد تفعيله',
      subtitle: 'حدّد الكليات التي يشملها الكود',
      onBack: widget.onBack,
      child: Column(
        children: [
          StreamBuilder<List<CollegeModel>>(
            stream: context.read<CollegeService>().getAvailableColleges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final colleges = snapshot.data ?? [];

              if (colleges.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'لا توجد كليات متاحة حالياً',
                    style: GoogleFonts.cairo(color: AppColors.textSecondary),
                  ),
                );
              }

              return Column(
                children: colleges.map((college) {
                  // Initialize selection state for new colleges
                  _selected.putIfAbsent(college.id, () => false);
                  final isSelected = _selected[college.id]!;

                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selected[college.id] = !isSelected),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryBlue.withValues(alpha: 0.06)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryBlue.withValues(alpha: 0.4)
                              : AppColors.borderLight,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Checkbox
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryBlue
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryBlue
                                    : AppColors.borderLight,
                                width: 1.5,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          // Icon
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryBlue.withValues(alpha: 0.1)
                                  : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              college.icon,
                              size: 22,
                              color: isSelected
                                  ? AppColors.primaryBlue
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Name
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  college.name,
                                  style: GoogleFonts.cairo(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? AppColors.primaryBlue
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${college.subjectCount} مواد',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _hasSelection ? widget.onActivated : null,
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: AppColors.borderLight,
              disabledForegroundColor: AppColors.textSecondary,
            ),
            child: const Text('تنشيط'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Shared Bottom Sheet Wrapper
// ─────────────────────────────────────────
class _SheetWrapper extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;

  const _SheetWrapper({
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Back button + Title row
            Row(
              children: [
                if (onBack != null)
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 38),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 46), // Balance the row
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            child,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Method Card (Step 1)
// ─────────────────────────────────────────
class _MethodCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 32, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_back_ios_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
