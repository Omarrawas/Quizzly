import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/core/theme/theme_service.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/home/domain/services/content_service.dart';
import 'package:quizzly/features/home/presentation/widgets/app_drawer.dart';
import 'package:quizzly/features/home/presentation/widgets/subject_card.dart';
import 'package:quizzly/features/subject/presentation/screens/subject_hub_screen.dart';
import 'package:quizzly/features/home/presentation/screens/subject_selection_screen.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quizzly/features/quiz/domain/services/smart_notification_service.dart';
import 'package:quizzly/features/home/presentation/screens/notifications_screen.dart';
import 'package:quizzly/features/auth/presentation/screens/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSyncing = false;
  bool _hasNewNotification = false;
  StreamSubscription? _notifSubscription;

  // Sorting state variables
  String _sortType = 'newest';
  List<String> _manualOrder = [];
  String? _lastOpenedSubjectId;

  @override
  void initState() {
    super.initState();
    _loadSortingSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthService>().addListener(_authListener);
    });
    _checkNewNotifications();
  }

  Future<void> _loadSortingSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _sortType = prefs.getString('home_subject_sort_type') ?? 'newest';
        _manualOrder = prefs.getStringList('home_subject_manual_order') ?? [];
        _lastOpenedSubjectId = prefs.getString('last_opened_subject_id');
      });
    }
  }

  Future<void> _changeSortType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('home_subject_sort_type', type);
    if (mounted) {
      setState(() {
        _sortType = type;
      });
    }
  }

  Future<void> _saveManualOrder(List<Map<String, dynamic>> subjects) async {
    final prefs = await SharedPreferences.getInstance();
    final order = subjects.map((s) => s['id'] as String).toList();
    await prefs.setStringList('home_subject_manual_order', order);
    if (mounted) {
      setState(() {
        _manualOrder = order;
      });
    }
  }

  Future<void> _trackLastOpenedSubject(String subjectId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_opened_subject_id', subjectId);
    if (mounted) {
      setState(() {
        _lastOpenedSubjectId = subjectId;
      });
    }
  }

  String _getSortTypeLabel() {
    switch (_sortType) {
      case 'newest':
        return 'الأحدث';
      case 'last_opened':
        return 'آخر فتح';
      case 'manual':
        return 'يدوي =';
      default:
        return 'الأحدث';
    }
  }

  void _checkNewNotifications() {
    // Listen for new notifications
    _notifSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
          if (snapshot.docs.isNotEmpty) {
            final latestDoc = snapshot.docs.first;
            final data = latestDoc.data();
            final latestTime = (data['timestamp'] as Timestamp?)?.toDate();

            final prefs = await SharedPreferences.getInstance();
            final lastSeenStr = prefs.getString('lastSeenNotifTime');
            DateTime? lastSeen;
            if (lastSeenStr != null) {
              lastSeen = DateTime.parse(lastSeenStr);
            }

            if (latestTime != null &&
                (lastSeen == null || latestTime.isAfter(lastSeen))) {
              if (mounted && !_hasNewNotification) {
                setState(() => _hasNewNotification = true);
                // Optionally, we can pop a local notification here if we want it to show while app is open
                final title = data['title'] ?? 'إشعار جديد';
                final body = data['body'] ?? 'لديك تحديث جديد';

                // To avoid spamming on every start, check if we already showed this specific one
                final lastPoppedId = prefs.getString('lastPoppedNotifId');
                if (lastPoppedId != latestDoc.id) {
                  await prefs.setString('lastPoppedNotifId', latestDoc.id);
                  // Trigger local notification so it appears in the notification bar
                  SmartNotificationService().showPlainNotification(
                    id: latestDoc.id.hashCode,
                    title: title,
                    body: body,
                  );
                }
              }
            } else {
              if (mounted && _hasNewNotification) {
                setState(() => _hasNewNotification = false);
              }
            }
          }
        });
  }

  void _authListener() {
    final auth = context.read<AuthService>();
    if (auth.user == null && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    context.read<AuthService>().removeListener(_authListener);
    super.dispose();
  }

  void _openActivationFlow() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubjectSelectionScreen()),
    );
  }

  Future<void> _syncDataForOffline() async {
    final authService = context.read<AuthService>();
    final contentService = context.read<ContentService>();

    if (authService.user == null) return;

    setState(() => _isSyncing = true);

    try {
      await contentService.syncOfflineData(authService.user!.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تحديث البيانات، التطبيق جاهز للعمل بدون إنترنت ✅',
              style: GoogleFonts.cairo(),
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
            content: Text('حدث خطأ أثناء التحديث', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final contentService = context.read<ContentService>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: _buildAppBar(),
      body: authService.user == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSubHeaderSection(authService.user!.uid),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: contentService.getUserActiveSubjects(
                      authService.user!.uid,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final subjects = snapshot.data ?? [];

                      return _buildBody(subjects);
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: theme.appBarTheme.backgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          onPressed: () => Scaffold.of(context).openDrawer(),
          icon: Icon(
            Icons.menu_rounded,
            color: theme.brightness == Brightness.light
                ? AppColors.textPrimary
                : Colors.white,
            size: 28,
          ),
        ),
      ),
      title: Text(
        'كويزلي',
        style: GoogleFonts.cairo(
          fontSize: 19,
          fontWeight: FontWeight.bold,
          color: theme.brightness == Brightness.light
              ? AppColors.textPrimary
              : Colors.white,
        ),
      ),
      centerTitle: false,
      actions: [
        Consumer<ThemeService>(
          builder: (context, themeService, _) {
            final isLight = themeService.themeMode == ThemeMode.light;
            return IconButton(
              onPressed: themeService.toggleTheme,
              icon: Icon(
                isLight
                    ? Icons.wb_sunny_outlined
                    : Icons.nightlight_round_outlined,
                color: Theme.of(context).brightness == Brightness.light
                    ? AppColors.textSecondary
                    : Colors.white,
                size: 24,
              ),
              tooltip: 'المظهر',
            );
          },
        ),
        if (_hasNewNotification)
          Stack(
            children: [
              IconButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                  // Clear dot when returning
                  if (mounted) setState(() => _hasNewNotification = false);
                },
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.textSecondary,
                  size: 26,
                ),
                tooltip: 'الإشعارات',
              ),
              // Badge Indicator
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                ),
              ),
            ],
          ),
        GestureDetector(
          onTap: _isSyncing ? null : _syncDataForOffline,
          child: Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(left: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFFF8500),
              shape: BoxShape.circle,
            ),
            child: _isSyncing
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSubHeaderSection(String userId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, userSnapshot) {
        final balance = (userSnapshot.data?.data() as Map<String, dynamic>?)?['balance'] as int? ?? 0;
        return _buildSubHeader(balance);
      },
    );
  }

  Widget _buildSubHeader(int balance) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Balance Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.green,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'الرصيد: $balance ل.س',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Sort Button
          PopupMenuButton<String>(
            onSelected: _changeSortType,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'newest',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('الأحدث', style: GoogleFonts.cairo(fontSize: 13)),
                    const SizedBox(width: 8),
                    const Icon(Icons.calendar_today_rounded, size: 16),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'last_opened',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('آخر فتح', style: GoogleFonts.cairo(fontSize: 13)),
                    const SizedBox(width: 8),
                    const Icon(Icons.history_rounded, size: 16),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'manual',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('يدوي =', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    const Icon(Icons.drag_handle_rounded, size: 16),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getSortTypeLabel(),
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.sort_rounded,
                    color: AppColors.primaryBlue,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> subjects) {
    if (subjects.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 80,
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا يوجد مواد مضافة بعد',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اضغط على زر + لإضافة مواد والبدء في الدراسة',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Sort subjects based on sort type
    List<Map<String, dynamic>> sortedSubjects = List.from(subjects);
    if (_sortType == 'newest') {
      sortedSubjects.sort((a, b) {
        final aTime = a['addedAt'] as Timestamp?;
        final bTime = b['addedAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // descending (newest first)
      });
    } else if (_sortType == 'last_opened') {
      if (_lastOpenedSubjectId != null) {
        sortedSubjects.sort((a, b) {
          if (a['id'] == _lastOpenedSubjectId) return -1;
          if (b['id'] == _lastOpenedSubjectId) return 1;
          return 0;
        });
      }
    } else if (_sortType == 'manual') {
      if (_manualOrder.isNotEmpty) {
        sortedSubjects.sort((a, b) {
          final aIndex = _manualOrder.indexOf(a['id']);
          final bIndex = _manualOrder.indexOf(b['id']);
          if (aIndex == -1 && bIndex == -1) return 0;
          if (aIndex == -1) return 1;
          if (bIndex == -1) return -1;
          return aIndex.compareTo(bIndex);
        });
      }
    }

    final isManual = _sortType == 'manual';

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          sliver: isManual
              ? SliverReorderableList(
                  itemBuilder: (context, index) {
                    final subject = sortedSubjects[index];
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(subject['id']),
                      index: index,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: SubjectCard(
                            key: ValueKey('card_${subject['id']}'),
                            subject: subject,
                            index: index,
                            showDragHandle: true,
                            onTap: () {
                              _trackLastOpenedSubject(subject['id']);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SubjectHubScreen(
                                    subjectId: subject['id'],
                                    subjectName: subject['name'],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  itemCount: sortedSubjects.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final item = sortedSubjects.removeAt(oldIndex);
                      sortedSubjects.insert(newIndex, item);
                      _saveManualOrder(sortedSubjects);
                    });
                  },
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final subject = sortedSubjects[index];
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: SubjectCard(
                            key: ValueKey('card_${subject['id']}'),
                            subject: subject,
                            index: index,
                            showDragHandle: false,
                            onTap: () {
                              _trackLastOpenedSubject(subject['id']);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SubjectHubScreen(
                                    subjectId: subject['id'],
                                    subjectName: subject['name'],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                    childCount: sortedSubjects.length,
                  ),
                ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: _openActivationFlow,
      backgroundColor: AppColors.primaryBlue,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 34),
    );
  }
}
