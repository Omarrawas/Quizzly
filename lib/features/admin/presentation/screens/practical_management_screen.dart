import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';

class PracticalManagementScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final String sectionId;
  final String sectionName;

  const PracticalManagementScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.sectionId,
    required this.sectionName,
  });

  @override
  State<PracticalManagementScreen> createState() =>
      _PracticalManagementScreenState();
}

class _PracticalManagementScreenState extends State<PracticalManagementScreen> {
  Query get _query => FirebaseFirestore.instance
      .collection('topics')
      .where('subjectId', isEqualTo: widget.subjectId)
      .where('sectionId', isEqualTo: widget.sectionId)
      .where('type', isEqualTo: 'practical')
      .orderBy('createdAt', descending: true);

  Future<void> _deleteLesson(String docId) async {
    await FirebaseFirestore.instance.collection('topics').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        title: Text(
          'إدارة الدروس العملية - ${widget.subjectName}',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _query.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'لا توجد دروس مضافة\nاضغط + لإضافة أول درس',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(color: Colors.grey, height: 1.6),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] ?? data['name'] ?? 'بدون عنوان';

              return _LessonAdminCard(
                docId: doc.id,
                data: data,
                title: title,
                isDark: isDark,
                onDelete: () => _confirmDelete(context, doc.id, title),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddLessonSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'إضافة درس جديد',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'حذف الدرس',
          style: GoogleFonts.cairo(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text('هل تريد حذف "$title"؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteLesson(id);
            },
            child: Text('حذف', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openAddLessonSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddLessonSheet(
        subjectId: widget.subjectId,
        sectionId: widget.sectionId,
      ),
    );
  }
}

class _LessonAdminCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String title;
  final bool isDark;
  final VoidCallback onDelete;

  const _LessonAdminCard({
    required this.docId,
    required this.data,
    required this.title,
    required this.isDark,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final description = data['description'] as String? ?? '';
    final mediaType = data['mediaType'] as String? ?? 'none';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    mediaType == 'video'
                        ? Icons.play_circle_rounded
                        : mediaType == 'images'
                        ? Icons.photo_library_rounded
                        : Icons.text_snippet_rounded,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddLessonSheet extends StatefulWidget {
  final String subjectId;
  final String sectionId;

  const _AddLessonSheet({required this.subjectId, required this.sectionId});

  @override
  State<_AddLessonSheet> createState() => _AddLessonSheetState();
}

class _AddLessonSheetState extends State<_AddLessonSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _videoUrlCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  final List<String> _imageUrls = [];
  String _mediaType = 'none';
  bool _saving = false;

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await FirebaseFirestore.instance.collection('topics').add({
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'subjectId': widget.subjectId,
      'sectionId': widget.sectionId,
      'type': 'practical',
      'subType': 'lesson', // Unified
      'mediaType': _mediaType,
      'videoUrl': _mediaType == 'video' ? _videoUrlCtrl.text.trim() : null,
      'imageUrls': _mediaType == 'images' ? _imageUrls : [],
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'إضافة درس عملي جديد',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _field(_titleCtrl, 'عنوان الدرس', Icons.title_rounded, isDark),
            const SizedBox(height: 16),
            Text(
              'نوع الوسائط',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _mediaBtn('بلا', 'none', Icons.text_fields_rounded),
                const SizedBox(width: 8),
                _mediaBtn('فيديو', 'video', Icons.play_circle_rounded),
                const SizedBox(width: 8),
                _mediaBtn('صور', 'images', Icons.photo_library_rounded),
              ],
            ),
            const SizedBox(height: 16),
            if (_mediaType == 'video')
              _field(_videoUrlCtrl, 'رابط الفيديو', Icons.link_rounded, isDark),
            if (_mediaType == 'images') ...[
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _imageUrlCtrl,
                      'رابط صورة',
                      Icons.image_rounded,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (_imageUrlCtrl.text.isNotEmpty)
                        setState(() {
                          _imageUrls.add(_imageUrlCtrl.text.trim());
                          _imageUrlCtrl.clear();
                        });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_imageUrls.isNotEmpty)
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imageUrls.length,
                    itemBuilder: (_, i) => Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(_imageUrls[i]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'الشرح النصي للدرس',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'حفظ الدرس',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon,
    bool isDark,
  ) => TextField(
    controller: ctrl,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  Widget _mediaBtn(String label, String value, IconData icon) {
    final selected = _mediaType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mediaType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryBlue : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primaryBlue : Colors.grey[300]!,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : Colors.grey,
              ),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 10,
                  color: selected ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
