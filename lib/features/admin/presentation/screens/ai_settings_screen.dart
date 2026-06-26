import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/domain/services/ai_grading_service.dart';

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

  String _selectedOpenRouterModel = 'nvidia/nemotron-3-ultra-550b-a55b:free';
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;

  final AIGradingService _aiService = AIGradingService();

  static const List<Map<String, String>> _openRouterModels = [
    {'id': 'nvidia/nemotron-3-ultra-550b-a55b:free', 'name': 'Nemotron 3 Ultra 550B', 'tag': 'مجاني'},
    {'id': 'openai/gpt-oss-120b:free', 'name': 'GPT OSS 120B', 'tag': 'مجاني'},
    {'id': 'google/gemma-4-31b-it:free', 'name': 'Gemma 4 31B IT', 'tag': 'مجاني'},
    {'id': 'nvidia/nemotron-nano-12b-v2-vl:free', 'name': 'Nemotron Nano 12B V2', 'tag': 'مجاني'},
    {'id': 'qwen/qwen3-coder:free', 'name': 'Qwen 3 Coder', 'tag': 'مجاني'},
    {'id': 'poolside/laguna-m.1:free', 'name': 'Laguna M.1', 'tag': 'مجاني'},
    {'id': 'google/gemini-flash-1.5', 'name': 'Gemini Flash 1.5', 'tag': 'مدفوع'},
    {'id': 'google/gemini-2.0-flash-001', 'name': 'Gemini 2.0 Flash', 'tag': 'مدفوع'},
    {'id': 'anthropic/claude-3-haiku', 'name': 'Claude 3 Haiku', 'tag': 'مدفوع'},
    {'id': 'anthropic/claude-3-sonnet', 'name': 'Claude 3 Sonnet', 'tag': 'مدفوع'},
    {'id': 'openai/gpt-4o-mini', 'name': 'GPT-4o Mini', 'tag': 'مدفوع'},
    {'id': 'openai/gpt-4o', 'name': 'GPT-4o', 'tag': 'مدفوع'},
    {'id': 'meta-llama/llama-3.1-70b-instruct', 'name': 'Llama 3.1 70B', 'tag': 'مدفوع'},
  ];

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
        _selectedOpenRouterModel = data['openRouterModel'] ?? 'nvidia/nemotron-3-ultra-550b-a55b:free';
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
        'openRouterModel': _selectedOpenRouterModel,
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

  Future<void> _testOpenRouter() async {
    if (_openRouterController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل OpenRouter API Key أولاً')),
      );
      return;
    }

    setState(() => _testing = true);
    try {
      final result = await _aiService.testProvider(
        provider: AIProvider.openRouter,
        model: _selectedOpenRouterModel,
      );
      if (mounted) {
        final isError = result != null && result.startsWith('خطأ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isError ? result : 'الاتصال ناجح! الرد: $result'),
            backgroundColor: isError ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الاختبار: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
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
                    const SizedBox(height: 12),
                    _buildOpenRouterModelDropdown(),
                    const SizedBox(height: 8),
                    _buildTestButton(),
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

  Widget _buildOpenRouterModelDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('موديل OpenRouter', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.withValues(alpha: 0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedOpenRouterModel,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              iconEnabledColor: textColor,
              style: GoogleFonts.inter(fontSize: 13, color: textColor),
              items: _openRouterModels.map((model) {
                final isFree = model['tag'] == 'مجاني';
                return DropdownMenuItem<String>(
                  value: model['id'],
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          model['name']!,
                          style: GoogleFonts.inter(fontSize: 13, color: textColor),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isFree ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          model['tag']!,
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isFree ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedOpenRouterModel = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTestButton() {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: _testing ? null : _testOpenRouter,
        icon: _testing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.play_arrow_rounded, size: 20),
        label: Text(
          _testing ? 'جاري الاختبار...' : 'اختبار الموديل',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          side: const BorderSide(color: AppColors.primaryBlue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
