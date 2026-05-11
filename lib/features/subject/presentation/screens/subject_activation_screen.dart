import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/home/domain/services/content_service.dart';

class SubjectActivationScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final String subjectCode;
  final double? basePrice;
  final double? discount;

  const SubjectActivationScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    this.basePrice,
    this.discount,
  });

  @override
  State<SubjectActivationScreen> createState() => _SubjectActivationScreenState();
}

class _SubjectActivationScreenState extends State<SubjectActivationScreen> {
  bool _isLoading = false;

  Future<void> _activateFree() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final contentService = Provider.of<ContentService>(context, listen: false);
    final userId = authService.user?.uid;

    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      await contentService.addUserSubject(userId, widget.subjectId);
      if (!mounted) return;
      _showSuccess('تم تفعيل المادة بنجاح ✨ استمتع بالدراسة!');
      Navigator.pop(context); // Go back to selection
    } catch (e) {
      _showError('حدث خطأ أثناء التفعيل، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCodeDialog() {
    final contentService = context.read<ContentService>();
    final authService = context.read<AuthService>();
    final userId = authService.user?.uid;
    if (userId == null) return;

    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('تفعيل بواسطة كود', textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'أدخل الكود الخاص بالمادة لتفعيلها مباشرة',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: codeController,
              textAlign: TextAlign.center,
              autofocus: true,
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2),
              decoration: InputDecoration(
                hintText: 'ABCD-1234',
                hintStyle: GoogleFonts.inter(color: Colors.grey[300]),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty) return;
              
              Navigator.pop(context); // Close dialog
              setState(() => _isLoading = true);
              
              try {
                final result = await contentService.resolveContentCode(code);
                if (result == null) {
                  _showError('الكود الذي أدخلته غير صحيح');
                } else {
                  if (result['type'] == 'subject') {
                    await contentService.addUserSubject(userId, result['targetId'], activationCode: code);
                  } else {
                    await contentService.addUserSemester(userId, result['targetId'], activationCode: code);
                  }
                  _showSuccess('تم التفعيل بنجاح ✅');
                  if (mounted) Navigator.pop(context);
                }
              } catch (e) {
                _showError('حدث خطأ أثناء معالجة الكود');
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('تفعيل', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.cairo()),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.cairo()),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Icon Section
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Hero(
                      tag: 'subject_icon_${widget.subjectId}',
                      child: const Icon(Icons.lock_open_rounded, size: 80, color: AppColors.primaryBlue),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Title Section
                  Text(
                    'تفعيل مادة دراسية',
                    style: GoogleFonts.cairo(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.subjectName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'رمز المادة: ${widget.subjectCode}',
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w600, letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Price Section
                  if (widget.basePrice != null && widget.basePrice! > 0) 
                    _buildPriceSection(),
                  const SizedBox(height: 32),
                  // Options Section
                  _buildActivationOption(
                    title: 'تفعيل مجاني',
                    subtitle: 'فعل المادة مجاناً لتجربة بعض الامتحانات المجانية',
                    icon: Icons.auto_awesome_rounded,
                    color: Colors.amber,
                    onTap: _activateFree,
                  ),
                  const SizedBox(height: 16),
                  _buildActivationOption(
                    title: 'تفعيل بواسطة كود',
                    subtitle: 'افتح كامل المادة بشكل غير محدود',
                    icon: Icons.vpn_key_rounded,
                    color: AppColors.primaryBlue,
                    onTap: _showCodeDialog,
                  ),
                  const SizedBox(height: 40),
                  // Help Text
                  Text(
                    'تواجه مشكلة في التفعيل؟ تواصل مع الدعم الفني',
                    style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.white.withValues(alpha: 0.8),
              child: const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
            ),
        ],
      ),
    );
  }

  Widget _buildPriceSection() {
    final double discount = widget.discount ?? 0;
    final double finalPrice = widget.basePrice! * (1 - discount / 100);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'تكلفة تفعيل المادة',
                style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (discount > 0) ...[
                    Text(
                      '${widget.basePrice!.toStringAsFixed(0)} ل.س',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: Colors.grey,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '%${discount.toStringAsFixed(0)}-',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    '${finalPrice.toStringAsFixed(0)} ل.س',
                    style: GoogleFonts.cairo(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivationOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.1), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color.withValues(alpha: 0.3), size: 18),
          ],
        ),
      ),
    );
  }
}
