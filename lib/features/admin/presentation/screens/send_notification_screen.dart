import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/notification_service.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _actionUrlController = TextEditingController();
  final _routeController = TextEditingController();
  final _notifService = AdminNotificationService();
  
  String _targetType = 'all'; // 'all' or 'subject'
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _imageUrlController.dispose();
    _actionUrlController.dispose();
    _routeController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    if (_targetType == 'subject' && _selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار مادة أولاً'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      if (_targetType == 'all') {
        await _notifService.sendGeneralNotification(
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          imageUrl: _imageUrlController.text.trim(),
          actionUrl: _actionUrlController.text.trim(),
          route: _routeController.text.trim(),
        );
      } else {
        await _notifService.sendSubjectNotification(
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          subjectId: _selectedSubjectId!,
          subjectName: _selectedSubjectName!,
          imageUrl: _imageUrlController.text.trim(),
          actionUrl: _actionUrlController.text.trim(),
          route: _routeController.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال الإشعار بنجاح ✅'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإرسال: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C14) : Colors.grey[50],
      appBar: AppBar(
        title: Text('إرسال إشعارات', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isSending 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('نوع الإشعار', isDark),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildTargetButton('عام (للجميع)', 'all', Icons.campaign_rounded),
                      const SizedBox(width: 12),
                      _buildTargetButton('لمادة محددة', 'subject', Icons.book_rounded),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  if (_targetType == 'subject') ...[
                    _buildSectionTitle('اختر المادة', isDark),
                    const SizedBox(height: 12),
                    _buildSubjectPicker(isDark),
                    const SizedBox(height: 32),
                  ],

                  _buildSectionTitle('محتوى الإشعار', isDark),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    decoration: _inputDecoration('عنوان الإشعار', Icons.title_rounded, isDark),
                    style: GoogleFonts.cairo(),
                    validator: (v) => v!.isEmpty ? 'يرجى إدخال العنوان' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bodyController,
                    maxLines: 4,
                    decoration: _inputDecoration('نص الإشعار', Icons.text_fields_rounded, isDark),
                    style: GoogleFonts.cairo(),
                    validator: (v) => v!.isEmpty ? 'يرجى إدخال النص' : null,
                  ),
                  const SizedBox(height: 32),
                  
                  _buildSectionTitle('إجراءات إضافية (اختياري)', isDark),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _imageUrlController,
                    decoration: _inputDecoration('رابط صورة (URL)', Icons.image_rounded, isDark),
                    style: GoogleFonts.cairo(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _actionUrlController,
                    decoration: _inputDecoration('رابط خارجي للفتح (URL)', Icons.link_rounded, isDark),
                    style: GoogleFonts.cairo(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _routeController,
                    decoration: _inputDecoration('توجيه داخلي (Route)', Icons.directions_rounded, isDark),
                    style: GoogleFonts.cairo(),
                  ),
                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _send,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text('إرسال الإشعار الآن', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white70 : AppColors.textSecondary,
      ),
    );
  }

  Widget _buildTargetButton(String label, String value, IconData icon) {
    final isSelected = _targetType == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _targetType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected 
              ? AppColors.primaryBlue 
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primaryBlue : (isDark ? Colors.white10 : AppColors.borderLight),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : AppColors.primaryBlue),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectPicker(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('subjects').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
        final subjects = snapshot.data?.docs ?? [];
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: Text('اختر المادة المستهدفة', style: GoogleFonts.cairo(fontSize: 14)),
              value: _selectedSubjectId,
              items: subjects.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(data['name'] ?? '', style: GoogleFonts.cairo()),
                  onTap: () => _selectedSubjectName = data['name'],
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedSubjectId = v),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primaryBlue),
      labelStyle: GoogleFonts.cairo(fontSize: 14),
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: isDark ? Colors.white10 : AppColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: isDark ? Colors.white10 : AppColors.borderLight),
      ),
    );
  }
}
