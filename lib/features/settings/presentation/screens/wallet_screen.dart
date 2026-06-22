import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:intl/intl.dart' as intl;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'dart:math';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final TextEditingController _codeController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  bool _isRedeeming = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleRedeem() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _isRedeeming = true);

    try {
      final authService = context.read<AuthService>();
      final userId = authService.user?.uid;

      if (userId == null) throw 'يجب تسجيل الدخول أولاً';

      final result = await _dbService.redeemCode(code, userId);

      if (mounted) {
        _codeController.clear();
        _showSuccessDialog(result['creditValue'], result['newBalance']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString(), style: GoogleFonts.tajawal()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRedeeming = false);
    }
  }

  void _showSuccessDialog(int amount, int newBalance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              'تم شحن الرصيد بنجاح!',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'تمت إضافة $amount ل.س إلى محفظتك.',
              style: GoogleFonts.tajawal(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'رصيدك الحالي: $newBalance ل.س',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('ممتاز', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = context.read<AuthService>().user?.uid;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('محفظتي', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: userId == null
          ? const Center(child: Text('يرجى تسجيل الدخول'))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
              builder: (context, userSnapshot) {
                final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                final balance = userData['balance'] as int? ?? 0;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Balance Card
                      _buildBalanceCard(balance, isDark),
                      const SizedBox(height: 32),

                      // Redeem Section
                      _buildRedeemSection(isDark),
                      const SizedBox(height: 32),

                      // History Section
                      Text(
                        'سجل العمليات',
                        style: GoogleFonts.tajawal(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTransactionHistory(userId, isDark),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildBalanceCard(int balance, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.primaryBlue.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'الرصيد المتوفر',
            style: GoogleFonts.tajawal(color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                intl.NumberFormat('#,###').format(balance),
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ل.س',
                style: GoogleFonts.tajawal(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRedeemSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'شحن الرصيد',
          style: GoogleFonts.tajawal(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.centerLeft,
                children: [
                  TextField(
                    controller: _codeController,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'أدخل كود الشحن',
                      hintStyle: GoogleFonts.tajawal(
                        fontSize: 16,
                        letterSpacing: 0,
                        color: isDark ? Colors.white24 : Colors.grey,
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: IconButton(
                      icon: Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryBlue, size: 28),
                      onPressed: _showScanner,
                      tooltip: 'مسح QR Code',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isRedeeming ? null : _handleRedeem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isRedeeming
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'تفعيل الكود',
                          style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              
              // ── Sham Cash Purchase Button ──
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () => _showRechargeAmountDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0EA5E9),
                    side: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.account_balance_wallet_rounded, size: 22),
                  label: Text(
                    'الشراء عبر شام كاش',
                    style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'مسح كود الشحن',
                style: GoogleFonts.tajawal(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: MobileScanner(
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final String? code = barcodes.first.rawValue;
                      if (code != null) {
                        setState(() => _codeController.text = code);
                        Navigator.pop(context);
                        _handleRedeem();
                      }
                    }
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'وجه الكاميرا نحو الـ QR Code الموجود على البطاقة',
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionHistory(String userId, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('credit_logs')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snapshot.data?.docs ?? [];

        if (logs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.history_rounded, size: 48, color: isDark ? Colors.white10 : Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text(
                    'لا يوجد سجل عمليات حتى الآن',
                    style: GoogleFonts.tajawal(color: isDark ? Colors.white38 : Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index].data() as Map<String, dynamic>;
            final type = log['type'] as String;
            final amount = log['amount'] as int;
            final timestamp = (log['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            final description = log['description'] as String? ?? '';

            final isCredit = type == 'redeem';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey[100]!),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isCredit ? Colors.green : Colors.red).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCredit ? Icons.add_rounded : Icons.remove_rounded,
                      color: isCredit ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          description,
                          style: GoogleFonts.tajawal(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          intl.DateFormat('yyyy/MM/dd • HH:mm').format(timestamp),
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isCredit ? "+" : "-"}${intl.NumberFormat('#,###').format(amount.abs())}',
                    style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isCredit ? Colors.green : Colors.red,
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

  void _showRechargeAmountDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    const primaryColor = Color(0xFF6E56FF);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'شحن الرصيد عبر شام كاش',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الرجاء إدخال كمية الرصيد المراد تعبئتها (ل.س):',
                style: GoogleFonts.tajawal(
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'مثال: 10000',
                  hintStyle: GoogleFonts.tajawal(color: Colors.grey),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال المبلغ';
                  }
                  final parsed = int.tryParse(value.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'الرجاء إدخال مبلغ صحيح';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: GoogleFonts.tajawal(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final amount = int.parse(amountController.text.trim());
                final refCode = (Random().nextInt(900000) + 100000).toString();
                Navigator.pop(context);
                _showShamCashPaymentDialog(context, amount, refCode);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'موافق',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showShamCashPaymentDialog(BuildContext context, int amount, String refCode) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF6E56FF);
    bool isSubmitting = false;
    bool isLoadingSettings = true;
    String accountId = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          if (isLoadingSettings) {
            FirebaseFirestore.instance.collection('settings').doc('payments').get().then((doc) {
              if (doc.exists && doc.data() != null) {
                if (context.mounted) {
                  setStateDialog(() {
                    accountId = doc.data()?['shamCashAccountId'] ?? '';
                    isLoadingSettings = false;
                  });
                }
              } else {
                if (context.mounted) {
                  setStateDialog(() => isLoadingSettings = false);
                }
              }
            }).catchError((_) {
              if (context.mounted) {
                setStateDialog(() => isLoadingSettings = false);
              }
            });
          }

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'تحويل الرصيد',
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            content: isLoadingSettings
                ? const SizedBox(
                    height: 100,
                    child: Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'يرجى تحويل مبلغ ${intl.NumberFormat('#,###').format(amount)} ل.س إلى حساب شام كاش الموضح أدناه:',
                          style: GoogleFonts.tajawal(
                            color: isDark ? Colors.white70 : AppColors.textSecondary,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        // Account ID Container
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'رقم الحساب',
                                      style: GoogleFonts.tajawal(
                                        fontSize: 11,
                                        color: isDark ? Colors.white38 : Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      accountId.isNotEmpty ? accountId : 'لم يتم تحديد حساب الدفع',
                                      style: GoogleFonts.tajawal(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (accountId.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, color: primaryColor),
                                  tooltip: 'نسخ رقم الحساب',
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: accountId));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'تم نسخ رقم الحساب بنجاح',
                                          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                                        ),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Reference Code Container
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'الكود المرجعي (ملاحظة التحويل)',
                                      style: GoogleFonts.tajawal(
                                        fontSize: 11,
                                        color: isDark ? Colors.white38 : Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      refCode,
                                      style: GoogleFonts.tajawal(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF7DFFA2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, color: primaryColor),
                                tooltip: 'نسخ الكود المرجعي',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: refCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'تم نسخ الكود المرجعي بنجاح',
                                        style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                                      ),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Warning card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4C6A).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFF4C6A).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4C6A), size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'هام جداً: يجب كتابة أو لصق الكود المرجعي أعلاه في حقل "ملاحظة التحويل" عند الدفع في شام كاش لضمان شحن رصيدك تلقائياً وفورياً.',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 12,
                                    color: const Color(0xFFFF4C6A),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (isSubmitting)
                          const CircularProgressIndicator(color: primaryColor)
                      ],
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: Text(
                  'تراجع',
                  style: GoogleFonts.tajawal(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setStateDialog(() => isSubmitting = true);
                        try {
                          final authService = this.context.read<AuthService>();
                          final userId = authService.user?.uid;
                          if (userId == null) throw 'يجب تسجيل الدخول أولاً';

                          // Get user details
                          String userName = 'طالب';
                          String userEmail = authService.user?.email ?? '';
                          String userPhone = authService.user?.phoneNumber ?? '';

                          final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
                          if (userDoc.exists) {
                            final uData = userDoc.data() ?? {};
                            userName = uData['name'] ?? uData['email'] ?? 'طالب';
                          }

                          // 1. Try immediate auto-matching!
                          final isAutoMatched = await _tryAutoMatchAndCharge(
                            userId,
                            userName,
                            userEmail,
                            userPhone,
                            amount,
                            refCode,
                          );

                          if (isAutoMatched) {
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                            return;
                          }

                          // 2. Fallback: Save to pending_recharges if not auto-matched
                          await FirebaseFirestore.instance.collection('pending_recharges').add({
                            'userId': userId,
                            'userName': userName,
                            'userEmail': userEmail,
                            'userPhone': userPhone,
                            'amount': amount,
                            'status': 'pending',
                            'referenceCode': refCode,
                            'timestamp': FieldValue.serverTimestamp(),
                          });

                          if (context.mounted) {
                            Navigator.pop(context);
                            _showPostPaymentInstructionsDialog(context, amount);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('حدث خطأ: $e', style: GoogleFonts.tajawal()),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setStateDialog(() => isSubmitting = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'تم الدفع',
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPostPaymentInstructionsDialog(BuildContext context, int amount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF6E56FF);
    bool isLoadingLinks = true;
    String whatsappUrl = 'https://wa.me/963955555555';
    String telegramUrl = 'https://t.me/QuizzlySupportBot';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          // Load links if not loaded
          if (isLoadingLinks) {
            FirebaseFirestore.instance.collection('settings').doc('socials').get().then((doc) {
              if (doc.exists && doc.data() != null) {
                final data = doc.data()!;
                if (mounted) {
                  setStateDialog(() {
                    whatsappUrl = data['whatsappUrl'] ?? 'https://wa.me/963955555555';
                    telegramUrl = data['supportBotUrl'] ?? data['telegramUrl'] ?? 'https://t.me/QuizzlySupportBot';
                    isLoadingLinks = false;
                  });
                }
              } else {
                if (mounted) {
                  setStateDialog(() => isLoadingLinks = false);
                }
              }
            }).catchError((e) {
              if (mounted) {
                setStateDialog(() => isLoadingLinks = false);
              }
            });
          }

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'طلب الشحن قيد الانتظار',
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.pending_actions_rounded,
                  color: Colors.orange,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'تم تسجيل طلب الشحن بقيمة ${intl.NumberFormat('#,###').format(amount)} ل.س بنجاح.',
                  style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'لتأكيد عملية الشحن وتفعيل الرصيد، يرجى إرسال لقطة شاشة (Screenshot) لمعاملة الدفع في شام كاش إلينا عبر واتساب أو تلغرام. سيبقى طلبك معلقاً حتى يوافق المسؤول.',
                  style: GoogleFonts.tajawal(
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (isLoadingLinks)
                  const CircularProgressIndicator(color: primaryColor)
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            String link = whatsappUrl;
                            final msg = 'مرحباً، قمت بتحويل الرصيد عبر شام كاش وأريد تفعيل طلبي بقيمة $amount ل.س.';
                            if (!link.contains('?')) {
                              link = '$link?text=${Uri.encodeComponent(msg)}';
                            } else {
                              link = '$link&text=${Uri.encodeComponent(msg)}';
                            }
                            _launchURL(link);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.chat_rounded, size: 20),
                          label: Text(
                            'واتساب',
                            style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _launchURL(telegramUrl),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0088CC),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.telegram_rounded, size: 20),
                          label: Text(
                            'تلغرام',
                            style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'موافق',
                  style: GoogleFonts.tajawal(color: primaryColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _tryAutoMatchAndCharge(
    String userId,
    String userName,
    String userEmail,
    String userPhone,
    int amount,
    String refCode,
  ) async {
    try {
      // 1. Get payment settings
      final settingsDoc = await FirebaseFirestore.instance.collection('settings').doc('payments').get();
      if (!settingsDoc.exists || settingsDoc.data() == null) {
        return false;
      }

      final data = settingsDoc.data()!;
      final String? token = data['shamCashToken'];
      final String? accountId = data['shamCashAccountId'];

      if (token == null || token.trim().isEmpty || accountId == null || accountId.trim().isEmpty) {
        return false;
      }

      // 2. Fetch recent transactions from Sham Cash API
      final response = await http.get(
        Uri.parse('https://api.shamcash-api.com/v1/transactions?account_id=$accountId&limit=50'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        return false;
      }

      final payload = jsonDecode(response.body);
      if (payload['status'] != 'success') {
        return false;
      }

      final List apiTransactions = payload['data'] ?? [];
      if (apiTransactions.isEmpty) {
        return false;
      }

      // 3. Find a matching, unused transaction
      for (final tx in apiTransactions) {
        final txId = tx['id']?.toString() ?? '';
        final txAmount = (tx['amount'] as num?)?.toInt() ?? 0;
        final txType = tx['type']?.toString() ?? '';
        final txNote = tx['note']?.toString() ?? '';

        if (txId.isNotEmpty && txAmount == amount && txType == 'in' && txNote.contains(refCode)) {
          // Check if this txId was already matched
          final dupQuery = await FirebaseFirestore.instance
              .collection('pending_recharges')
              .where('shamCashTxId', isEqualTo: txId)
              .get();

          if (dupQuery.docs.isEmpty) {
            // Unused matching transaction found! Process credit instantly in a transaction
            final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
            final rechargeRef = FirebaseFirestore.instance.collection('pending_recharges').doc();
            final logRef = FirebaseFirestore.instance.collection('credit_logs').doc();

            int finalBalance = 0;

            await FirebaseFirestore.instance.runTransaction((transaction) async {
              final userDoc = await transaction.get(userRef);
              if (!userDoc.exists) return;

              final currentBalance = (userDoc.data()?['balance'] as num?)?.toInt() ?? 0;
              finalBalance = currentBalance + amount;

              transaction.update(userRef, {'balance': finalBalance});
              transaction.set(rechargeRef, {
                'userId': userId,
                'userName': userName,
                'userEmail': userEmail,
                'userPhone': userPhone,
                'amount': amount,
                'status': 'approved',
                'shamCashTxId': txId,
                'referenceCode': refCode,
                'timestamp': FieldValue.serverTimestamp(),
                'matchedAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              transaction.set(logRef, {
                'userId': userId,
                'amount': amount,
                'type': 'redeem',
                'description': 'شحن تلقائي شام كاش (معاملة: $txId)',
                'timestamp': FieldValue.serverTimestamp(),
              });
            });

            if (mounted) {
              _showSuccessDialog(amount, finalBalance);
            }
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('Auto-match error: $e');
    }
    return false;
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فتح الرابط: $urlString', style: GoogleFonts.tajawal()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

