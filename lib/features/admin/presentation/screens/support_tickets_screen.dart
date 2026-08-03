import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/core/services/telegram_service.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _selectedFilter = 'all'; // 'all', 'open', 'resolved'

  Future<void> _replyToTicket({
    required String ticketId,
    required String telegramChatId,
    required String replyMessage,
  }) async {
    if (replyMessage.trim().isEmpty) return;

    try {
      final ticketRef = _db.collection('support_tickets').doc(ticketId);

      final replyData = {
        'sender': 'admin',
        'message': replyMessage.trim(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      // 1. Update Firestore Ticket document
      await ticketRef.update({
        'status': 'resolved',
        'updatedAt': FieldValue.serverTimestamp(),
        'replies': FieldValue.arrayUnion([replyData]),
      });

      // 2. Send Telegram message directly to user via Bot API (Phase 5)
      final formattedTelegramText =
          "💬 *رد من فريق الدعم الفني - كويزلي:*\n\n"
          "${replyMessage.trim()}\n\n"
          "-----------------------------------\n"
          "نتمنى لك دراسة ممتعة وتوفيقاً دائماً! 🎓";

      final sent = await TelegramService.sendDirectMessage(
        chatId: telegramChatId,
        text: formattedTelegramText,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sent
                  ? 'تم إرسال الرد وتحديث التذكرة بنجاح 🚀'
                  : 'تم تحديث التذكرة، ولكن تعذر الإرسال عبر التليجرام (تأكد من توكن البوت)',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: sent ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الرد: $e', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showReplyDialog(BuildContext context, Map<String, dynamic> ticketData, String ticketId) {
    final replyController = TextEditingController(text: 'تم حل المشكلة.');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = ticketData['userName'] ?? 'المستخدم';
    final telegramChatId = ticketData['telegramChatId'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131A26) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.reply_rounded, color: AppColors.primaryBlue),
            const SizedBox(width: 8),
            Text(
              'الرد على: $userName',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'الشكوى: "${ticketData['message'] ?? ''}"',
                style: GoogleFonts.cairo(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'نص الرد الذي سيرسل عبر البوت:',
              style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: replyController,
              maxLines: 4,
              style: GoogleFonts.cairo(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'اكتب نص الرد هنا...',
                filled: true,
                fillColor: isDark ? const Color(0xFF080C14) : Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.white10 : AppColors.borderLight),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _replyToTicket(
                ticketId: ticketId,
                telegramChatId: telegramChatId,
                replyMessage: replyController.text,
              );
            },
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text('إرسال عبر البوت', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTicketStatus(String ticketId, String currentStatus) async {
    final newStatus = currentStatus == 'resolved' ? 'open' : 'resolved';
    try {
      await _db.collection('support_tickets').doc(ticketId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'resolved' ? 'تمت إضافة العلامة: تم الحل 🟢' : 'تم تغيير الحالة إلى: قيد الانتظار 🟡',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: newStatus == 'resolved' ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C14) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'تذاكر الدعم الفني (Support Tickets)',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Filter Bar ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? const Color(0xFF131A26) : Colors.white,
            child: Row(
              children: [
                _buildFilterChip('all', 'الكل', Icons.list_alt_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('open', 'قيد الانتظار 🟡', Icons.hourglass_top_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('resolved', 'تم الحل 🟢', Icons.check_circle_rounded),
              ],
            ),
          ),

          // ── Tickets List ────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('support_tickets')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('خطأ في تحميل التذاكر: ${snapshot.error}', style: GoogleFonts.cairo()),
                  );
                }

                var docs = snapshot.data?.docs ?? [];

                // Client side filter if composite query index isn't ready
                if (_selectedFilter != 'all') {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['status'] == _selectedFilter;
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 64,
                          color: isDark ? Colors.white24 : Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد تذاكر دعم فني متطابقة حالياً',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            color: isDark ? Colors.white54 : Colors.grey[600],
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
                    final ticketId = doc.id;

                    return _buildTicketCard(data, ticketId, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;
    return Expanded(
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.primaryBlue),
        label: Center(
          child: Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.primaryBlue,
            ),
          ),
        ),
        selectedColor: AppColors.primaryBlue,
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? AppColors.primaryBlue : AppColors.borderLight,
          ),
        ),
        onSelected: (bool selected) {
          setState(() {
            _selectedFilter = value;
          });
        },
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> data, String ticketId, bool isDark) {
    final userName = data['userName'] ?? 'مستخدم غير معروف';
    final userPhone = data['userPhone'] ?? '';
    final category = data['category'] ?? 'عامة';
    final message = data['message'] ?? '';
    final status = data['status'] ?? 'open';
    final telegramUsername = data['telegramUsername'] ?? '';
    final telegramChatId = data['telegramChatId'] ?? '';
    final replies = (data['replies'] as List<dynamic>?) ?? [];

    final Timestamp? ts = data['createdAt'] as Timestamp?;
    final dateStr = ts != null
        ? intl.DateFormat('yyyy/MM/dd - hh:mm a').format(ts.toDate())
        : 'الآن';

    final isResolved = status == 'resolved';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A26) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isResolved
              ? Colors.green.withValues(alpha: 0.3)
              : (isDark ? Colors.white10 : AppColors.borderLight),
          width: isResolved ? 1.5 : 1,
        ),
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
          // Card Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isResolved
                  ? Colors.green.withValues(alpha: 0.05)
                  : (isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: GoogleFonts.cairo(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        Row(
                          children: [
                            if (userPhone.isNotEmpty)
                              Text(
                                userPhone,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.grey[600],
                                ),
                              ),
                            if (userPhone.isNotEmpty && telegramUsername.isNotEmpty)
                              const Text(' • '),
                            if (telegramUsername.isNotEmpty)
                              Text(
                                telegramUsername,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else if (telegramChatId.isNotEmpty)
                              Text(
                                'ID: $telegramChatId',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark ? Colors.white38 : Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                // Status Badge
                GestureDetector(
                  onTap: () => _toggleTicketStatus(ticketId, status),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isResolved
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isResolved ? Colors.green : Colors.orange,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isResolved ? Icons.check_circle : Icons.hourglass_top_rounded,
                          size: 14,
                          color: isResolved ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isResolved ? 'تم الحل' : 'قيد الانتظار',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isResolved ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Card Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    Text(
                      dateStr,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                  ),
                ),

                // Conversation replies log
                if (replies.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'سجل الردود المعالجة:',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white54 : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...replies.map((r) {
                          final rMap = r as Map<String, dynamic>;
                          final isAdmin = rMap['sender'] == 'admin';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isAdmin ? '👨‍💼 المشرف: ' : '👤 الطالب: ',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isAdmin ? AppColors.primaryBlue : Colors.purple,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    rMap['message'] ?? '',
                                    style: GoogleFonts.cairo(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Card Action Footer
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showReplyDialog(context, data, ticketId),
                    icon: const Icon(Icons.reply_rounded, size: 18),
                    label: Text(
                      'رد عبر تليجرام (Reply)',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _toggleTicketStatus(ticketId, status),
                  icon: Icon(
                    isResolved ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                    size: 18,
                    color: isResolved ? Colors.orange : Colors.green,
                  ),
                  label: Text(
                    isResolved ? 'إلغاء التأشير' : 'تأشير كـ تم الحل',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isResolved ? Colors.orange : Colors.green,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isResolved ? Colors.orange : Colors.green),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
