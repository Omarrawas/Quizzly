import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';

class SalesLocationsScreen extends StatelessWidget {
  const SalesLocationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'أماكن بيع أكواد الرصيد',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('settings')
            .doc('sales_locations')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data =
              snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final List<dynamic> provincesRaw = data['provinces'] ?? [];

          // Parse provinces with new centers structure
          final provinces = provincesRaw.map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            final rawCenters = map['centers'] as List<dynamic>? ?? [];
            final centers = rawCenters
                .map((c) => Map<String, String>.from(
                    (c as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
                .toList();
            return {
              'name': map['name'] as String? ?? '',
              'centers': centers,
            };
          }).where((p) => (p['name'] as String).isNotEmpty).toList();

          if (provinces.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off_rounded,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد نقاط بيع مضافة حالياً',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          // Calculate counters dynamically from centers list
          final provincesCount = provinces.length;
          final totalCentersCount = provinces.fold<int>(
            0,
            (total, p) =>
                total + (p['centers'] as List).length,
          );

          return Column(
            children: [
              // ── Dynamic counters header ─────────────────────────
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Icon(Icons.map_rounded,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 28),
                          const SizedBox(height: 8),
                          Text(
                            'عدد المحافظات',
                            style: GoogleFonts.cairo(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$provincesCount',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 50,
                        color: Colors.white.withValues(alpha: 0.2)),
                    Expanded(
                      child: Column(
                        children: [
                          Icon(Icons.store_mall_directory_rounded,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 28),
                          const SizedBox(height: 8),
                          Text(
                            'المراكز المعتمدة',
                            style: GoogleFonts.cairo(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalCentersCount',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Provinces list ──────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 24),
                  itemCount: provinces.length,
                  itemBuilder: (context, index) {
                    final province = provinces[index];
                    final name = province['name'] as String;
                    final centers =
                        province['centers'] as List<Map<String, String>>;
                    final count = centers.length;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white10
                              : AppColors.borderLight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.2 : 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ExpansionTile(
                        backgroundColor: Colors.transparent,
                        collapsedBackgroundColor: Colors.transparent,
                        shape: const Border(),
                        iconColor: AppColors.primaryBlue,
                        collapsedIconColor: Colors.grey,
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.location_on_rounded,
                                color: AppColors.primaryBlue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              name,
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$count ${count == 1 ? 'مركز' : 'مراكز'}',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFF60A5FA)
                                  : AppColors.primaryBlue,
                            ),
                          ),
                        ),
                        children: [
                          if (centers.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'لا توجد مراكز مضافة لهذه المحافظة حالياً.',
                                style: GoogleFonts.cairo(
                                    color: Colors.grey, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            ...centers.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final center = entry.value;
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    20, 4, 20, 4),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // Number badge
                                    CircleAvatar(
                                      radius: 13,
                                      backgroundColor: AppColors.primaryBlue
                                          .withValues(alpha: 0.12),
                                      child: Text(
                                        '${idx + 1}',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryBlue,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            center['name'] ?? '',
                                            style: GoogleFonts.cairo(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: isDark
                                                  ? Colors.white
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                          if ((center['address'] ?? '')
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(
                                                    Icons
                                                        .location_on_outlined,
                                                    size: 13,
                                                    color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    center['address'] ?? '',
                                                    style: GoogleFonts.cairo(
                                                      fontSize: 12,
                                                      color: isDark
                                                          ? Colors.white54
                                                          : Colors.black54,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          const Divider(height: 16),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
