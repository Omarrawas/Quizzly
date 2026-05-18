import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/quiz/domain/services/battle_service.dart';
import 'package:quizzly/features/quiz/presentation/screens/battle_session_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectBattlesScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;

  const SubjectBattlesScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<SubjectBattlesScreen> createState() => _SubjectBattlesScreenState();
}

class _SubjectBattlesScreenState extends State<SubjectBattlesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BattleService _battleService = BattleService();
  late TextEditingController _joinCodeController;
  List<Map<String, dynamic>> _topics = [];
  bool _isLoadingTopics = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _joinCodeController = TextEditingController();
    _loadTopics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('topics')
          .where('subjectId', isEqualTo: widget.subjectId)
          .get();
      if (mounted) {
        setState(() {
          _topics = snap.docs.map((d) {
            final t = d.data();
            t['id'] = d.id;
            t['name'] = t['name'] ?? t['title'] ?? '';
            return t;
          }).toList();
          _isLoadingTopics = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTopics = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = context.watch<AuthService>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('معارك المواد: ${widget.subjectName}',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18,
                color: isDark ? Colors.white : AppColors.textPrimary)),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.grey,
          indicatorColor: AppColors.primaryBlue,
          labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'إنشاء / انضمام'),
            Tab(text: 'سجل التحديات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          KeepAliveWrapper(child: _buildActionTab(user.uid, user.displayName ?? 'طالب', isDark)),
          KeepAliveWrapper(child: _buildHistoryTab(user.uid)),
        ],
      ),
    );
  }

  Widget _buildActionTab(String userId, String userName, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildActiveBattlesSection(userId, isDark),
          _buildCreateCard(userId, userName, isDark),
          const SizedBox(height: 24),
          _buildJoinCard(userId, userName, isDark),
        ],
      ),
    );
  }

  Widget _buildActiveBattlesSection(String userId, bool isDark) {
    return StreamBuilder<List<BattleChallenge>>(
      stream: _battleService.streamMyBattles(userId).map((list) => list.where((b) => b.status != BattleStatus.finished).toList()),
      builder: (context, snapshot) {
        final active = snapshot.data ?? [];
        if (active.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('تحديات نشطة', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : null)),
                ],
              ),
            ),
            ...active.map((b) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14532D).withValues(alpha: 0.3) : Colors.green[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF166534) : Colors.green[200]!),
              ),
              child: ListTile(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BattleSessionScreen(battle: b)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.flash_on_rounded, color: Colors.green, size: 24),
                ),
                title: Text('تحدي ضد ${b.opponentName ?? 'قيد الانتظار'}', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : null)),
                subtitle: Text('${b.status == BattleStatus.active ? "جارٍ" : "بانتظار المنافس"} • ${b.questionIds.length} أسئلة', style: GoogleFonts.cairo(fontSize: 12, color: isDark ? Colors.white60 : null)),
                trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Colors.green),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            )),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildCreateCard(String userId, String userName, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 48),
          const SizedBox(height: 16),
          Text('تحدي جديد', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : null)),
          const SizedBox(height: 8),
          Text(
            'قم بإنشاء تحدي جديد وشارك الكود مع صديقك للمنافسة في أسئلة عشوائية من هذه المادة.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showTopicSelectionBottomSheet(userId, userName),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('إنشاء تحدي الآن', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinCard(String userId, String userName, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.group_add_rounded, color: Colors.green, size: 48),
          const SizedBox(height: 16),
          Text('انضمام لتحدي', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : null)),
          const SizedBox(height: 8),
          Text(
            'أدخل كود التحدي الذي شاركه معك صديقك للبدء.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _joinCodeController,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 2, color: isDark ? Colors.white : null),
            decoration: InputDecoration(
              hintText: 'أدخل الكود هنا',
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _joinChallenge(userId, userName, _joinCodeController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('دخول المعركة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(String userId) {
    return StreamBuilder<List<BattleChallenge>>(
      stream: _battleService.streamMyBattles(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final battles = snapshot.data ?? [];
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        if (battles.isEmpty) {
          return Center(
            child: Text('لا توجد تحديات سابقة.', style: GoogleFonts.cairo(color: isDark ? Colors.white38 : Colors.grey)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: battles.length,
          itemBuilder: (context, index) {
            final b = battles[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: isDark ? const BorderSide(color: Colors.white10) : BorderSide.none,
              ),
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BattleSessionScreen(battle: b),
                    ),
                  );
                },
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: b.status == BattleStatus.finished 
                    ? (isDark ? Colors.white10 : Colors.grey[200]) 
                    : (isDark ? Colors.amber.withValues(alpha: 0.2) : Colors.amber[100]),
                  child: Icon(
                    b.status == BattleStatus.finished ? Icons.flag_rounded : Icons.pending_actions_rounded,
                    color: b.status == BattleStatus.finished ? Colors.grey : Colors.amber,
                  ),
                ),
                title: Text(
                  'تحدي ضد ${b.opponentName ?? 'قيد الانتظار'}', 
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: isDark ? Colors.white : null)
                ),
                subtitle: Text(
                  'الحالة: ${b.status.name}', 
                  style: GoogleFonts.cairo(fontSize: 12, color: isDark ? Colors.white60 : null)
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded, color: AppColors.primaryBlue),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: b.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ كود التحدي!')),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _createChallenge(String userId, String userName, [List<String>? topicIds, int questionsCount = 10]) async {
    showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final battle = await _battleService.createChallenge(
        challengerId: userId,
        challengerName: userName,
        subjectId: widget.subjectId,
        subjectName: widget.subjectName,
        topicIds: topicIds,
        questionsCount: questionsCount,
      );
      
      if (!mounted) return;
      Navigator.pop(context); // close loader
      
      _showBattleCodeDialog(battle);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء الإنشاء')));
    }
  }

  Future<void> _joinChallenge(String userId, String userName, String code) async {
    if (code.trim().isEmpty) return;
    showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final battle = await _battleService.joinChallenge(
        battleId: code.trim(),
        opponentId: userId,
        opponentName: userName,
      );
      if (!mounted) return;
      Navigator.pop(context); // close loader

      if (battle == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كود غير صحيح أو التحدي غير متاح')));
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BattleSessionScreen(battle: battle),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الانضمام بنجاح! جاري تحضير المعركة...')));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء الانضمام')));
    }
  }

  void _showBattleCodeDialog(BattleChallenge battle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'تم إنشاء التحدي!', 
          textAlign: TextAlign.center, 
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: isDark ? Colors.white : null)
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'شارك هذا الكود مع صديقك ليبدأ التحدي:', 
              textAlign: TextAlign.center, 
              style: GoogleFonts.cairo(color: isDark ? Colors.white70 : null)
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.grey[100], 
                borderRadius: BorderRadius.circular(12)
              ),
              child: SelectableText(
                battle.id,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold, 
                  fontSize: 18, 
                  letterSpacing: 1,
                  color: isDark ? Colors.white : null,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: battle.id));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ!')));
            },
            child: Text('نسخ الكود', style: GoogleFonts.cairo(color: isDark ? const Color(0xFF60A5FA) : AppColors.primaryBlue)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BattleSessionScreen(battle: battle)),
              );
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
            label: Text('ابدأ المعركة الآن', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showTopicSelectionBottomSheet(String userId, String userName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Select all topics by default
    List<String> selectedIds = _topics.map((t) => t['id'] as String).toList();
    int selectedQuestionsCount = 10;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final hasTopics = _topics.isNotEmpty;
            final isAllSelected = selectedIds.length == _topics.length;

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.85,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'إعدادات تحدي المعركة',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Questions Count Selector Section
                      Text(
                        'عدد الأسئلة المطلوبة:',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [5, 10, 15, 20].map((qCount) {
                          final isSelected = selectedQuestionsCount == qCount;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text(
                                  '$qCount أسئلة' == '20 أسئلة' ? '20 سؤالاً' : '$qCount أسئلة' == '15 أسئلة' ? '15 سؤالاً' : '$qCount أسئلة',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected 
                                        ? Colors.white 
                                        : (isDark ? Colors.white70 : AppColors.textPrimary),
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (val) {
                                  if (val) {
                                    setModalState(() {
                                      selectedQuestionsCount = qCount;
                                    });
                                  }
                                },
                                selectedColor: AppColors.primaryBlue,
                                backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                                checkmarkColor: Colors.white,
                                showCheckmark: false,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      if (hasTopics)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'اختر مواضيع التحدي (${_topics.length})',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : AppColors.textSecondary,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  if (isAllSelected) {
                                    selectedIds.clear();
                                  } else {
                                    selectedIds = _topics.map((t) => t['id'] as String).toList();
                                  }
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryBlue,
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                isAllSelected ? 'إلغاء تحديد الكل' : 'تحديد الكل',
                                style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _isLoadingTopics
                            ? const Center(child: CircularProgressIndicator())
                            : !hasTopics
                                ? Center(
                                    child: Text(
                                      'لا توجد مواضيع متاحة لهذه المادة.',
                                      style: GoogleFonts.cairo(color: isDark ? Colors.white38 : Colors.grey),
                                    ),
                                  )
                                : ListView.builder(
                                    controller: scrollController,
                                    itemCount: _topics.length,
                                    itemBuilder: (context, index) {
                                      final t = _topics[index];
                                      final id = t['id'] as String;
                                      final name = t['name'] as String;
                                      final isSelected = selectedIds.contains(id);

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.3) : Colors.grey[50],
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected 
                                                ? AppColors.primaryBlue.withValues(alpha: 0.5) 
                                                : Colors.transparent,
                                          ),
                                        ),
                                        child: CheckboxListTile(
                                          value: isSelected,
                                          onChanged: (val) {
                                            setModalState(() {
                                              if (val == true) {
                                                selectedIds.add(id);
                                              } else {
                                                selectedIds.remove(id);
                                              }
                                            });
                                          },
                                          title: Text(
                                            name,
                                            style: GoogleFonts.cairo(
                                              fontSize: 14,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              color: isDark ? Colors.white : AppColors.textPrimary,
                                            ),
                                          ),
                                          activeColor: AppColors.primaryBlue,
                                          checkColor: Colors.white,
                                          controlAffinity: ListTileControlAffinity.leading,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: selectedIds.isEmpty
                            ? null
                            : () {
                                Navigator.pop(context); // Close sheet
                                _createChallenge(userId, userName, selectedIds, selectedQuestionsCount);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                          disabledForegroundColor: isDark ? Colors.white24 : Colors.grey[400],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'تأكيد وإنشاء المعركة',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
