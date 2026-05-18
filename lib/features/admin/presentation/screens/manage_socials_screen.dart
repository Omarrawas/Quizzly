import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';

class ManageSocialsScreen extends StatefulWidget {
  const ManageSocialsScreen({super.key});

  @override
  State<ManageSocialsScreen> createState() => _ManageSocialsScreenState();
}

class _ManageSocialsScreenState extends State<ManageSocialsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _telegramController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _youtubeController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _supportBotController = TextEditingController();

  bool _telegramEnabled = true;
  bool _whatsappEnabled = true;
  bool _youtubeEnabled = true;
  bool _facebookEnabled = true;
  bool _instagramEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSocials();
  }

  @override
  void dispose() {
    _telegramController.dispose();
    _whatsappController.dispose();
    _youtubeController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _supportBotController.dispose();
    super.dispose();
  }

  Future<void> _loadSocials() async {
    try {
      final doc = await _db.collection('settings').doc('socials').get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _telegramController.text = data['telegramUrl'] ?? 'https://t.me/';
          _whatsappController.text = data['whatsappUrl'] ?? 'https://wa.me/';
          _youtubeController.text = data['youtubeUrl'] ?? 'https://youtube.com/';
          _facebookController.text = data['facebookUrl'] ?? 'https://facebook.com/';
          _instagramController.text = data['instagramUrl'] ?? 'https://instagram.com/';
          _supportBotController.text = data['supportBotUrl'] ?? 'https://t.me/QuizzlySupportBot';

          _telegramEnabled = data['telegramEnabled'] ?? true;
          _whatsappEnabled = data['whatsappEnabled'] ?? true;
          _youtubeEnabled = data['youtubeEnabled'] ?? true;
          _facebookEnabled = data['facebookEnabled'] ?? true;
          _instagramEnabled = data['instagramEnabled'] ?? true;
        });
      } else {
        // Set default placeholders
        _telegramController.text = 'https://t.me/QuizzlyNews';
        _whatsappController.text = 'https://wa.me/963955555555';
        _youtubeController.text = 'https://youtube.com/';
        _facebookController.text = 'https://facebook.com/';
        _instagramController.text = 'https://instagram.com/';
        _supportBotController.text = 'https://t.me/QuizzlySupportBot';
      }
    } catch (e) {
      debugPrint('Error loading socials: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSocials() async {
    setState(() => _isSaving = true);
    try {
      await _db.collection('settings').doc('socials').set({
        'telegramUrl': _telegramController.text.trim(),
        'whatsappUrl': _whatsappController.text.trim(),
        'youtubeUrl': _youtubeController.text.trim(),
        'facebookUrl': _facebookController.text.trim(),
        'instagramUrl': _instagramController.text.trim(),
        'supportBotUrl': _supportBotController.text.trim(),

        'telegramEnabled': _telegramEnabled,
        'whatsappEnabled': _whatsappEnabled,
        'youtubeEnabled': _youtubeEnabled,
        'facebookEnabled': _facebookEnabled,
        'instagramEnabled': _instagramEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ الإعدادات بنجاح', style: GoogleFonts.cairo()),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الحفظ: $e', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'ضبط وسائل التواصل',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Section 1: Support Bot
                  _buildSectionHeader('بوت الدعم الفني الذكي', Icons.headset_mic_rounded, isDark),
                  const SizedBox(height: 12),
                  _buildCard(
                    isDark: isDark,
                    child: _buildTextField(
                      controller: _supportBotController,
                      label: 'رابط بوت التلغرام (الدعم الفني المباشر)',
                      hint: 'مثال: https://t.me/QuizzlySupportBot',
                      icon: Icons.smart_toy_rounded,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Section 2: Social Links
                  _buildSectionHeader('وسائل التواصل الاجتماعي (الشريط الجانبي)', Icons.share_rounded, isDark),
                  const SizedBox(height: 12),
                  _buildCard(
                    isDark: isDark,
                    child: Column(
                      children: [
                        _buildSocialConfigRow(
                          controller: _telegramController,
                          label: 'قناة التلغرام (المستجدات)',
                          hint: 'https://t.me/QuizzlyChannel',
                          icon: Icons.telegram_rounded,
                          color: const Color(0xFF0088CC),
                          enabled: _telegramEnabled,
                          onChanged: (v) => setState(() => _telegramEnabled = v),
                          isDark: isDark,
                        ),
                        const Divider(height: 32),
                        _buildSocialConfigRow(
                          controller: _whatsappController,
                          label: 'رابط الواتساب',
                          hint: 'https://wa.me/...',
                          icon: Icons.chat_rounded,
                          color: const Color(0xFF25D366),
                          enabled: _whatsappEnabled,
                          onChanged: (v) => setState(() => _whatsappEnabled = v),
                          isDark: isDark,
                        ),
                        const Divider(height: 32),
                        _buildSocialConfigRow(
                          controller: _youtubeController,
                          label: 'قناة اليوتيوب',
                          hint: 'https://youtube.com/...',
                          icon: Icons.play_circle_fill_rounded,
                          color: const Color(0xFFFF0000),
                          enabled: _youtubeEnabled,
                          onChanged: (v) => setState(() => _youtubeEnabled = v),
                          isDark: isDark,
                        ),
                        const Divider(height: 32),
                        _buildSocialConfigRow(
                          controller: _facebookController,
                          label: 'صفحة الفيسبوك',
                          hint: 'https://facebook.com/...',
                          icon: Icons.facebook_rounded,
                          color: const Color(0xFF1877F2),
                          enabled: _facebookEnabled,
                          onChanged: (v) => setState(() => _facebookEnabled = v),
                          isDark: isDark,
                        ),
                        const Divider(height: 32),
                        _buildSocialConfigRow(
                          controller: _instagramController,
                          label: 'رابط الانستغرام',
                          hint: 'https://instagram.com/...',
                          icon: Icons.camera_alt_rounded,
                          color: const Color(0xFFE1306C),
                          enabled: _instagramEnabled,
                          onChanged: (v) => setState(() => _instagramEnabled = v),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSocials,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'حفظ التغييرات',
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryBlue, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : AppColors.borderLight,
        ),
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white24 : Colors.grey,
            ),
            prefixIcon: Icon(icon, color: AppColors.primaryBlue, size: 20),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialConfigRow({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    required bool enabled,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Switch(
              value: enabled,
              onChanged: onChanged,
              activeThumbColor: AppColors.primaryBlue,
            ),
          ],
        ),
        if (enabled) ...[
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white24 : Colors.grey,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ],
    );
  }
}
