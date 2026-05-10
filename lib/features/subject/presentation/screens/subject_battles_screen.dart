import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/quiz/domain/services/battle_service.dart';
import 'package:quizzly/features/quiz/presentation/screens/battle_session_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('معارك المواد: ${widget.subjectName}', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: Colors.grey,
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
          _buildActionTab(user.uid, user.displayName ?? 'طالب'),
          _buildHistoryTab(user.uid),
        ],
      ),
    );
  }

  Widget _buildActionTab(String userId, String userName) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCreateCard(userId, userName),
          const SizedBox(height: 24),
          _buildJoinCard(userId, userName),
        ],
      ),
    );
  }

  Widget _buildCreateCard(String userId, String userName) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 48),
          const SizedBox(height: 16),
          Text('تحدي جديد', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'قم بإنشاء تحدي جديد وشارك الكود مع صديقك للمنافسة في أسئلة عشوائية من هذه المادة.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _createChallenge(userId, userName),
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

  Widget _buildJoinCard(String userId, String userName) {
    final codeController = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.group_add_rounded, color: Colors.green, size: 48),
          const SizedBox(height: 16),
          Text('انضمام لتحدي', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'أدخل كود التحدي الذي شاركه معك صديقك للبدء.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: codeController,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 2),
            decoration: InputDecoration(
              hintText: 'أدخل الكود هنا',
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _joinChallenge(userId, userName, codeController.text),
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
        if (battles.isEmpty) {
          return Center(
            child: Text('لا توجد تحديات سابقة.', style: GoogleFonts.cairo(color: Colors.grey)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: battles.length,
          itemBuilder: (context, index) {
            final b = battles[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  backgroundColor: b.status == BattleStatus.finished ? Colors.grey[200] : Colors.amber[100],
                  child: Icon(
                    b.status == BattleStatus.finished ? Icons.flag_rounded : Icons.pending_actions_rounded,
                    color: b.status == BattleStatus.finished ? Colors.grey : Colors.amber,
                  ),
                ),
                title: Text('تحدي ضد ${b.opponentName ?? 'قيد الانتظار'}', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                subtitle: Text('الحالة: ${b.status.name}', style: GoogleFonts.cairo(fontSize: 12)),
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

  Future<void> _createChallenge(String userId, String userName) async {
    showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final battleId = await _battleService.createChallenge(
        challengerId: userId,
        challengerName: userName,
        subjectId: widget.subjectId,
        subjectName: widget.subjectName,
      );
      
      final battle = await _battleService.getBattle(battleId);
      
      if (!mounted) return;
      Navigator.pop(context); // close loader
      
      if (battle != null) {
        _showBattleCodeDialog(battle);
      }
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تم إنشاء التحدي!', textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('شارك هذا الكود مع صديقك ليبدأ التحدي:', textAlign: TextAlign.center, style: GoogleFonts.cairo()),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
              child: SelectableText(
                battle.id,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1),
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
            child: Text('نسخ الكود', style: GoogleFonts.cairo(color: AppColors.primaryBlue)),
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
}
