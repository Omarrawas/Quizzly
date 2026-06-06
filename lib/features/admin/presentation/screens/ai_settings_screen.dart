import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';

class AISettingsScreen extends StatefulWidget {
  const AISettingsScreen({super.key});

  @override
  State<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends State<AISettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  final _geminiController = TextEditingController();
  final _groqController = TextEditingController();
  final _openRouterController = TextEditingController();
  final _proxyController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await _firestore.collection('settings').doc('ai_config').get();
      if (doc.exists) {
        final data = doc.data()!;
        _geminiController.text = data['geminiKey'] ?? '';
        _groqController.text = data['groqKey'] ?? '';
        _openRouterController.text = data['openRouterKey'] ?? '';
        _proxyController.text = data['cloudflareProxyUrl'] ?? 'https://quizzly-proxy.omar-rawas17.workers.dev';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الإعدادات: $e', style: GoogleFonts.cairo())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await _firestore.collection('settings').doc('ai_config').set({
        'geminiKey': _geminiController.text.trim(),
        'groqKey': _groqController.text.trim(),
        'openRouterKey': _openRouterController.text.trim(),
        'cloudflareProxyUrl': _proxyController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الإعدادات بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إعدادات الذكاء الاصطناعي', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        actions: [
          if (!_loading)
            IconButton(
              onPressed: _saving ? null : _saveSettings,
              icon: _saving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.save_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _geminiController,
                      label: 'Gemini API Key',
                      hint: 'AIzaSy...',
                      icon: Icons.auto_awesome_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _groqController,
                      label: 'Groq API Key',
                      hint: 'gsk_...',
                      icon: Icons.bolt_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _openRouterController,
                      label: 'OpenRouter API Key',
                      hint: 'sk-or-...',
                      icon: Icons.hub_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _proxyController,
                      label: 'Cloudflare Proxy URL',
                      hint: 'https://...',
                      icon: Icons.lan_rounded,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveSettings,
                        icon: const Icon(Icons.save_rounded),
                        label: Text('حفظ جميع الإعدادات', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.blue),
              const SizedBox(width: 8),
              Text('إدارة المفاتيح', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'هذه المفاتيح تُستخدم لتصحيح الإجابات المقالية للطلاب. يتم استخدام التبديل التلقائي بين المزودين في حال فشل أحدهما.',
            style: GoogleFonts.cairo(fontSize: 13, color: Colors.blue.shade900),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: Colors.grey.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: GoogleFonts.inter(fontSize: 14),
        ),
      ],
    );
  }
}
