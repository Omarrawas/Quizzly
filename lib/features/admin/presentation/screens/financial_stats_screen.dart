import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

      // 2. Fetch all purchases to calculate revenue per subject
      final purchasesSnap = await _db.collection('user_subjects')
          .where('type', isEqualTo: 'purchase')
          .get();

      final Map<String, int> revenueMap = {};
      final Map<String, int> activationCountMap = {};
      int total = 0;

      for (var doc in purchasesSnap.docs) {
        final data = doc.data();
        final subjectId = data['subjectId'] as String?;
        final price = (data['price'] as num?)?.toInt() ?? 0;
        
        if (subjectId != null) {
          revenueMap[subjectId] = (revenueMap[subjectId] ?? 0) + price;
          activationCountMap[subjectId] = (activationCountMap[subjectId] ?? 0) + 1;
          total += price;
        }
      }

      // Fetch exams/evaluations to get some stats (e.g. number of exams)
      final examsSnap = await _db.collection('exams').get();
      final Map<String, int> examsMap = {};
      for(var doc in examsSnap.docs) {
        final subjectId = doc.data()['subjectId'] as String?;
        if(subjectId != null) {
          examsMap[subjectId] = (examsMap[subjectId] ?? 0) + 1;
        }
      }

      final List<Map<String, dynamic>> stats = [];
      for (var subject in subjects) {
        final id = subject.id;
        final name = subject.data()['name'] ?? 'بدون اسم';
        final rev = revenueMap[id] ?? 0;
        final acts = activationCountMap[id] ?? 0;
        final exms = examsMap[id] ?? 0;

        stats.add({
          'id': id,
          'name': name,
          'revenue': rev,
          'activations': acts,
          'examsCount': exms,
        });
      }

      // Sort by revenue descending
      stats.sort((a, b) => (b['revenue'] as int).compareTo(a['revenue'] as int));

      setState(() {
        _subjectStats = stats;
        _totalRevenue = total;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint('Error fetching financial data: $e');
      if (mounted) {
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
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
              _buildMiniStat('عمليات الشراء', '${stat['activations']}', Icons.shopping_cart_rounded, isDark),
              _buildMiniStat('الاختبارات (التقويم)', '${stat['examsCount']}', Icons.assignment_turned_in_rounded, isDark),
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
