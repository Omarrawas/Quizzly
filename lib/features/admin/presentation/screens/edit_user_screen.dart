import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/home/domain/services/content_service.dart';
import 'package:provider/provider.dart';

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
}
