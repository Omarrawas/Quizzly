import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:intl/intl.dart' as intl;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:quizzly/core/services/telegram_service.dart';


class PendingRechargesScreen extends StatefulWidget {
  const PendingRechargesScreen({super.key});

  @override
  State<PendingRechargesScreen> createState() => _PendingRechargesScreenState();
}

class _PendingRechargesScreenState extends State<PendingRechargesScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isProcessing = false;
  String? _processingId;

  Future<void> _autoMatchTransactions(BuildContext context) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Get payment settings
      final settingsDoc = await _db.collection('settings').doc('payments').get();
      if (!settingsDoc.exists || settingsDoc.data() == null) {
        throw 'يرجى ضبط إعدادات شام كاش API أولاً من خلال أيقونة الإعدادات.';
      }

      final data = settingsDoc.data()!;
      final String? token = data['shamCashToken'];
      final String? accountId = data['shamCashAccountId'];

      if (token == null || token.trim().isEmpty || accountId == null || accountId.trim().isEmpty) {
        throw 'إعدادات الـ API غير مكتملة. يرجى إدخال التوكن ومعرف الحساب.';
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
        throw 'فشل الاتصال بـ API شام كاش: كود الحالة ${response.statusCode}';
      }

      final payload = jsonDecode(response.body);
      if (payload['status'] != 'success') {
        throw 'فشل الـ API: ${payload['message'] ?? 'خطأ غير معروف'}';
      }

      final List apiTransactions = payload['data'] ?? [];
      if (apiTransactions.isEmpty) {
        throw 'لا توجد حركات مالية حديثة في حساب شام كاش.';
      }

      // 3. Get pending recharges from Firestore
      final pendingSnap = await _db
          .collection('pending_recharges')
          .where('status', isEqualTo: 'pending')
          .get();

      final pendingRequests = pendingSnap.docs;
      if (pendingRequests.isEmpty) {
        throw 'لا توجد طلبات شحن معلقة لمطابقتها.';
      }

      // 4. Get already approved transaction IDs to prevent reuse
      final approvedSnap = await _db
          .collection('pending_recharges')
          .where('status', isEqualTo: 'approved')
          .get();

      final Set<String> usedTxIds = approvedSnap.docs
          .map((d) => d.data()['shamCashTxId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet();

      int matchCount = 0;

      // 5. Match and approve
      for (final req in pendingRequests) {
        final reqData = req.data();
        final reqDocId = req.id;
        final String userId = reqData['userId'] ?? '';
        final int amount = (reqData['amount'] as num?)?.toInt() ?? 0;
        final String? refCode = reqData['referenceCode']?.toString();

        if (userId.isEmpty || amount <= 0) continue;

        // Find a matching transaction in the API list
        final matchTx = apiTransactions.firstWhere(
          (tx) {
            final txId = tx['id']?.toString() ?? '';
            final txAmount = (tx['amount'] as num?)?.toInt() ?? 0;
            final txType = tx['type']?.toString() ?? '';
            final txNote = tx['note']?.toString() ?? '';

            final bool basicMatch = txId.isNotEmpty &&
                txAmount == amount &&
                txType == 'in' &&
                !usedTxIds.contains(txId);

            if (!basicMatch) return false;

            // If request has referenceCode, require txNote to match it
            if (refCode != null && refCode.trim().isNotEmpty) {
              return txNote.contains(refCode);
            }

            // Fallback for backward compatibility
            return true;
          },
          orElse: () => null,
        );

        if (matchTx != null) {
          final String txId = matchTx['id'].toString();

          // Approve this request in database via transaction
          final userRef = _db.collection('users').doc(userId);
          final rechargeRef = _db.collection('pending_recharges').doc(reqDocId);
          final logRef = _db.collection('credit_logs').doc();

          await _db.runTransaction((transaction) async {
            final userDoc = await transaction.get(userRef);
            if (!userDoc.exists) return;

            final currentBalance = (userDoc.data()?['balance'] as num?)?.toInt() ?? 0;
            final newBalance = currentBalance + amount;

            transaction.update(userRef, {'balance': newBalance});
            transaction.update(rechargeRef, {
              'status': 'approved',
              'shamCashTxId': txId,
              'matchedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            transaction.set(logRef, {
              'userId': userId,
              'amount': amount,
              'type': 'redeem',
              'description': 'تفعيل تلقائي شام كاش (معاملة: $txId)',
              'timestamp': FieldValue.serverTimestamp(),
            });
          });

          // Mark this transaction as used so we don't match it again in this run
          usedTxIds.add(txId);
          matchCount++;
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تمت المطابقة بنجاح! تم تفعيل $matchCount طلبات شحن تلقائياً.',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString(), style: GoogleFonts.tajawal()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showApiSettingsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokenController = TextEditingController();
    final accountIdController = TextEditingController();
    bool isLoading = true;
    const primaryColor = Color(0xFF6E56FF);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          if (isLoading) {
            _db.collection('settings').doc('payments').get().then((doc) {
              if (doc.exists && doc.data() != null) {
                final data = doc.data()!;
                tokenController.text = data['shamCashToken'] ?? '';
                accountIdController.text = data['shamCashAccountId'] ?? '';
              }
              if (mounted) {
                setStateDialog(() {
                  isLoading = false;
                });
              }
            }).catchError((e) {
              if (mounted) {
                setStateDialog(() {
                  isLoading = false;
                });
              }
            });
          }

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF131A26) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'إعدادات شام كاش API',
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            content: isLoading
                ? const SizedBox(
                    height: 100,
                    child: Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: tokenController,
                        obscureText: true,
                        style: GoogleFonts.tajawal(color: isDark ? Colors.white : AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'API Token',
                          labelStyle: GoogleFonts.tajawal(),
                          hintText: 'أدخل sc_token...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: accountIdController,
                        style: GoogleFonts.tajawal(color: isDark ? Colors.white : AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Account ID',
                          labelStyle: GoogleFonts.tajawal(),
                          hintText: 'أدخل معرف الحساب...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
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
                onPressed: isLoading
                    ? null
                    : () async {
                        try {
                          await _db.collection('settings').doc('payments').set({
                            'shamCashToken': tokenController.text.trim(),
                            'shamCashAccountId': accountIdController.text.trim(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'تم حفظ إعدادات الـ API بنجاح.',
                                  style: GoogleFonts.tajawal(),
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('فشل الحفظ: $e', style: GoogleFonts.tajawal()),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'حفظ',
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleApprove(String docId, String userId, int amount) async {
    setState(() {
      _isProcessing = true;
      _processingId = docId;
    });

    try {
      final userRef = _db.collection('users').doc(userId);
      final rechargeRef = _db.collection('pending_recharges').doc(docId);
      final logRef = _db.collection('credit_logs').doc();

      await _db.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
          throw 'المستخدم غير موجود في قاعدة البيانات';
        }

        final currentBalance = (userDoc.data()?['balance'] as num?)?.toInt() ?? 0;
        final newBalance = currentBalance + amount;

        // 1. Update user balance
        transaction.update(userRef, {'balance': newBalance});

        // 2. Update recharge request status
        transaction.update(rechargeRef, {
          'status': 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 3. Write log
        transaction.set(logRef, {
          'userId': userId,
          'amount': amount,
          'type': 'redeem', // Same type as card recharge to show up in revenue/wallet history correctly
          'description': 'شحن رصيد شام كاش (موافقة إدارية)',
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      // Send Telegram Notification (Phase 9)
      TelegramService.notifyActivationApproved(userId, 'تم شحن رصيد بمبلغ $amount ل.س بنجاح إلى حسابك.');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم قبول طلب الشحن وإضافة $amount ل.س بنجاح!',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل العملية: $e', style: GoogleFonts.tajawal()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingId = null;
        });
      }
    }
  }

  Future<void> _handleReject(String docId, {String? userId}) async {
    setState(() {
      _isProcessing = true;
      _processingId = docId;
    });

    try {
      await _db.collection('pending_recharges').doc(docId).update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send Telegram Notification if userId is available (Phase 9)
      if (userId != null && userId.isNotEmpty) {
        TelegramService.notifyPaymentRejected(userId, 'تم رفض طلب الشحن من قبل المشرف.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم رفض طلب الشحن بنجاح.',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل العملية: $e', style: GoogleFonts.tajawal()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const primaryColor = Color(0xFF6E56FF);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'طلبات الشحن المعلقة',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'مطابقة تلقائية عبر API',
            onPressed: _isProcessing ? null : () => _autoMatchTransactions(context),
            color: primaryColor,
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'إعدادات شام كاش API',
            onPressed: _isProcessing ? null : () => _showApiSettingsDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('pending_recharges')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryColor));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'حدث خطأ أثناء جلب الطلبات: ${snapshot.error}',
                  style: GoogleFonts.tajawal(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Sort documents in-memory by timestamp descending to avoid requiring a composite index
          final List<QueryDocumentSnapshot> docs = List.from(snapshot.data?.docs ?? []);
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>?;
            final bData = b.data() as Map<String, dynamic>?;
            final aTime = (aData?['timestamp'] as Timestamp?)?.toDate();
            final bTime = (bData?['timestamp'] as Timestamp?)?.toDate();
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 80,
                    color: isDark ? Colors.white10 : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد طلبات شحن معلقة حالياً',
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      color: isDark ? Colors.white38 : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final String docId = doc.id;
              final String userId = data['userId'] ?? '';
              final String userName = data['userName'] ?? 'طالب غير معروف';
              final String userEmail = data['userEmail'] ?? '';
              final String userPhone = data['userPhone'] ?? '';
              final int amount = (data['amount'] as num?)?.toInt() ?? 0;
              final DateTime time = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

              final isDocProcessing = _isProcessing && _processingId == docId;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                color: isDark ? const Color(0xFF131A26) : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? Colors.white10 : AppColors.borderLight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Amount & Date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${intl.NumberFormat('#,###').format(amount)} ل.س',
                              style: GoogleFonts.tajawal(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            intl.DateFormat('yyyy/MM/dd • HH:mm').format(time),
                            style: GoogleFonts.tajawal(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Student Info
                      Text(
                        'اسم الطالب: $userName',
                        style: GoogleFonts.tajawal(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      if (userEmail.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'البريد الإلكتروني: $userEmail',
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (userPhone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'الهاتف: $userPhone',
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (data['referenceCode'] != null && data['referenceCode'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'الكود المرجعي: ${data['referenceCode']}',
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF7DFFA2) : const Color(0xFF6E56FF),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Actions
                      if (isDocProcessing)
                        const Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isProcessing ? null : () => _handleApprove(docId, userId, amount),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: Text(
                                  'قبول',
                                  style: GoogleFonts.tajawal(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isProcessing ? null : () => _handleReject(docId),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.close_rounded, size: 18),
                                label: Text(
                                  'رفض',
                                  style: GoogleFonts.tajawal(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
