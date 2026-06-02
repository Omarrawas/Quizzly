import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:flutter/services.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _searchQuery = '';
  String _selectedRoleFilter = 'all'; // 'all', 'admin', 'teacher', 'user'
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
        title: Text('إدارة المستخدمين', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
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

          final allDocs = snapshot.data!.docs;
          
          // Calculate Counts
          final totalCount = allDocs.length;
          final adminCount = allDocs.where((doc) {
            final r = (doc.data() as Map<String, dynamic>)['role']?.toString().toLowerCase() ?? 'user';
            return r == 'admin' || r == 'super_admin' || r == 'superadmin';
          }).length;
          final teacherCount = allDocs.where((doc) => (doc.data() as Map<String, dynamic>)['role'] == 'teacher').length;
          final userCount = allDocs.where((doc) => (doc.data() as Map<String, dynamic>)['role'] == 'user' || (doc.data() as Map<String, dynamic>)['role'] == null).length;

          // Apply Filters for displaying the list
          final filteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            
            // Role Filter logic
            final role = (data['role'] ?? 'user').toString().toLowerCase();
            bool matchesRole = false;
            if (_selectedRoleFilter == 'all') {
              matchesRole = true;
            } else if (_selectedRoleFilter == 'admin') {
              matchesRole = role == 'admin' || role == 'super_admin' || role == 'superadmin';
            } else {
              matchesRole = role == _selectedRoleFilter;
            }
            
            if (!matchesRole) return false;

            // Search Filter logic
            final email = (data['email'] ?? '').toString().toLowerCase();
            final fullName = (data['defaults']?['fullName'] ?? '').toString().toLowerCase();
            final phone = (data['defaults']?['phoneNumber'] ?? '').toString().toLowerCase();
            final uid = doc.id.toLowerCase();
            final deviceId = (data['deviceId'] ?? '').toString().toLowerCase();
            final deviceModel = (data['deviceModel'] ?? '').toString().toLowerCase();
            final deviceName = (data['deviceName'] ?? '').toString().toLowerCase();
            
            return email.contains(_searchQuery) || 
                   fullName.contains(_searchQuery) || 
                   phone.contains(_searchQuery) || 
                   uid.contains(_searchQuery) ||
                   deviceId.contains(_searchQuery) ||
                   deviceModel.contains(_searchQuery) ||
                   deviceName.contains(_searchQuery);
          }).toList();

          return Column(
            children: [
              // ── Search & Filter Section ──
              Container(
                padding: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.appBarTheme.backgroundColor,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim().toLowerCase();
                          });
                        },
                        textDirection: TextDirection.rtl,
                        style: GoogleFonts.cairo(),
                        decoration: InputDecoration(
                          hintText: 'ابحث بالاسم، الإيميل، الهاتف، أو معرّف الجهاز...',
                          hintStyle: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize: 13),
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
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Role Filters
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _buildFilterChip('الكل', 'all', totalCount, isDark),
                          const SizedBox(width: 8),
                          _buildFilterChip('أدمن', 'admin', adminCount, isDark),
                          const SizedBox(width: 8),
                          _buildFilterChip('معلم', 'teacher', teacherCount, isDark),
                          const SizedBox(width: 8),
                          _buildFilterChip('طلاب', 'user', userCount, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Users List ──
              Expanded(
                child: filteredDocs.isEmpty 
                  ? Center(child: Text('لم يتم العثور على نتائج.', style: GoogleFonts.cairo()))
                  : ListView.builder(
                      itemCount: filteredDocs.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final email = data['email'] ?? 'بدون إيميل';
                        final role = data['role'] ?? 'user';
                        final hasDevice = data.containsKey('deviceId') && data['deviceId'] != null;
                        final defaults = data['defaults'] as Map<String, dynamic>? ?? {};

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.1),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Theme(
                              data: theme.copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(role).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getRoleIcon(role),
                                    color: _getRoleColor(role),
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  defaults['fullName'] ?? email.split('@')[0],
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Row(
                                  children: [
                                    const Icon(Icons.email_outlined, size: 12, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        email,
                                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                                        textDirection: TextDirection.ltr,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: hasDevice ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    hasDevice ? Icons.phonelink_lock : Icons.phonelink_erase,
                                    color: hasDevice ? Colors.green : Colors.grey,
                                    size: 18,
                                  ),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 8.0),
                                          child: Divider(height: 1),
                                        ),
                                        
                                        _buildInfoSectionTitle('معلومات الاتصال والحساب', isDark),
                                        _buildDetailRow(Icons.phone_android, 'رقم الهاتف', defaults['phoneNumber'] ?? 'غير متوفر', isDark),
                                        _buildDetailRow(Icons.fingerprint, 'معرّف المستخدم (UID)', doc.id, isDark, isLtr: true, showCopy: true),
                                        
                                        const SizedBox(height: 12),
                                        
                                        _buildInfoSectionTitle('المعلومات الدراسية', isDark),
                                        _buildDetailRow(Icons.account_balance, 'الجامعة', defaults['universityName'] ?? 'غير متوفر', isDark),
                                        _buildDetailRow(Icons.school, 'الكلية', defaults['collegeName'] ?? 'غير متوفر', isDark),
                                        _buildDetailRow(Icons.category, 'القسم', defaults['departmentName'] ?? 'غير متوفر', isDark),
                                        _buildDetailRow(Icons.calendar_today, 'السنة', defaults['yearName'] ?? 'غير متوفر', isDark),

                                        const SizedBox(height: 12),

                                        _buildInfoSectionTitle('معلومات الجهاز', isDark),
                                        _buildDetailRow(Icons.devices, 'نوع الجهاز', '${data['brand'] ?? ''} ${data['deviceModel'] ?? ''}'.trim().isEmpty ? 'غير متوفر' : '${data['brand'] ?? ''} ${data['deviceModel'] ?? ''}', isDark),
                                        _buildDetailRow(Icons.settings_suggest, 'نظام التشغيل', data['system'] ?? (data['deviceVersion'] ?? 'غير متوفر'), isDark, isLtr: true),
                                        _buildDetailRow(Icons.adb, 'نسخة التطبيق', data['appVersion'] ?? 'غير متوفر', isDark, isLtr: true),
                                        _buildDetailRow(Icons.phonelink_lock, 'معرف الارتباط', data['deviceId'] ?? 'غير مرتبط', isDark, isLtr: true, showCopy: data['deviceId'] != null),
                                        
                                        const SizedBox(height: 20),
                                        
                                        Text('إجراءات الإدارة:', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.1)),
                                                ),
                                                child: DropdownButtonHideUnderline(
                                                  child: DropdownButton<String>(
                                                    isExpanded: true,
                                                    value: (role == 'admin' || role == 'teacher' || role == 'user') ? role : (role == 'super_admin' || role == 'superAdmin' ? 'admin' : 'user'),
                                                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                                    icon: const Icon(Icons.arrow_drop_down_circle_outlined, size: 20, color: AppColors.primaryBlue),
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
                                            ),
                                            const SizedBox(width: 12),
                                            ElevatedButton.icon(
                                              onPressed: hasDevice ? () => _clearDeviceSession(doc.id) : null,
                                              icon: const Icon(Icons.phonelink_erase_rounded, size: 18),
                                              label: Text('إلغاء الارتباط', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                                                foregroundColor: Colors.redAccent,
                                                elevation: 0,
                                                minimumSize: const Size(0, 48),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

  Widget _buildFilterChip(String label, String value, int count, bool isDark) {
    bool isSelected = _selectedRoleFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedRoleFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primaryBlue 
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? AppColors.primaryBlue 
                : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.cairo(
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.2) : AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                count.toString(),
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryBlue.withValues(alpha: 0.7),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark, {bool isLtr = false, bool showCopy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: isDark ? Colors.white38 : Colors.grey),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: GoogleFonts.cairo(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
          ),
          Expanded(
            child: Text(
              value,
              style: isLtr 
                  ? GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87) 
                  : GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
              textAlign: isLtr ? TextAlign.left : TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showCopy && value != 'غير مرتبط' && value != 'غير متوفر')
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم النسخ إلى الحافظة'), duration: Duration(seconds: 1)),
                  );
                },
                child: Icon(Icons.copy_rounded, size: 14, color: AppColors.primaryBlue.withValues(alpha: 0.6)),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getRoleIcon(String role) {
    role = role.toLowerCase();
    if (role == 'admin' || role == 'super_admin' || role == 'superadmin') return Icons.admin_panel_settings_rounded;
    if (role == 'teacher') return Icons.school_rounded;
    return Icons.person_rounded;
  }

  Color _getRoleColor(String role) {
    role = role.toLowerCase();
    if (role == 'admin' || role == 'super_admin' || role == 'superadmin') return Colors.orange;
    if (role == 'teacher') return AppColors.primaryBlue;
    return Colors.teal;
  }
}
