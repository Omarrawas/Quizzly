import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/gamification/domain/services/subject_league_service.dart';

class SubjectLeagueScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;

  const SubjectLeagueScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<SubjectLeagueScreen> createState() => _SubjectLeagueScreenState();
}

class _SubjectLeagueScreenState extends State<SubjectLeagueScreen> {
  final SubjectLeagueService _leagueService = SubjectLeagueService();
  String _selectedLeague = 'bronze';
  bool _checkingReset = true;
  Timer? _countdownTimer;
  Duration _timeLeft = Duration.zero;

  static const Map<String, Map<String, dynamic>> leagueMeta = {
    'bronze': {
      'name': 'الدوري البرونزي',
      'icon': '🥉',
      'color': Color(0xFFCD7F32),
      'glow': Color(0x33CD7F32),
    },
    'silver': {
      'name': 'الدوري الفضي',
      'icon': '🥈',
      'color': Color(0xFFC0C0C0),
      'glow': Color(0x33C0C0C0),
    },
    'gold': {
      'name': 'الدوري الذهبي',
      'icon': '🥇',
      'color': Color(0xFFFFD700),
      'glow': Color(0x33FFD700),
    },
    'diamond': {
      'name': 'الدوري الماسي',
      'icon': '💎',
      'color': Color(0xFF00E5FF),
      'glow': Color(0x3300E5FF),
    },
  };

