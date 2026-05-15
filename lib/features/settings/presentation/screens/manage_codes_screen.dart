import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:intl/intl.dart' as intl;

class ManageCodesScreen extends StatefulWidget {
  const ManageCodesScreen({super.key});

  @override
  State<ManageCodesScreen> createState() => _ManageCodesScreenState();
}

class _ManageCodesScreenState extends State<ManageCodesScreen> {
  int _selectedIndex = 0; // 0: التفعيلات المدفوعة, 1: التفعيلات المجانية
  final DatabaseService _dbService = DatabaseService();
  late Stream<QuerySnapshot> _activationsStream;

  @override
  void initState() {
    super.initState();
    _activationsStream = _dbService.getActivations();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppColors.textPrimary,
            size: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() {
              _activationsStream = _dbService.getActivations();
            }),
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white38 : AppColors.textSecondary,
              size: 24,
            ),
          ),
        ],
        title: Text(
          'إدارة الأكواد',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _buildTabs(isDark),
        ),
      ),
      body: _buildActivationsList(isPaid: _selectedIndex == 0, isDark: isDark),
    );
  }

  Widget _buildActivationsList({required bool isPaid, required bool isDark}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _activationsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue));
        }
        
        final allDocs = snapshot.data?.docs ?? [];
        
        // Smart filtering for both old and new data
        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final type = data['activationType']?.toString();
          final code = data['activationCode']?.toString();
          
          if (isPaid) {
            // Document is 'paid' if type is 'code' OR if it has a non-empty activationCode
            return type == 'code' || (code != null && code.isNotEmpty && code != 'null');
          } else {
            // Document is 'free' if type is 'free' OR if it explicitly has no code
            return type == 'free' || code == null || code.isEmpty || code == 'null';
          }
        }).toList();

        if (docs.isEmpty) {
          return _buildEmptyState(
            isPaid ? Icons.account_balance_wallet_rounded : Icons.person_add_alt_1_rounded,
            isPaid ? 'لا توجد تفعيلات مدفوعة حالياً' : 'لا توجد تفعيلات مجانية حالياً',
            isDark,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final userId = data['userId'] as String;
            final subjectId = data['subjectId'] as String;
            final activationCode = data['activationCode'] as String?;
            final date = data['activatedAt'] != null ? (data['activatedAt'] as Timestamp).toDate() : DateTime.now();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey[100]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isPaid ? AppColors.primaryBlue.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPaid ? Icons.verified_rounded : Icons.person_rounded,
                      color: isPaid ? AppColors.primaryBlue : Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<DocumentSnapshot>(
                          future: _dbService.getUser(userId),
                          builder: (context, userSnap) {
                            final name = (userSnap.data?.data() as Map<String, dynamic>?)?['displayName'] ?? '...';
                            return Text(
                              name,
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold, 
                                fontSize: 16, 
                                color: isDark ? Colors.white : AppColors.textPrimary
                              ),
                            );
                          },
                        ),
                        Row(
                          children: [
                            Icon(Icons.book_rounded, size: 12, color: isPaid ? Colors.blue[800] : AppColors.primaryBlue),
                            const SizedBox(width: 4),
                            Expanded(
                              child: FutureBuilder<DocumentSnapshot>(
                                future: _dbService.getSubject(subjectId),
                                builder: (context, subjSnap) {
                                  final name = (subjSnap.data?.data() as Map<String, dynamic>?)?['name'] ?? '...';
                                  return Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.cairo(
                                      fontSize: 13, 
                                      color: isPaid ? Colors.blue[800] : AppColors.primaryBlue, 
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        if (isPaid && activationCode != null)
                          Container(
                            margin: const EdgeInsets.only(top: 4, bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.vpn_key_rounded, size: 10, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  activationCode,
                                  style: GoogleFonts.inter(
                                    fontSize: 11, 
                                    fontWeight: FontWeight.bold, 
                                    color: isDark ? Colors.white70 : Colors.grey[700], 
                                    letterSpacing: 0.5
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              intl.DateFormat('yyyy/MM/dd • HH:mm').format(date),
                              style: GoogleFonts.inter(
                                fontSize: 11, 
                                color: isDark ? Colors.white24 : Colors.grey[400]
                              ),
                            ),
                            if (data['expiresAt'] != null)
                              Text(
                                'ينتهي: ${intl.DateFormat('yyyy/MM/dd').format((data['expiresAt'] as Timestamp).toDate())}',
                                style: GoogleFonts.cairo(fontSize: 10, color: Colors.red[300], fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.red.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    child: IconButton(
                      onPressed: () => _confirmDeleteActivation(doc.id, isDark),
                      icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 22),
                      tooltip: 'حذف التفعيل',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteActivation(String id, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'حذف التفعيل', 
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.red)
        ),
        content: Text(
          'هل أنت متأكد من حذف هذا التفعيل؟ سيتم قفل المادة عند المستخدم فوراً.', 
          style: GoogleFonts.cairo(color: isDark ? Colors.white70 : Colors.black87)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text(
              'إلغاء', 
              style: GoogleFonts.cairo(color: isDark ? Colors.white38 : Colors.grey)
            )
          ),
          TextButton(
            onPressed: () async {
              await _dbService.deleteActivation(id);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(
              'حذف', 
              style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: isDark ? Colors.white10 : AppColors.textSecondary.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white38 : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildTab(
              title: 'التفعيلات المدفوعة',
              index: 0,
              icon: Icons.verified_user_rounded,
              isDark: isDark,
            ),
            _buildTab(
              title: 'التفعيلات المجانية',
              index: 1,
              icon: Icons.person_add_alt_1_rounded,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab({required String title, required int index, required IconData icon, required bool isDark}) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? const Color(0xFF1E293B) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.primaryBlue : (isDark ? Colors.white38 : AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? AppColors.primaryBlue : (isDark ? Colors.white38 : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
