import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';

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
  List<Map<String, dynamic>> _provinces = [];

  @override
  void initState() {
    super.initState();
    _loadSalesLocations();
  }

  Future<void> _loadSalesLocations() async {
    try {
      final doc = await _db.collection('settings').doc('sales_locations').get();
      if (doc.exists) {
        final data = doc.data()!;
        final List<dynamic> listRaw = data['provinces'] ?? [];
        setState(() {
          _provinces = listRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading sales locations: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSalesLocations() async {
    setState(() => _isSaving = true);
    try {
      await _db.collection('settings').doc('sales_locations').set({
        'provinces': _provinces,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم حفظ نقاط البيع بنجاح',
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
            content: Text('فشل الحفظ: $e', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showAddEditProvinceDialog({int? index}) {
    final isEdit = index != null;
    final province = isEdit ? _provinces[index] : null;

    final nameController = TextEditingController(text: province?['name'] ?? '');
    final countController = TextEditingController(
      text: province?['centersCount']?.toString() ?? '1',
    );
    final detailsController = TextEditingController(
      text: province?['details'] ?? '',
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          isEdit ? 'تعديل محافظة' : 'إضافة محافظة جديدة',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                style: GoogleFonts.cairo(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'اسم المحافظة',
                  labelStyle: GoogleFonts.cairo(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: countController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'عدد المراكز المعتمدة',
                  labelStyle: GoogleFonts.cairo(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: detailsController,
                maxLines: 5,
                style: GoogleFonts.cairo(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'تفاصيل المراكز بالأسفل (الترقيم تلقائي أو يدوي)',
                  labelStyle: GoogleFonts.cairo(),
                  hintText:
                      'مثال:\n١. مكتبة الرائد - البرامكة\n٢. مكتبة الهدى - الحلبوني',
                  hintStyle: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final count = int.tryParse(countController.text.trim()) ?? 0;
              final details = detailsController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الرجاء إدخال اسم المحافظة')),
                );
                return;
              }

              setState(() {
                if (isEdit) {
                  _provinces[index] = {
                    'name': name,
                    'centersCount': count,
                    'details': details,
                  };
                } else {
                  _provinces.add({
                    'name': name,
                    'centersCount': count,
                    'details': details,
                  });
                }
              });

              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'حفظ',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteProvince(int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final province = _provinces[index];
    final name = province['name'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'تأكيد الحذف',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'هل أنت متأكد من حذف محافظة "$name"؟',
          style: GoogleFonts.cairo(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _provinces.removeAt(index);
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم حذف "$name" بنجاح',
                    style: GoogleFonts.cairo(),
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'حذف',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'إدارة نقاط وأماكن البيع',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => _showAddEditProvinceDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _provinces.isEmpty
                      ? Center(
                          child: Text(
                            'لا توجد محافظات مضافة حالياً. اضغط على + لإضافة واحدة.',
                            style: GoogleFonts.cairo(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _provinces.length,
                          itemBuilder: (context, index) {
                            final province = _provinces[index];
                            final name = province['name'] ?? '';
                            final count = province['centersCount'] ?? 0;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.white10
                                      : AppColors.borderLight,
                                ),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  Icons.location_on_rounded,
                                  color: AppColors.primaryBlue,
                                ),
                                title: Text(
                                  name,
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  '$count مراكز معتمدة',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_rounded,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () =>
                                          _showAddEditProvinceDialog(
                                            index: index,
                                          ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _deleteProvince(index),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSalesLocations,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'تأكيد وحفظ التغييرات في السحابة',
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
