import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/home/domain/services/content_service.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';
import 'package:quizzly/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    _markAsSeen();
  }

  Future<void> _markAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    // Use slightly later time to ensure any current notification is considered seen
    await prefs.setString('lastSeenNotifTime', DateTime.now().add(const Duration(seconds: 1)).toIso8601String());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authService = context.read<AuthService>();
    final contentService = context.read<ContentService>();
    final userId = authService.user?.uid;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppColors.textPrimary,
            size: 20,
          ),
        ),
        title: Text(
          'الإشعارات',
          style: GoogleFonts.cairo(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: userId == null 
        ? _buildEmptyState(isDark)
        : StreamBuilder<List<Map<String, dynamic>>>(
            stream: contentService.getUserActiveSubjects(userId),
            builder: (context, activeSubSnap) {
              final activeSubjectIds = activeSubSnap.data?.map((s) => s['id'] as String).toList() ?? [];

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('notifications')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allNotifs = snapshot.data?.docs ?? [];
                  final filteredNotifs = allNotifs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final target = data['target'];
                    if (target == 'all') return true;
                    if (target == 'subject') {
                      return activeSubjectIds.contains(data['subjectId']);
                    }
                    return false;
                  }).take(5).toList();

                  if (filteredNotifs.isEmpty) {
                    return _buildEmptyState(isDark);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredNotifs.length,
                    itemBuilder: (context, index) {
                      final data = filteredNotifs[index].data() as Map<String, dynamic>;
                      return _buildNotificationCard(data, isDark);
                    },
                  );
                },
              );
            },
          ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> data, bool isDark) {
    final title = data['title'] ?? '';
    final body = data['body'] ?? '';
    final type = data['type'] ?? 'general';
    final timestamp = data['timestamp'] as Timestamp?;
    final dateStr = timestamp != null 
        ? intl.DateFormat('yyyy/MM/dd - hh:mm a').format(timestamp.toDate())
        : '';

    IconData icon;
    Color color;
    switch (type) {
      case 'subject_update':
        icon = Icons.update_rounded;
        color = Colors.blue;
        break;
      case 'general':
      default:
        icon = Icons.campaign_rounded;
        color = Colors.orange;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A26) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
                if (data['subjectName'] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      data['subjectName'],
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ],
                
                // --- Rich Media: Image ---
                if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      data['imageUrl'],
                      width: double.infinity,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(),
                    ),
                  ),
                ],

                // --- Action Buttons ---
                if ((data['actionUrl'] != null && data['actionUrl'].toString().isNotEmpty) || 
                    (data['route'] != null && data['route'].toString().isNotEmpty)) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (data['actionUrl'] != null && data['actionUrl'].toString().isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () async {
                            final url = Uri.parse(data['actionUrl']);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: Text('فتح الرابط', style: GoogleFonts.cairo(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryBlue,
                            side: const BorderSide(color: AppColors.primaryBlue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                        ),
                      if (data['route'] != null && data['route'].toString().isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () {
                            if (navigatorKey.currentState != null) {
                              navigatorKey.currentState!.pushNamed(data['route']);
                            }
                          },
                          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: Text('الانتقال', style: GoogleFonts.cairo(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            elevation: 0,
                          ),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 8),
                Text(
                  dateStr,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد إشعارات',
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أنت على إطلاع دائم بجميع التحديثات!',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
