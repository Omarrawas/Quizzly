import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/presentation/screens/edit_user_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  Future<void> _updateRole(String uid, String newRole) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'role': newRole,
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث الصلاحية بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  Future<void> _clearDeviceSession(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'deviceId': FieldValue.delete(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء جلسة الجهاز بنجاح. يمكن للطالب الدخول من جهاز جديد.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('إدارة المستخدمين', style: GoogleFonts.cairo()),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: Column(
        children: [
          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث بالبريد الإلكتروني...',
                hintStyle: GoogleFonts.cairo(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search, color: AppColors.primaryBlue),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                ),
              ),
            ),
          ),

          // ── Users List ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('لا يوجد مستخدمون.', style: GoogleFonts.cairo()),
                  );
                }

                final docs = snapshot.data!.docs;
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return email.contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text('لم يتم العثور على نتائج.', style: GoogleFonts.cairo()),
                  );
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final email = data['email'] ?? 'بدون إيميل';
                    final role = data['role'] ?? 'user';
                    final hasDevice = data.containsKey('deviceId') && data['deviceId'] != null;

                    return Card(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Email & Device Status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['defaults']?['fullName'] ?? email,
                                        style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (data['defaults']?['fullName'] != null)
                                        Text(
                                          email,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                          textDirection: TextDirection.ltr,
                                        ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EditUserScreen(uid: doc.id, userData: data),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.edit_note_rounded, color: AppColors.primaryBlue),
                                      tooltip: 'تعديل البيانات',
                                    ),
                                    if (hasDevice)
                                      const Tooltip(
                                        message: 'جهاز مرتبط',
                                        child: Icon(Icons.phonelink_lock, color: Colors.green, size: 20),
                                      )
                                    else
                                      const Tooltip(
                                        message: 'غير مرتبط بجهاز',
                                        child: Icon(Icons.phonelink_erase, color: Colors.grey, size: 20),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Actions
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Role Dropdown
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: (role == 'admin' || role == 'teacher' || role == 'user') ? role : (role == 'super_admin' || role == 'superAdmin' ? 'admin' : 'user'),
                                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      style: GoogleFonts.cairo(
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'user', child: Text('طالب')),
                                        DropdownMenuItem(value: 'teacher', child: Text('معلم')),
                                        DropdownMenuItem(value: 'admin', child: Text('أدمن')),
                                      ],
                                      onChanged: (val) {
                                        if (val != null && val != role) {
                                          _updateRole(doc.id, val);
                                        }
                                      },
                                    ),
                                  ),
                                ),

                                // Clear Session Button
                                ElevatedButton.icon(
                                  onPressed: hasDevice ? () => _clearDeviceSession(doc.id) : null,
                                  icon: const Icon(Icons.phonelink_erase_rounded, size: 18),
                                  label: Text(
                                    'إلغاء الارتباط',
                                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                                    foregroundColor: Colors.redAccent,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(color: Colors.redAccent),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          ),
        ],
      ),
    );
  }
}
