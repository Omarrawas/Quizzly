import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quizzly/core/theme/app_colors.dart';

class FinancialStatsScreen extends StatefulWidget {
  const FinancialStatsScreen({super.key});

  @override
  State<FinancialStatsScreen> createState() => _FinancialStatsScreenState();
}

class _FinancialStatsScreenState extends State<FinancialStatsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _subjectStats = [];
  int _totalRevenue = 0;
  DateTime? _lastResetDate;

  @override
  void initState() {
    super.initState();
    _fetchFinancialData();
  }

  Future<void> _fetchFinancialData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch all subjects
      final subjectsSnap = await _db.collection('subjects').get();
      final subjects = subjectsSnap.docs;

      // Fetch the last reset date from settings
      DateTime? lastResetDate;
      final settingsDoc = await _db.collection('system_settings').doc('financials').get();
      if (settingsDoc.exists && settingsDoc.data()!.containsKey('last_financial_reset')) {
        lastResetDate = (settingsDoc.data()!['last_financial_reset'] as Timestamp).toDate();
      }

      // 2. Fetch all user_subjects to calculate stats per subject
      final userSubjectsSnap = await _db.collection('user_subjects').get();

      final Map<String, int> revenueMap = {};
      final Map<String, int> totalSubscribersMap = {};
      final Map<String, int> paidSubscriptionsMap = {};

      for (var doc in userSubjectsSnap.docs) {
        final data = doc.data();
        
        // Local filter by reset date
        if (lastResetDate != null && data.containsKey('activatedAt')) {
          final activatedAt = (data['activatedAt'] as Timestamp?)?.toDate();
          if (activatedAt != null && activatedAt.isBefore(lastResetDate)) {
            continue;
          }
        }

        final subjectId = data['subjectId'] as String?;
        final type = data['type'] as String? ?? data['activationType'] as String? ?? 'free';
        final price = (data['price'] as num?)?.toInt() ?? 0;
        final isPaid = type == 'purchase' || price > 0;
        
        if (subjectId != null) {
          totalSubscribersMap[subjectId] = (totalSubscribersMap[subjectId] ?? 0) + 1;
          
          if (isPaid) {
            paidSubscriptionsMap[subjectId] = (paidSubscriptionsMap[subjectId] ?? 0) + 1;
            revenueMap[subjectId] = (revenueMap[subjectId] ?? 0) + price;
          }
        }
      }

      // Calculate TOTAL revenue from actual code redemptions
      int total = 0;
      final redeemLogsSnap = await _db.collection('credit_logs').where('type', isEqualTo: 'redeem').get();
      for (var doc in redeemLogsSnap.docs) {
        final data = doc.data();
        
        // Local filter by reset date
        if (lastResetDate != null && data.containsKey('timestamp')) {
          final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
          if (timestamp != null && timestamp.isBefore(lastResetDate)) {
            continue;
          }
        }

        total += (data['amount'] as num?)?.toInt() ?? 0;
      }

      // Fetch exams/evaluations to get some stats (e.g. number of exams)
      final examsSnap = await _db.collection('exams').get();
      final Map<String, int> examsMap = {};
      for(var doc in examsSnap.docs) {
        final data = doc.data();
        
        // Local filter by reset date
        if (lastResetDate != null && data.containsKey('createdAt')) {
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          if (createdAt != null && createdAt.isBefore(lastResetDate)) {
            continue;
          }
        }

        final subjectId = data['subjectId'] as String?;
        if(subjectId != null) {
          examsMap[subjectId] = (examsMap[subjectId] ?? 0) + 1;
        }
      }

      final List<Map<String, dynamic>> stats = [];
      for (var subject in subjects) {
        final id = subject.id;
        final name = subject.data()['name'] ?? 'بدون اسم';
        final rev = revenueMap[id] ?? 0;
        final totalSubs = totalSubscribersMap[id] ?? 0;
        final paidSubs = paidSubscriptionsMap[id] ?? 0;
        final exms = examsMap[id] ?? 0;

        stats.add({
          'id': id,
          'name': name,
          'revenue': rev,
          'totalSubscribers': totalSubs,
          'paidSubscriptions': paidSubs,
          'examsCount': exms,
        });
      }

      // Sort by revenue descending
      stats.sort((a, b) => (b['revenue'] as int).compareTo(a['revenue'] as int));

      setState(() {
        _subjectStats = stats;
        _totalRevenue = total;
        _lastResetDate = lastResetDate;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint('Error fetching financial data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetStatistics() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تأكيد التصفير', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Text(
          'هل أنت متأكد أنك تريد تصفير الإحصاءات المالية؟\nسيؤدي هذا إلى بدء حساب الإيرادات من الآن (بداية فصل جديد). لا يمكن التراجع عن هذا الإجراء.',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('تصفير', style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _db.collection('system_settings').doc('financials').set({
          'last_financial_reset': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تصفير الإحصاءات بنجاح.', style: GoogleFonts.cairo()),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _fetchFinancialData();
      } catch (e) {
        debugPrint('Error resetting stats: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _printReport() {
    // In a real app, this would generate a PDF or CSV
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('جاري تجهيز التقرير للطباعة...', style: GoogleFonts.cairo()),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'إدارة الإحصاءات المالية',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
            tooltip: 'تصفير الإحصاءات',
            onPressed: _resetStatistics,
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded, color: AppColors.primaryBlue),
            onPressed: _printReport,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryBlue),
            onPressed: _fetchFinancialData,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Total Revenue Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryBlue, Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'إجمالي الأموال المحصلة (كل المواد)',
                        style: GoogleFonts.cairo(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_totalRevenue ل.س',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_lastResetDate != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'منذ: ${intl.DateFormat('yyyy/MM/dd').format(_lastResetDate!)}',
                            style: GoogleFonts.cairo(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'الإحصاءات منذ البداية (لم يتم التصفير)',
                            style: GoogleFonts.cairo(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'إحصاءات المواد (البطاقات)',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _subjectStats.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final stat = _subjectStats[index];
                    return _buildSubjectCard(stat, isDark);
                  },
                ),
              ],
            ),
        ),
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> stat, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A26) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.book_rounded, color: AppColors.primaryBlue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  stat['name'],
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${stat['revenue']} ل.س',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat('إجمالي المشتركين', '${stat['totalSubscribers']}', Icons.groups_rounded, isDark),
              _buildMiniStat('اشتراكات مدفوعة', '${stat['paidSubscriptions']}', Icons.payments_rounded, isDark),
              _buildMiniStat('الاختبارات', '${stat['examsCount']}', Icons.assignment_turned_in_rounded, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold, 
                fontSize: 14,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