  @override
  void initState() {
    super.initState();
    _runWeeklyResetCheck();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _runWeeklyResetCheck() async {
    final auth = context.read<AuthService>();
    final user = auth.user;
    if (user != null) {
      final name = user.displayName ?? user.email?.split('@').first ?? 'طالب';
      final avatar = user.photoURL;

      final resetResult = await _leagueService.checkAndApplyWeeklyReset(
        userId: user.uid,
        subjectId: widget.subjectId,
        userName: name,
        userAvatar: avatar,
      );

      if (resetResult != null && resetResult['reset'] == true) {
        final status = resetResult['status'];
        final oldL = resetResult['oldLeague'];
        final newL = resetResult['newLeague'];
        if (status == 'promoted') {
          _showPromotionDialog(oldL, newL);
        } else if (status == 'demoted') {
          _showDemotionDialog(oldL, newL);
        }
      }
    }
    setState(() => _checkingReset = false);
  }

  void _startCountdown() {
    _updateTimeLeft();
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {
          _updateTimeLeft();
        });
      }
    });
  }

  void _updateTimeLeft() {
    final now = DateTime.now();
    // Next Sunday start
    int daysToNextSunday = 7 - (now.weekday % 7);
    if (daysToNextSunday == 0) daysToNextSunday = 7;
    final nextSunday = DateTime(now.year, now.month, now.day).add(Duration(days: daysToNextSunday));
    _timeLeft = nextSunday.difference(now);
  }

  String _formatCountdown() {
    final days = _timeLeft.inDays;
    final hours = _timeLeft.inHours % 24;
    final minutes = _timeLeft.inMinutes % 60;
    if (days > 0) {
      return 'تبقي $days يوم و $hours ساعة';
    } else {
      return 'تبقي $hours ساعة و $minutes دقيقة';
    }
  }

  void _showPromotionDialog(String oldLeague, String newLeague) {
    HapticFeedback.heavyImpact();
    final meta = leagueMeta[newLeague]!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (context, val, child) {
          return Transform.scale(
            scale: val,
            child: AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🏆 ترقية جديدة! 🏆',
                    style: GoogleFonts.cairo(
                      color: const Color(0xFFFFD700),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: meta['color'].withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: meta['color'].withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: Center(
                      child: Text(
                        meta['icon'],
                        style: const TextStyle(fontSize: 50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'تهانينا! لقد صعدت إلى:',
                    style: GoogleFonts.cairo(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    meta['name'],
                    style: GoogleFonts.cairo(
                      color: meta['color'],
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'استمر بالدراسة وحل الكويزات لتصل للدوري الماسي!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: meta['color'],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      'رائع!',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDemotionDialog(String oldLeague, String newLeague) {
    HapticFeedback.vibrate();
    final meta = leagueMeta[newLeague]!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '⚠️ انتبه للتحدي!',
              style: GoogleFonts.cairo(
                color: const Color(0xFFEF4444),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: meta['color'].withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  meta['icon'],
                  style: const TextStyle(fontSize: 50),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'لقد تراجعت إلى:',
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 14),
            ),
            Text(
              meta['name'],
              style: GoogleFonts.cairo(
                color: meta['color'],
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لا تستسلم! أثبت جدارتك هذا الأسبوع واستعد لقبك!',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF334155),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                'سأفعل ذلك',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userId = context.read<AuthService>().user?.uid;

    if (_checkingReset || userId == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _leagueService.getUserLeagueInfoStream(userId, widget.subjectId),
      builder: (context, userLeagueSnap) {
        final userData = userLeagueSnap.data;
        final String activeLeague = userData?['league'] ?? 'bronze';
        
        // Auto-select active league on initial load
        if (userData != null && !userLeagueSnap.hasError && userLeagueSnap.connectionState == ConnectionState.active) {
          // Select users active league if they are placed in one
          // to make it smooth.
        }

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(activeLeague, isDark),
              SliverToBoxAdapter(
                child: _buildCountdownBanner(isDark),
              ),
              SliverToBoxAdapter(
                child: _buildLeagueSelector(activeLeague, isDark),
              ),
              _buildLeaderboardList(userId, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar(String activeLeague, bool isDark) {
    final currentMeta = leagueMeta[activeLeague]!;
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      currentMeta['color'].withValues(alpha: 0.15),
                      const Color(0xFF0F172A),
                    ]
                  : [
                      currentMeta['color'].withValues(alpha: 0.1),
                      const Color(0xFFF8FAFC),
                    ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: currentMeta['color'].withValues(alpha: 0.2),
                  boxShadow: [
                    BoxShadow(
                      color: currentMeta['color'].withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    currentMeta['icon'],
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'أنت في ${currentMeta['name']}',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                widget.subjectName,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildCountdownBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_rounded, color: Color(0xFFFB923C), size: 20),
          const SizedBox(width: 10),
          Text(
            'انتهاء الدوري:',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const Spacer(),
          Text(
            _formatCountdown(),
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: const Color(0xFFFB923C),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeagueSelector(String activeLeague, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: leagueMeta.entries.map((entry) {
          final key = entry.key;
          final meta = entry.value;
          final isSelected = _selectedLeague == key;
          final isActive = activeLeague == key;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedLeague = key);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? meta['color'].withValues(alpha: 0.15)
                    : isDark
                        ? const Color(0xFF1E293B)
                        : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? meta['color']
                      : isActive
                          ? meta['color'].withValues(alpha: 0.4)
                          : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: meta['color'].withValues(alpha: 0.2),
                          blurRadius: 10,
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Text(meta['icon'], style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    meta['name'],
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? meta['color']
                          : isDark
                              ? Colors.white70
                              : Colors.black87,
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: meta['color'],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLeaderboardList(String currentUserId, bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _leagueService.getLeaderboardStream(widget.subjectId, _selectedLeague),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
              child: Column(
                children: [
                  const Text('👻', style: TextStyle(fontSize: 50)),
                  const SizedBox(height: 16),
                  Text(
                    'لا يوجد متسابقون في هذا الدوري بعد!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: isDark ? Colors.white30 : Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'كن أول من يسجل نقاطًا دراسية هنا عن طريق حل الأسئلة!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: isDark ? Colors.white24 : Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final user = list[index];
                final userId = user['userId'] as String;
                final isMe = userId == currentUserId;
                final xp = user['weeklyXp'] as int;
                final name = user['userName'] as String;
                final avatar = user['userAvatar'] as String?;
                final rank = index + 1;

                // Determine Zone backgrounds
                Color? zoneBg;
                final isPromotion = rank <= 3 || rank <= (list.length * 0.25).ceil();
                final isDemotion = list.length > 5 && rank > (list.length * 0.8).floor();

                if (isPromotion) {
                  zoneBg = Colors.green.withValues(alpha: isDark ? 0.05 : 0.03);
                } else if (isDemotion) {
                  zoneBg = Colors.red.withValues(alpha: isDark ? 0.05 : 0.03);
                }

                // Me style
                if (isMe) {
                  zoneBg = leagueMeta[_selectedLeague]!['color'].withValues(alpha: 0.1);
                }

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: zoneBg ?? (isDark ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isMe
                          ? leagueMeta[_selectedLeague]!['color']
                          : isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey[200]!,
                      width: isMe ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildRankBadge(rank),
                        const SizedBox(width: 12),
                        _buildUserAvatar(name, avatar, isDark),
                      ],
                    ),
                    title: Text(
                      name,
                      style: GoogleFonts.cairo(
                        fontWeight: isMe ? FontWeight.w900 : FontWeight.bold,
                        fontSize: 14,
                        color: isMe
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    subtitle: isMe
                        ? Text(
                            'أنت',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: leagueMeta[_selectedLeague]!['color'],
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                    trailing: Text(
                      '$xp XP',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        color: isMe
                            ? leagueMeta[_selectedLeague]!['color']
                            : (isDark ? Colors.white60 : Colors.grey[700]),
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
              childCount: list.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) {
      return const Text('🥇', style: TextStyle(fontSize: 22));
    } else if (rank == 2) {
      return const Text('🥈', style: TextStyle(fontSize: 22));
    } else if (rank == 3) {
      return const Text('🥉', style: TextStyle(fontSize: 22));
    } else {
      return SizedBox(
        width: 24,
        child: Center(
          child: Text(
            rank.toString(),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildUserAvatar(String name, String? avatarUrl, bool isDark) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }

    final initial = name.isNotEmpty ? name.substring(0, 1) : '?';
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1),
            leagueMeta[_selectedLeague]!['color'] as Color,
          ],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
