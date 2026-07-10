import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';

const List<String> kSyrianGovernorates = [
  'دمشق',
  'ريف دمشق',
  'حلب',
  'حمص',
  'حماة',
  'اللاذقية',
  'طرطوس',
  'إدلب',
  'دير الزور',
  'الرقة',
  'الحسكة',
  'القنيطرة',
  'السويداء',
  'درعا',
];

class ManageSalesLocationsScreen extends StatefulWidget {
  const ManageSalesLocationsScreen({super.key});

  @override
  State<ManageSalesLocationsScreen> createState() =>
      _ManageSalesLocationsScreenState();
}

class _ManageSalesLocationsScreenState
    extends State<ManageSalesLocationsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isSaving = false;

  // Key: governorate name, Value: list of centers [{name, address}]
  Map<String, List<Map<String, String>>> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc =
          await _db.collection('settings').doc('sales_locations').get();
      if (doc.exists) {
        final raw = doc.data()?['provinces'] as List<dynamic>? ?? [];
        final Map<String, List<Map<String, String>>> loaded = {};
        for (final item in raw) {
          final govName = item['name'] as String? ?? '';
          final centers = (item['centers'] as List<dynamic>? ?? [])
              .map((c) => {
                    'name': (c['name'] as String? ?? ''),
                    'address': (c['address'] as String? ?? ''),
                  })
              .toList();
          if (govName.isNotEmpty) loaded[govName] = centers;
        }
        setState(() => _data = loaded);
      }
    } catch (e) {
      debugPrint('Error loading: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final provinces = _data.entries.map((e) {
        return {
          'name': e.key,
          'centers': e.value
              .map((c) => {'name': c['name'], 'address': c['address']})
              .toList(),
        };
      }).toList();

      await _db.collection('settings').doc('sales_locations').set({
        'provinces': provinces,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تم الحفظ بنجاح ✅', style: GoogleFonts.cairo()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('فشل الحفظ: $e', style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showAddGovernorateDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alreadyAdded = _data.keys.toSet();
    final available =
        kSyrianGovernorates.where((g) => !alreadyAdded.contains(g)).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تم إضافة جميع المحافظات', style: GoogleFonts.cairo()),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    String selected = available.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF131A26) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'اختر المحافظة',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF080C14) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
                width: 1,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selected,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF131A26) : Colors.white,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDark ? Colors.white70 : AppColors.primaryBlue,
                ),
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
                items: available
                    .map((g) => DropdownMenuItem(
                          value: g,
                          child: Text(
                            g,
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selected = v);
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _data[selected] = []);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('إضافة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCenterDialog(String governorate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131A26) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'إضافة مركز — $governorate',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: GoogleFonts.cairo(fontSize: 14),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: 'اسم المركز',
                labelStyle: GoogleFonts.cairo(),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.store_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: addressCtrl,
              style: GoogleFonts.cairo(fontSize: 14),
              textAlign: TextAlign.right,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'عنوان المركز',
                labelStyle: GoogleFonts.cairo(),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.location_on_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final address = addressCtrl.text.trim();
              if (name.isEmpty) return;
              setState(() {
                _data[governorate]!
                    .add({'name': name, 'address': address});
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _editCenter(String governorate, int idx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final center = _data[governorate]![idx];
    final nameCtrl = TextEditingController(text: center['name']);
    final addressCtrl = TextEditingController(text: center['address']);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131A26) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'تعديل مركز — $governorate',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: GoogleFonts.cairo(fontSize: 14),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: 'اسم المركز',
                labelStyle: GoogleFonts.cairo(),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.store_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: addressCtrl,
              style: GoogleFonts.cairo(fontSize: 14),
              textAlign: TextAlign.right,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'عنوان المركز',
                labelStyle: GoogleFonts.cairo(),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.location_on_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final address = addressCtrl.text.trim();
              if (name.isEmpty) return;
              setState(() {
                _data[governorate]![idx] = {'name': name, 'address': address};
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF080C14) : const Color(0xFFE5E2DA),
      appBar: AppBar(
        title: Text('إدارة نقاط البيع',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded),
            tooltip: 'إضافة محافظة',
            onPressed: _showAddGovernorateDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Summary chip ──────────────────────────────────
                if (_data.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(children: [
                            Text(
                              '${_data.length}',
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900),
                            ),
                            Text('محافظة',
                                style: GoogleFonts.cairo(
                                    color: Colors.white70, fontSize: 12)),
                          ]),
                          Container(
                              width: 1,
                              height: 36,
                              color: Colors.white24),
                          Column(children: [
                            Text(
                              '${_data.values.fold(0, (s, l) => s + l.length)}',
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900),
                            ),
                            Text('مركز',
                                style: GoogleFonts.cairo(
                                    color: Colors.white70, fontSize: 12)),
                          ]),
                        ],
                      ),
                    ),
                  ),
                // ── List ──────────────────────────────────────────
                Expanded(
                  child: _data.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_location_alt_rounded,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text('اضغط + لإضافة محافظة',
                                  style: GoogleFonts.cairo(
                                      color: Colors.grey, fontSize: 15)),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: _data.entries.map((entry) {
                            final govName = entry.key;
                            final centers = entry.value;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF131A26)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: isDark
                                        ? Colors.white10
                                        : AppColors.borderLight),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                        alpha: isDark ? 0.2 : 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Governorate header
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 14, 8, 0),
                                    child: Row(
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
                                              size: 18),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            govName,
                                            style: GoogleFonts.cairo(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: isDark
                                                  ? Colors.white
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        // Badge count
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryBlue
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${centers.length} مراكز',
                                            style: GoogleFonts.cairo(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryBlue,
                                            ),
                                          ),
                                        ),
                                        // Delete governorate
                                        IconButton(
                                          icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Colors.red,
                                              size: 20),
                                          onPressed: () => setState(
                                              () => _data.remove(govName)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 12, indent: 16, endIndent: 16),
                                  // Centers list
                                  ...centers.asMap().entries.map((ce) {
                                    final idx = ce.key;
                                    final center = ce.value;
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 0, 16, 8),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundColor: AppColors
                                                .primaryBlue
                                                .withValues(alpha: 0.12),
                                            child: Text('${idx + 1}',
                                                style: GoogleFonts.inter(
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color: AppColors
                                                        .primaryBlue)),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(center['name'] ?? '',
                                                    style: GoogleFonts.cairo(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 13,
                                                        color: isDark
                                                            ? Colors.white
                                                            : AppColors
                                                                .textPrimary)),
                                                if ((center['address'] ?? '')
                                                    .isNotEmpty)
                                                  Text(center['address'] ?? '',
                                                      style: GoogleFonts.cairo(
                                                          fontSize: 11,
                                                          color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.edit_rounded,
                                                color: Colors.blue,
                                                size: 18),
                                            onPressed: () =>
                                                _editCenter(govName, idx),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.remove_circle_outline,
                                                color: Colors.red,
                                                size: 18),
                                            onPressed: () => setState(() =>
                                                _data[govName]!.removeAt(idx)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  // Add center button
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 14),
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _showAddCenterDialog(govName),
                                      icon: const Icon(Icons.add_rounded,
                                          size: 18),
                                      label: Text('إضافة مركز',
                                          style:
                                              GoogleFonts.cairo(fontSize: 13)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primaryBlue,
                                        side: BorderSide(
                                            color: AppColors.primaryBlue
                                                .withValues(alpha: 0.4)),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
                // ── Save button ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : Text('تأكيد وحفظ التغييرات',
                              style: GoogleFonts.cairo(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
