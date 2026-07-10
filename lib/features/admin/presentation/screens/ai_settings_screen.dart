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
  final _bynaraController = TextEditingController();
  final _groqController = TextEditingController();
  final _openRouterController = TextEditingController();

  String _selectedOpenRouterModel = 'nvidia/nemotron-3-ultra-550b-a55b:free';
  String _selectedGeminiModel = 'gemini-3.5-flash';
  String _selectedBynaraModel = 'auto/bynara';
  bool _loading = true;
  bool _saving = false;
  AIProvider? _testingProvider;

  final AIGradingService _aiService = AIGradingService();

  static const List<Map<String, String>> _bynaraModels = [
    {'id': 'auto/bynara', 'name': 'Bynara Auto (تحديد تلقائي)', 'tag': 'موصى به'},
    {'id': 'mimo-v2.5', 'name': 'MiMo v2.5', 'tag': 'مجاني'},
    {'id': 'mimo-v2.5-pro', 'name': 'MiMo v2.5 Pro', 'tag': 'مجاني'},
    {'id': 'mimo-v2.5-pro-ultraspeed', 'name': 'MiMo v2.5 Pro Ultraspeed', 'tag': 'مجاني'},
    {'id': 'mimo-v2.5-hermes', 'name': 'MiMo v2.5 Hermes', 'tag': 'مجاني'},
    {'id': 'mimo-v2.5-pro-hermes', 'name': 'MiMo v2.5 Pro Hermes', 'tag': 'مجاني'},
    {'id': 'deepseek-v4-flash', 'name': 'DeepSeek v4 Flash', 'tag': 'مجاني'},
    {'id': 'deepseek-v4-pro', 'name': 'DeepSeek v4 Pro', 'tag': 'مجاني'},
    {'id': 'kimi-k2.6', 'name': 'Kimi k2.6', 'tag': 'مجاني'},
    {'id': 'kimi-k2.7-code', 'name': 'Kimi k2.7 Code', 'tag': 'مجاني'},
    {'id': 'mistral-large', 'name': 'Mistral Large', 'tag': 'مجاني'},
    {'id': 'mistral-medium-3-5', 'name': 'Mistral Medium 3.5', 'tag': 'مجاني'},
    {'id': 'tencent-hy3', 'name': 'Tencent Hunyuan 3', 'tag': 'مجاني'},
    {'id': 'claude-opus-4.7-plan', 'name': 'Claude Opus 4.7 Plan', 'tag': 'مجاني'},
    {'id': 'claude-opus-4.8-plan', 'name': 'Claude Opus 4.8 Plan', 'tag': 'مجاني'},
    {'id': 'claude-sonnet-5-plan', 'name': 'Claude Sonnet 5 Plan', 'tag': 'مجاني'},
    {'id': 'gpt-5.4', 'name': 'GPT 5.4', 'tag': 'مجاني'},
    {'id': 'gpt-5.5', 'name': 'GPT 5.5', 'tag': 'مجاني'},
  ];

  static const List<Map<String, String>> _openRouterModels = [
    {'id': 'nvidia/nemotron-3-ultra-550b-a55b:free', 'name': 'Nemotron 3 Ultra 550B', 'tag': 'مجاني'},
    {'id': 'openai/gpt-oss-120b:free', 'name': 'GPT OSS 120B', 'tag': 'مجاني'},
    {'id': 'google/gemma-4-31b-it:free', 'name': 'Gemma 4 31B IT', 'tag': 'مجاني'},
    {'id': 'nvidia/nemotron-nano-12b-v2-vl:free', 'name': 'Nemotron Nano 12B V2', 'tag': 'مجاني'},
    {'id': 'qwen/qwen3-coder:free', 'name': 'Qwen 3 Coder', 'tag': 'مجاني'},
    {'id': 'poolside/laguna-m.1:free', 'name': 'Laguna M.1', 'tag': 'مجاني'},
    {'id': 'google/gemini-3.5-flash', 'name': 'Gemini 3.5 Flash', 'tag': 'مدفوع'},
    {'id': 'google/gemini-3.1-flash-lite', 'name': 'Gemini-3.1 Flash Lite', 'tag': 'مدفوع'},
    {'id': 'google/gemini-flash-1.5', 'name': 'Gemini Flash 1.5', 'tag': 'مدفوع'},
    {'id': 'google/gemini-2.0-flash-001', 'name': 'Gemini 2.0 Flash', 'tag': 'مدفوع'},
    {'id': 'anthropic/claude-3-haiku', 'name': 'Claude 3 Haiku', 'tag': 'مدفوع'},
    {'id': 'anthropic/claude-3-sonnet', 'name': 'Claude 3 Sonnet', 'tag': 'مدفوع'},
    {'id': 'openai/gpt-4o-mini', 'name': 'GPT-4o Mini', 'tag': 'مدفوع'},
    {'id': 'openai/gpt-4o', 'name': 'GPT-4o', 'tag': 'مدفوع'},
    {'id': 'meta-llama/llama-3.1-70b-instruct', 'name': 'Llama 3.1 70B', 'tag': 'مدفوع'},
  ];

  static const List<Map<String, String>> _geminiModels = [
    {'id': 'gemini-3.5-flash', 'name': 'Gemini 3.5 Flash', 'tag': 'جديد/افتراضي'},
    {'id': 'gemini-3.1-pro-preview', 'name': 'Gemini 3.1 Pro Preview (الأعلى دقة)', 'tag': 'جديد/دقيق'},
    {'id': 'gemini-3.1-flash-lite', 'name': 'Gemini 3.1 Flash Lite', 'tag': 'جديد/اقتصادي'},
    {'id': 'gemini-3-flash-preview', 'name': 'Gemini 3 Flash Preview', 'tag': 'سريع'},
    {'id': 'gemini-pro-latest', 'name': 'Gemini Pro Latest (Points to 3.1 Pro)', 'tag': 'دقيق جداً'},
    {'id': 'gemini-flash-latest', 'name': 'Gemini Flash Latest (Points to 3.5 Flash)', 'tag': 'افتراضي'},
    {'id': 'gemini-flash-lite-latest', 'name': 'Gemini Flash-Lite Latest (Points to 3.1 Lite)', 'tag': 'اقتصادي'},
    {'id': 'gemini-2.5-pro', 'name': 'Gemini 2.5 Pro', 'tag': 'تفكير/دقيق'},
    {'id': 'gemini-2.5-flash', 'name': 'Gemini 2.5 Flash', 'tag': 'متوازن'},
    {'id': 'gemini-2.5-flash-lite', 'name': 'Gemini 2.5 Flash-Lite', 'tag': 'اقتصادي'},
    {'id': 'gemini-robotics-er-1.6-preview', 'name': 'Gemini Robotics-ER 1.6 Preview', 'tag': 'تفكير تجريبي'},
    {'id': 'gemini-3.1-flash-lite-image', 'name': 'Gemini 3.1 Flash Lite Image', 'tag': 'توليد صور'},
    {'id': 'gemini-3.1-flash-image', 'name': 'Gemini 3.1 Flash Image', 'tag': 'توليد صور'},
    {'id': 'gemini-3-pro-image', 'name': 'Gemini 3 Pro Image', 'tag': 'توليد صور'},
    {'id': 'gemini-2.5-flash-image', 'name': 'Gemini 2.5 Flash Image', 'tag': 'توليد صور'},
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
        _bynaraController.text = data['bynaraKey'] ?? '';
        _groqController.text = data['groqKey'] ?? '';
        _openRouterController.text = data['openRouterKey'] ?? '';
        _selectedOpenRouterModel = data['openRouterModel'] ?? 'nvidia/nemotron-3-ultra-550b-a55b:free';
        _selectedGeminiModel = data['geminiModel'] ?? 'gemini-3.5-flash';
        _selectedBynaraModel = data['bynaraModel'] ?? 'auto/bynara';
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
        'geminiModel': _selectedGeminiModel,
        'bynaraKey': _bynaraController.text.trim(),
        'bynaraModel': _selectedBynaraModel,
        'groqKey': _groqController.text.trim(),
        'openRouterKey': _openRouterController.text.trim(),
        'openRouterModel': _selectedOpenRouterModel,
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

  Future<void> _testProvider(AIProvider provider) async {
    if (_testingProvider != null) return;

    String apiKey = '';
    String? model;
    String name = '';

    if (provider == AIProvider.gemini) {
      apiKey = _geminiController.text.trim();
      name = 'Gemini';
      model = _selectedGeminiModel;
    } else if (provider == AIProvider.bynara) {
      apiKey = _bynaraController.text.trim();
      name = 'Bynara';
      model = _selectedBynaraModel;
    } else if (provider == AIProvider.groq) {
      apiKey = _groqController.text.trim();
      name = 'Groq';
    } else if (provider == AIProvider.openRouter) {
      apiKey = _openRouterController.text.trim();
      name = 'OpenRouter';
      model = _selectedOpenRouterModel;
    }

    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الرجاء إدخال مفتاح $name أولاً', style: GoogleFonts.tajawal()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _testingProvider = provider);
    try {
      final result = await _aiService.testProvider(
        provider: provider,
        model: model,
        apiKey: apiKey,
      );
      if (mounted) {
        final isError = result != null && (result.startsWith('خطأ') || result.contains('Error') || result.contains('Exception'));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isError ? 'فشل اختبار $name: $result' : 'اتصال $name ناجح! الرد: $result',
              style: GoogleFonts.tajawal(),
            ),
            backgroundColor: isError ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في اختبار $name: $e', style: GoogleFonts.tajawal()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _testingProvider = null);
      }
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
                      provider: AIProvider.gemini,
                    ),
                    const SizedBox(height: 12),
                    _buildGeminiModelDropdown(),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _bynaraController,
                      label: 'Bynara API Key',
                      hint: 'nara_...',
                      icon: Icons.rocket_launch_rounded,
                      provider: AIProvider.bynara,
                    ),
                    const SizedBox(height: 12),
                    _buildBynaraModelDropdown(),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _groqController,
                      label: 'Groq API Key',
                      hint: 'gsk_...',
                      icon: Icons.bolt_rounded,
                      provider: AIProvider.groq,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _openRouterController,
                      label: 'OpenRouter API Key',
                      hint: 'sk-or-...',
                      icon: Icons.hub_rounded,
                      provider: AIProvider.openRouter,
                    ),
                    const SizedBox(height: 12),
                    _buildOpenRouterModelDropdown(),
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
    AIProvider? provider,
  }) {
    final isTestingThis = provider != null && _testingProvider == provider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 14)),
            if (provider != null)
              TextButton.icon(
                onPressed: _testingProvider != null ? null : () => _testProvider(provider),
                icon: isTestingThis
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6E56FF)),
                      )
                    : const Icon(Icons.play_circle_outline_rounded, size: 16, color: Color(0xFF6E56FF)),
                label: Text(
                  isTestingThis ? 'جاري الاختبار...' : 'اختبار الموديل',
                  style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: const Color(0xFF6E56FF),
                  ),
                ),
              ),
          ],
        ),
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
            color: isDark ? const Color(0xFF131A26) : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.withValues(alpha: 0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedOpenRouterModel,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF131A26) : Colors.white,
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

  Widget _buildGeminiModelDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('موديل Google Gemini', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131A26) : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.withValues(alpha: 0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedGeminiModel,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF131A26) : Colors.white,
              iconEnabledColor: textColor,
              style: GoogleFonts.inter(fontSize: 13, color: textColor),
              items: _geminiModels.map((model) {
                return DropdownMenuItem<String>(
                  value: model['id'],
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          model['name']!,
                          style: GoogleFonts.tajawal(fontSize: 13, color: textColor),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          model['tag']!,
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedGeminiModel = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBynaraModelDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('موديل Bynara', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131A26) : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.withValues(alpha: 0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedBynaraModel,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF131A26) : Colors.white,
              iconEnabledColor: textColor,
              style: GoogleFonts.inter(fontSize: 13, color: textColor),
              items: _bynaraModels.map((model) {
                return DropdownMenuItem<String>(
                  value: model['id'],
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          model['name']!,
                          style: GoogleFonts.tajawal(fontSize: 13, color: textColor),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          model['tag']!,
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedBynaraModel = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
