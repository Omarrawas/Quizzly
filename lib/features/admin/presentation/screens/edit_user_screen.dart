import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/home/domain/services/content_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class EditUserScreen extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> userData;

  const EditUserScreen({
    super.key,
    required this.uid,
    required this.userData,
  });

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  String? _selectedUniversityId;
  String? _selectedCollegeId;
  String? _selectedDepartmentId;
  String? _selectedYearId;

  String _universityName = '';
  String _collegeName = '';
  String _departmentName = '';
  String _yearName = '';

  bool _isLoading = false;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    final defaults = widget.userData['defaults'] as Map<String, dynamic>? ?? {};
    _nameController = TextEditingController(text: defaults['fullName'] ?? '');
    _phoneController = TextEditingController(text: defaults['phoneNumber'] ?? '');
    
    _selectedUniversityId = defaults['universityId'];
    _selectedCollegeId = defaults['collegeId'];
    _selectedDepartmentId = defaults['departmentId'];
    _selectedYearId = defaults['yearId'];

    _universityName = defaults['universityName'] ?? '';
    _collegeName = defaults['collegeName'] ?? '';
    _departmentName = defaults['departmentName'] ?? '';
    _yearName = defaults['yearName'] ?? '';
    _deviceId = widget.userData['deviceId'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final data = {
        'defaults.fullName': _nameController.text.trim(),
        'defaults.phoneNumber': _phoneController.text.trim(),
        'defaults.universityId': _selectedUniversityId,
        'defaults.universityName': _universityName,
        'defaults.collegeId': _selectedCollegeId,
        'defaults.collegeName': _collegeName,
        'defaults.departmentId': _selectedDepartmentId,
        'defaults.departmentName': _departmentName,
        'defaults.yearId': _selectedYearId,
        'defaults.yearName': _yearName,
      };

      await FirebaseFirestore.instance.collection('users').doc(widget.uid).set(
        data,
        SetOptions(merge: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث بيانات المستخدم بنجاح ✅')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentService = context.read<ContentService>();

    final email = widget.userData['email'] as String? ?? 'بدون بريد إلكتروني';
    final role = widget.userData['role'] as String? ?? 'user';

    final platform = widget.userData['platform'] as String? ?? widget.userData['deviceOS'] as String? ?? 'غير معروف';
    final deviceName = widget.userData['deviceName'] as String? ?? 'غير معروف';
    final deviceModel = widget.userData['deviceModel'] as String? ?? 'غير معروف';
    final brand = widget.userData['brand'] as String? ?? '';
    final system = widget.userData['system'] as String? ?? widget.userData['deviceVersion'] as String? ?? 'غير معروف';
    final appVersion = widget.userData['appVersion'] as String? ?? 'غير معروف';
    final uniqueId = widget.userData['uniqueId'] as String? ?? widget.userData['androidId'] as String? ?? 'غير متوفر';
    final lastLoginStamp = widget.userData['lastLogin'] as Timestamp?;

    IconData platformIcon = Icons.device_unknown_rounded;
    Color platformColor = Colors.grey;
    String platformText = 'غير معروف';

    if (platform.toLowerCase() == 'android') {
      platformIcon = Icons.android_rounded;
      platformColor = Colors.green;
      platformText = 'أندرويد';
    } else if (platform.toLowerCase() == 'ios') {
      platformIcon = Icons.apple_rounded;
      platformColor = isDark ? Colors.white : Colors.black87;
      platformText = 'آي أو إس (iOS)';
    } else if (platform.toLowerCase() == 'windows') {
      platformIcon = Icons.laptop_windows_rounded;
      platformColor = Colors.blue;
      platformText = 'ويندوز';
    } else if (platform.toLowerCase() == 'web') {
      platformIcon = Icons.language_rounded;
      platformColor = Colors.teal;
      platformText = 'متصفح ويب';
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('تعديل بيانات المستخدم', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('المعلومات الأساسية', isDark),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _nameController,
                    label: 'الاسم الكامل',
                    icon: Icons.person_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'رقم الهاتف',
                    icon: Icons.phone_rounded,
                    isDark: isDark,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle('التخصص الدراسي', isDark),
                  const SizedBox(height: 16),
                  
                  // University
                  _buildSelectionTile(
                    label: 'الجامعة',
                    value: _universityName.isEmpty ? 'اختر الجامعة' : _universityName,
                    icon: Icons.account_balance_rounded,
                    onTap: () => _showHierarchyPicker(
                      title: 'اختر الجامعة',
                      stream: contentService.getUniversities(),
                      onSelected: (doc) {
                        setState(() {
                          _selectedUniversityId = doc.id;
                          _universityName = doc['name'];
                          // Reset children
                          _selectedCollegeId = null;
                          _collegeName = '';
                          _selectedDepartmentId = null;
                          _departmentName = '';
                          _selectedYearId = null;
                          _yearName = '';
                        });
                      },
                      isDark: isDark,
                    ),
                    isDark: isDark,
                  ),
                  
                  // College
                  if (_selectedUniversityId != null) ...[
                    const SizedBox(height: 12),
                    _buildSelectionTile(
                      label: 'الكلية',
                      value: _collegeName.isEmpty ? 'اختر الكلية' : _collegeName,
                      icon: Icons.school_rounded,
                      onTap: () => _showHierarchyPicker(
                        title: 'اختر الكلية',
                        stream: contentService.getColleges(_selectedUniversityId!),
                        onSelected: (doc) {
                          setState(() {
                            _selectedCollegeId = doc.id;
                            _collegeName = doc['name'];
                            // Reset children
                            _selectedDepartmentId = null;
                            _departmentName = '';
                            _selectedYearId = null;
                            _yearName = '';
                          });
                        },
                        isDark: isDark,
                      ),
                      isDark: isDark,
                    ),
                  ],

                  // Department
                  if (_selectedCollegeId != null) ...[
                    const SizedBox(height: 12),
                    _buildSelectionTile(
                      label: 'القسم / التخصص',
                      value: _departmentName.isEmpty ? 'اختر القسم' : _departmentName,
                      icon: Icons.category_rounded,
                      onTap: () => _showHierarchyPicker(
                        title: 'اختر القسم',
                        stream: contentService.getDepartments(_selectedCollegeId!),
                        onSelected: (doc) {
                          setState(() {
                            _selectedDepartmentId = doc.id;
                            _departmentName = doc['name'];
                            // Reset children
                            _selectedYearId = null;
                            _yearName = '';
                          });
                        },
                        isDark: isDark,
                      ),
                      isDark: isDark,
                    ),
                  ],

                  // Year
                  if (_selectedDepartmentId != null) ...[
                    const SizedBox(height: 12),
                    _buildSelectionTile(
                      label: 'السنة الدراسية',
                      value: _yearName.isEmpty ? 'اختر السنة' : _yearName,
                      icon: Icons.calendar_today_rounded,
                      onTap: () => _showHierarchyPicker(
                        title: 'اختر السنة',
                        stream: contentService.getYears(_selectedDepartmentId!),
                        onSelected: (doc) {
                          setState(() {
                            _selectedYearId = doc.id;
                            _yearName = doc['name'];
                          });
                        },
                        isDark: isDark,
                      ),
                      isDark: isDark,
                    ),
                  ],

                  // Divider and Spacing
                  const SizedBox(height: 32),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 24),

                  // Account Information Section
                  _buildSectionTitle('معلومات الحساب', isDark),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          icon: Icons.fingerprint_rounded,
                          label: 'معرّف المستخدم (UID)',
                          value: widget.uid,
                          isDark: isDark,
                          isLtr: true,
                          onCopy: () {
                            Clipboard.setData(ClipboardData(text: widget.uid));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم نسخ المعرّف (UID) بنجاح 📋')),
                            );
                          },
                        ),
                        const Divider(height: 24, color: Colors.white10),
                        _buildInfoRow(
                          icon: Icons.email_rounded,
                          label: 'البريد الإلكتروني',
                          value: email,
                          isDark: isDark,
                          isLtr: true,
                          onCopy: widget.userData['email'] != null 
                              ? () {
                                  Clipboard.setData(ClipboardData(text: email));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تم نسخ البريد الإلكتروني بنجاح 📋')),
                                  );
                                }
                              : null,
                        ),
                        const Divider(height: 24, color: Colors.white10),
                        _buildInfoRow(
                          icon: Icons.admin_panel_settings_rounded,
                          label: 'نوع الحساب / الصلاحية',
                          value: role == 'admin' || role == 'super_admin' ? 'أدمن' : 'طالب',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Device & Activity Information Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('معلومات الجهاز والنشاط', isDark),
                      _buildStatusBadge(_deviceId != null && _deviceId!.isNotEmpty),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Platform (with custom icon & badge)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Icon(platformIcon, size: 22, color: platformColor),
                              const SizedBox(width: 12),
                              Text(
                                'نظام التشغيل / المنصة',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  color: isDark ? Colors.white60 : Colors.grey[700],
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: platformColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: platformColor.withValues(alpha: 0.3), width: 1),
                                ),
                                child: Text(
                                  platformText,
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: platformColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 24, color: Colors.white10),
                        
                        _buildInfoRow(
                          icon: Icons.phone_android_rounded,
                          label: 'اسم ونوع الجهاز',
                          value: brand.isNotEmpty ? '$brand $deviceModel ($deviceName)' : '$deviceModel ($deviceName)',
                          isDark: isDark,
                        ),
                        const Divider(height: 24, color: Colors.white10),
                        
                        _buildInfoRow(
                          icon: Icons.settings_suggest_rounded,
                          label: 'إصدار النظام',
                          value: system,
                          isDark: isDark,
                          isLtr: true,
                        ),
                        const Divider(height: 24, color: Colors.white10),
                        
                        _buildInfoRow(
                          icon: Icons.perm_device_information_rounded,
                          label: 'معرّف الجهاز الفريد (Hardware ID)',
                          value: uniqueId,
                          isDark: isDark,
                          isLtr: true,
                          onCopy: uniqueId != 'غير متوفر' 
                              ? () {
                                  Clipboard.setData(ClipboardData(text: uniqueId));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تم نسخ معرّف الجهاز الفريد 📋')),
                                  );
                                }
                              : null,
                        ),
                        const Divider(height: 24, color: Colors.white10),
                        
                        _buildInfoRow(
                          icon: Icons.adb_rounded,
                          label: 'نسخة التطبيق الحالية',
                          value: appVersion,
                          isDark: isDark,
                          isLtr: true,
                        ),
                        const Divider(height: 24, color: Colors.white10),
                        
                        _buildInfoRow(
                          icon: Icons.history_toggle_off_rounded,
                          label: 'آخر تسجيل دخول نشط',
                          value: _formatTimestamp(lastLoginStamp),
                          isDark: isDark,
                        ),
                        const Divider(height: 24, color: Colors.white10),

                        _buildInfoRow(
                          icon: Icons.phonelink_lock_rounded,
                          label: 'معرّف الارتباط النشط (Binding UUID)',
                          value: _deviceId ?? 'غير مرتبط بجهاز',
                          isDark: isDark,
                          isLtr: _deviceId != null,
                          onCopy: _deviceId != null
                              ? () {
                                  Clipboard.setData(ClipboardData(text: _deviceId!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تم نسخ معرّف الارتباط النشط 📋')),
                                  );
                                }
                              : null,
                        ),

                        if (_deviceId != null) ...[
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _clearDeviceSession,
                              icon: const Icon(Icons.phonelink_erase_rounded, size: 18),
                              label: Text(
                                'إلغاء ارتباط هذا الجهاز',
                                style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent, width: 1.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        'حفظ التغييرات',
                        style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.cairo(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textAlign: TextAlign.right,
      style: GoogleFonts.cairo(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(color: isDark ? Colors.white60 : Colors.grey),
        prefixIcon: Icon(icon, color: AppColors.primaryBlue),
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
    );
  }

  Widget _buildSelectionTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryBlue, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_drop_down_rounded, color: isDark ? Colors.white38 : Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showHierarchyPicker({
    required String title,
    required Stream<QuerySnapshot> stream,
    required Function(QueryDocumentSnapshot) onSelected,
    required bool isDark,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              title,
              style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return ListTile(
                      title: Text(
                        doc['name'],
                        style: GoogleFonts.cairo(),
                        textAlign: TextAlign.center,
                      ),
                      onTap: () {
                        onSelected(doc);
                        Navigator.pop(context);
                      },
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

  Widget _buildStatusBadge(bool hasDevice) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: hasDevice 
            ? Colors.green.withValues(alpha: 0.15) 
            : Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: hasDevice 
              ? Colors.green.withValues(alpha: 0.5) 
              : Colors.amber.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: hasDevice ? Colors.green : Colors.amber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            hasDevice ? 'حساب مرتبط بجهاز' : 'غير مرتبط بجهاز',
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: hasDevice ? Colors.green[300] ?? Colors.green : Colors.amber[300] ?? Colors.amber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    bool isLtr = false,
    VoidCallback? onCopy,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.grey[700],
            ),
          ),
          const Spacer(),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: isLtr 
                        ? GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          )
                        : GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                    textAlign: TextAlign.left,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onCopy != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primaryBlue),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onCopy,
                    tooltip: 'نسخ',
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'غير متوفر';
    final DateTime dateTime = timestamp.toDate();
    final DateFormat formatter = DateFormat('yyyy/MM/dd - hh:mm a');
    return formatter.format(dateTime);
  }

  Future<void> _clearDeviceSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'تأكيد إلغاء الارتباط',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          textAlign: TextAlign.right,
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في إلغاء ارتباط هذا الحساب بالجهاز الحالي؟ سيتمكن الطالب من تسجيل الدخول من جهاز آخر.',
          style: GoogleFonts.cairo(),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('نعم، إلغاء الارتباط', style: GoogleFonts.cairo(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
        'deviceId': FieldValue.delete(),
      }, SetOptions(merge: true));

      setState(() {
        _deviceId = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء ارتباط الجهاز بنجاح ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء إلغاء الارتباط: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
