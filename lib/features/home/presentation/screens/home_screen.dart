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
import 'package:quizzly/features/settings/domain/services/settings_service.dart';
import 'package:quizzly/features/auth/presentation/screens/login_screen.dart';

import 'package:quizzly/features/settings/presentation/screens/settings_screen.dart';
import 'package:quizzly/features/settings/presentation/screens/wallet_screen.dart';
import 'package:quizzly/features/quiz/domain/services/exam_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSyncing = false;
  bool _hasNewNotification = false;
  bool _contentUpdateAvailable = false;
  int _currentTabIndex = 0;
  StreamSubscription? _notifSubscription;
  Timer? _contentUpdateTimer;
  Stream<List<Map<String, dynamic>>>? _activeSubjectsStream;

  // Sorting state variables
  String _sortType = 'newest';
  List<String> _manualOrder = [];
  String? _lastOpenedSubjectId;

  // Subject selection for tab 1
  List<Map<String, dynamic>> _allActiveSubjects = [];
  int _selectedSubjectIndex = 0;

  bool _areSubjectListsEqual(List<Map<String, dynamic>> list1, List<Map<String, dynamic>> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i]['id'] != list2[i]['id']) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _loadSortingSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthService>().addListener(_authListener);
      _initContentUpdateCheck();
    });
    _checkNewNotifications();
  }

  Future<void> _initContentUpdateCheck() async {
    // Run initial check
    await _checkContentUpdates();

    // Setup periodic checking based on user settings
    if (mounted) {
      final settings = context.read<SettingsService>();
      final intervalMinutes = settings.autoUpdateInterval;

      _contentUpdateTimer?.cancel();
      _contentUpdateTimer = Timer.periodic(Duration(minutes: intervalMinutes), (
        timer,
      ) {
        _checkContentUpdates();
      });
    }
  }

  Future<void> _checkContentUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncedStr = prefs.getString('last_synced_content_time');
      if (lastSyncedStr == null) {
        // If the user has never synced before, treat current state as up-to-date initially
        await prefs.setString(
          'last_synced_content_time',
          DateTime.now().toIso8601String(),
        );
        return;
      }

      final lastSyncedTime = DateTime.parse(lastSyncedStr);

      // Query server directly to bypass local cached document state
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('content_metadata')
          .get(const GetOptions(source: Source.server));

      if (doc.exists) {
        final lastUpdateTimestamp =
            doc.data()?['lastContentUpdate'] as Timestamp?;
        if (lastUpdateTimestamp != null) {
          final lastUpdateTime = lastUpdateTimestamp.toDate();
          if (lastUpdateTime.isAfter(lastSyncedTime)) {
            if (mounted) {
              setState(() {
                _contentUpdateAvailable = true;
              });
            }
          }
        }
      } else {
        // Automatically create metadata doc if it does not exist
        await FirebaseFirestore.instance
            .collection('settings')
            .doc('content_metadata')
            .set({
              'lastContentUpdate': FieldValue.serverTimestamp(),
              'description':
                  'Quizzly content metadata for tracking offline version updates',
            });
      }
    } catch (e) {
      debugPrint('Error checking content updates: $e');
    }
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
    _contentUpdateTimer?.cancel();
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

      // Update local last synced time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'last_synced_content_time',
        DateTime.now().toIso8601String(),
      );

      if (mounted) {
        setState(() {
          _contentUpdateAvailable = false;
        });
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

  Widget _buildTabWrapper(Widget child) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (mounted) {
          setState(() {
            _currentTabIndex = 0;
          });
        }
      },
      child: child,
    );
  }

  Widget _buildPremiumBottomBar(bool isDark) {
    final activeColor = isDark
        ? const Color(0xFF818CF8)
        : const Color(0xFF6366F1); // Lavender / Indigo
    final inactiveColor = isDark ? Colors.white38 : Colors.grey.shade500;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : Colors.white;

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade100,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomTabItem(
                index: 0,
                label: 'الرئيسية',
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                isDark: isDark,
              ),
              _buildBottomTabItem(
                index: 1,
                label: 'المواد',
                icon: Icons.school_outlined,
                selectedIcon: Icons.school_rounded,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                isDark: isDark,
              ),
              _buildBottomTabItem(
                index: 2,
                label: 'حسابي',
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomTabItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData selectedIcon,
    required Color activeColor,
    required Color inactiveColor,
    required bool isDark,
  }) {
    final isSelected = _currentTabIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTabIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final contentService = context.read<ContentService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (authService.user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _activeSubjectsStream ??= contentService.getUserActiveSubjects(authService.user!.uid);

    Widget currentBody;
    PreferredSizeWidget? currentAppBar;
    Widget? currentDrawer;
    Widget? currentFAB;

    switch (_currentTabIndex) {
      case 0:
        currentBody = Column(
          children: [
            _buildSubHeaderSection(authService.user!.uid),
            if (_contentUpdateAvailable)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF7ED), Color(0xFFFDF2E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFEDD5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.info_rounded,
                        color: Color(0xFFEA580C),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '📢 يتوفر تحديث جديد للمناهج والأسئلة! يرجى الضغط على زر التحديث الدائري البرتقالي في الأعلى للحصول عليه.',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFC2410C),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _activeSubjectsStream,
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
        );
        currentAppBar = _buildAppBar();
        currentDrawer = const AppDrawer();
        currentFAB = _buildFAB();
        break;
      case 1:
        currentBody = _buildTabWrapper(
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _activeSubjectsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final activeSubjects = snapshot.data ?? [];
              if (activeSubjects.isEmpty) {
                return const SubjectSelectionScreen();
              }

              // Update the list of active subjects and ensure selected index is valid
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_areSubjectListsEqual(_allActiveSubjects, activeSubjects)) {
                  setState(() {
                    _allActiveSubjects = activeSubjects;
                    if (_selectedSubjectIndex >= activeSubjects.length) {
                      _selectedSubjectIndex = 0;
                    }
                  });
                }
              });

              if (_allActiveSubjects.isEmpty) {
                _allActiveSubjects = activeSubjects;
              }

              final currentSubjects = _allActiveSubjects.isNotEmpty
                  ? _allActiveSubjects
                  : activeSubjects;
              final idx = _selectedSubjectIndex < currentSubjects.length
                  ? _selectedSubjectIndex
                  : 0;
              final selectedSubject = currentSubjects[idx];

              return SubjectHubScreen(
                subjectId: selectedSubject['id'] as String,
                subjectName: selectedSubject['name'] as String,
              );
            },
          ),
        );
        currentAppBar = _buildSubjectSelectionAppBar(isDark);
        break;
      case 2:
        currentBody = _buildTabWrapper(const SettingsScreen());
        break;
      default:
        currentBody = const SizedBox.shrink();
    }

    return PopScope(
      canPop: _currentTabIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentTabIndex != 0) {
          setState(() {
            _currentTabIndex = 0;
          });
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawer: currentDrawer,
        appBar: currentAppBar,
        body: currentBody,
        floatingActionButton: currentFAB,
        bottomNavigationBar: _buildPremiumBottomBar(isDark),
      ),
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

  /// AppBar for the "المواد" tab - shows a dropdown subject selector
  PreferredSizeWidget _buildSubjectSelectionAppBar(bool isDark) {
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
      title: _allActiveSubjects.isEmpty
          ? Text(
              'المواد',
              style: GoogleFonts.cairo(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: theme.brightness == Brightness.light
                    ? AppColors.textPrimary
                    : Colors.white,
              ),
            )
          : Directionality(
              textDirection: TextDirection.rtl,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedSubjectIndex < _allActiveSubjects.length
                      ? _selectedSubjectIndex
                      : 0,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: theme.brightness == Brightness.light
                        ? AppColors.textSecondary
                        : Colors.white70,
                  ),
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  dropdownColor: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.brightness == Brightness.light
                        ? AppColors.textPrimary
                        : Colors.white,
                  ),
                  onChanged: (int? newIndex) {
                    if (newIndex != null) {
                      setState(() {
                        _selectedSubjectIndex = newIndex;
                        _trackLastOpenedSubject(
                          _allActiveSubjects[newIndex]['id'],
                        );
                      });
                    }
                  },
                  items: List.generate(_allActiveSubjects.length, (index) {
                    final subject = _allActiveSubjects[index];
                    return DropdownMenuItem<int>(
                      value: index,
                      child: SizedBox(
                        width: 200,
                        child: Text(
                          subject['name'] ?? 'مادة ${index + 1}',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.brightness == Brightness.light
                                ? AppColors.textPrimary
                                : Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    );
                  }),
                  isExpanded: false,
                  alignment: AlignmentDirectional.centerEnd,
                  hint: Text(
                    'اختر مادة',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.brightness == Brightness.light
                          ? AppColors.textPrimary
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
      centerTitle: true,
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
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSubHeaderSection(String userId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, userSnapshot) {
        final balance =
            (userSnapshot.data?.data() as Map<String, dynamic>?)?['balance']
                as int? ??
            0;
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
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Balance Pill
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              );
            },
            borderRadius: BorderRadius.circular(14),
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
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade100,
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
          ),

          // Sort Button
          PopupMenuButton<String>(
            onSelected: _changeSortType,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
                    Text(
                      'يدوي =',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade100,
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
                            userId: context.read<AuthService>().user!.uid,
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
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final subject = sortedSubjects[index];
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: SubjectCard(
                          key: ValueKey('card_${subject['id']}'),
                          subject: subject,
                          index: index,
                          showDragHandle: false,
                          userId: context.read<AuthService>().user!.uid,
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
                  }, childCount: sortedSubjects.length),
                ),
        ),
        SliverToBoxAdapter(child: _buildStatsSection()),
        SliverToBoxAdapter(child: _buildLatestExamsSection(context)),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildStatsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Row(
            children: [
              // 1. Streak Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey[200]!,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.35 : 0.02,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Fire Icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_fire_department_rounded,
                          color: Color(0xFFEF4444),
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Number
                      Text(
                        '5',
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Text
                      Text(
                        'أيام متتالية',
                        style: GoogleFonts.cairo(
                          color: isDark
                              ? Colors.white60
                              : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 2. Curriculum Completion Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey[200]!,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.35 : 0.02,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Progress Ring
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 54,
                            height: 54,
                            child: CircularProgressIndicator(
                              value: 0.75,
                              strokeWidth: 5.5,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.grey[200]!,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF5F5DFA),
                              ),
                            ),
                          ),
                          Text(
                            '75%',
                            style: GoogleFonts.inter(
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Label Title
                      Text(
                        'إكمال المنهج',
                        style: GoogleFonts.cairo(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Subtitle
                      Text(
                        'بقي 3 فصول فقط',
                        style: GoogleFonts.cairo(
                          color: isDark ? Colors.white30 : Colors.grey[400],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLatestExamsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = context.watch<AuthService>();

    if (authService.user == null) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ExamService().streamRecentAttempts(
        authService.user!.uid,
        limit: 5,
      ),
      builder: (context, snapshot) {
        final attempts = snapshot.data ?? [];

        if (attempts.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          // Navigate to exams history
                        },
                        child: Text(
                          'عرض الكل',
                          style: GoogleFonts.cairo(
                            color: const Color(0xFF5F5DFA),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'آخر الاختبارات',
                        style: GoogleFonts.cairo(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Exam Cards List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: attempts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final e = attempts[index];
                      final title = e['examTitle'] ?? 'اختبار';
                      final totalQuestions = e['totalQuestions'] ?? 0;
                      final correctCount = e['correctCount'] ?? 0;
                      final score = (e['score'] as num?)?.toDouble() ?? 0.0;
                      final hasProgress = totalQuestions > 0;
                      final progress = totalQuestions > 0
                          ? correctCount / totalQuestions
                          : 0.0;

                      // Calculate score color
                      Color scoreColor;
                      String scoreLabel;
                      if (score >= 80) {
                        scoreColor = const Color(0xFF10B981);
                        scoreLabel = 'ممتاز';
                      } else if (score >= 60) {
                        scoreColor = const Color(0xFFF59E0B);
                        scoreLabel = 'جيد';
                      } else {
                        scoreColor = const Color(0xFFEF4444);
                        scoreLabel = 'ضعيف';
                      }

                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey[200]!,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.35 : 0.02,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                // 1. Score Badge (Left)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scoreColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    scoreLabel,
                                    style: GoogleFonts.cairo(
                                      color: scoreColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                const Spacer(),

                                // 2. Title & Subtitle (Middle/Right)
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        title,
                                        style: GoogleFonts.cairo(
                                          color: isDark
                                              ? Colors.white
                                              : AppColors.textPrimary,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$correctCount من $totalQuestions صحيح • ${score.toStringAsFixed(0)}%',
                                        style: GoogleFonts.cairo(
                                          color: isDark
                                              ? Colors.white30
                                              : Colors.grey[400],
                                          fontSize: 11.5,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 14),

                                // 3. Score Circle (Far Right)
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${score.toStringAsFixed(0)}%',
                                      style: GoogleFonts.inter(
                                        color: scoreColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Progress Bar
                            if (hasProgress) ...[
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 4.5,
                                  backgroundColor: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.grey[100]!,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    scoreColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
