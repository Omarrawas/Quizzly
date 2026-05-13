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
  State<PracticalManagementScreen> createState() => _PracticalManagementScreenState();
}

class _PracticalManagementScreenState extends State<PracticalManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _tabs = const [
    (label: 'المذاكرات',  icon: Icons.description_rounded,       subType: 'summary'),
    (label: 'الأطلس',     icon: Icons.biotech_rounded,            subType: 'drawing'),
    (label: 'التجارب',    icon: Icons.science_rounded,            subType: 'experiment'),
    (label: 'المقابلات',  icon: Icons.record_voice_over_rounded,  subType: 'interview'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────

  String get _currentSubType => _tabs[_tabController.index].subType;

  Query _queryFor(String subType) => FirebaseFirestore.instance
      .collection('topics')
      .where('subjectId', isEqualTo: widget.subjectId)
      .where('sectionId', isEqualTo: widget.sectionId)
      .where('type', isEqualTo: 'practical')
      .where('subType', isEqualTo: subType)
      .orderBy('createdAt', descending: true);

  Future<void> _deleteLesson(String docId) async {
    await FirebaseFirestore.instance.collection('topics').doc(docId).delete();
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        title: Text(
          'إدارة المحتوى العملي - ${widget.subjectName}',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primaryBlue,
          labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.cairo(fontSize: 12),
          tabs: _tabs.map((t) => Tab(text: t.label, icon: Icon(t.icon, size: 18))).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((t) => _LessonListView(
          subType: t.subType,
          query: _queryFor(t.subType),
          onDelete: _deleteLesson,
          isDark: isDark,
        )).toList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddLessonSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: Text('إضافة درس', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  // ── Add-Lesson Bottom Sheet ─────────────────────────────────

  void _openAddLessonSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddLessonSheet(
        subType: _currentSubType,
        subjectId: widget.subjectId,
        sectionId: widget.sectionId,
      ),
    );
  }
}

// ── Lesson List ──────────────────────────────────────────────────────────────

class _LessonListView extends StatelessWidget {
  final String subType;
  final Query query;
  final Future<void> Function(String) onDelete;
  final bool isDark;

  const _LessonListView({
    required this.subType,
    required this.query,
    required this.onDelete,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_rounded, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('لا توجد دروس بعد\nاضغط + لإضافة درس جديد',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(color: Colors.grey, height: 1.6)),
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
            return _LessonCard(
              docId: doc.id,
              data: data,
              isDark: isDark,
              onDelete: () => _confirmDelete(context, doc.id, data['title'] ?? ''),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف الدرس', style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text('هل تريد حذف "$title"؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async { Navigator.pop(ctx); await onDelete(id); },
            child: Text('حذف', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Lesson Card ──────────────────────────────────────────────────────────────

class _LessonCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isDark;
  final VoidCallback onDelete;

  const _LessonCard({
    required this.docId,
    required this.data,
    required this.isDark,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title       = data['title'] as String? ?? 'بدون عنوان';
    final description = data['description'] as String? ?? '';
    final mediaType   = data['mediaType'] as String? ?? 'none';
    final videoUrl    = data['videoUrl'] as String?;
    final imageUrls   = (data['imageUrls'] as List?)?.cast<String>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Media Preview ──────────────────────────────────
          if (mediaType == 'video' && videoUrl != null && videoUrl.isNotEmpty)
            _VideoPreview(url: videoUrl),

          if (mediaType == 'images' && imageUrls.isNotEmpty)
            _ImageCarouselPreview(urls: imageUrls),

          // ── Text Content ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : AppColors.textPrimary)),
                    ),
                    // Delete button
                    GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Icon(Icons.delete_outline_rounded, size: 17, color: Colors.red.shade400),
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(description,
                      style: GoogleFonts.cairo(fontSize: 13,
                          color: isDark ? Colors.white60 : AppColors.textSecondary,
                          height: 1.6)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Video Preview ────────────────────────────────────────────────────────────

class _VideoPreview extends StatelessWidget {
  final String url;
  const _VideoPreview({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 64),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Text(url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ),
        ],
      ),
    );
  }
}

// ── Image Carousel Preview ───────────────────────────────────────────────────

class _ImageCarouselPreview extends StatefulWidget {
  final List<String> urls;
  const _ImageCarouselPreview({required this.urls});

  @override
  State<_ImageCarouselPreview> createState() => _ImageCarouselPreviewState();
}

class _ImageCarouselPreviewState extends State<_ImageCarouselPreview> {
  int _current = 0;
  final _controller = PageController();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SizedBox(
        height: 200,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) => Image.network(
                widget.urls[i],
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, _, _) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 48),
                ),
              ),
            ),
            if (widget.urls.length > 1)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.urls.length, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _current == i ? 14 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _current == i ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Add Lesson Bottom Sheet ──────────────────────────────────────────────────

class _AddLessonSheet extends StatefulWidget {
  final String subType;
  final String subjectId;
  final String sectionId;

  const _AddLessonSheet({
    required this.subType,
    required this.subjectId,
    required this.sectionId,
  });

  @override
  State<_AddLessonSheet> createState() => _AddLessonSheetState();
}

class _AddLessonSheetState extends State<_AddLessonSheet> {
  final _titleCtrl       = TextEditingController();
  final _descCtrl        = TextEditingController();
  final _videoUrlCtrl    = TextEditingController();
  final _imageUrlCtrl    = TextEditingController();
  final List<String>     _imageUrls = [];
  String _mediaType = 'none'; // 'none' | 'video' | 'images'
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose();
    _videoUrlCtrl.dispose(); _imageUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final payload = {
      'title':       _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'subjectId':   widget.subjectId,
      'sectionId':   widget.sectionId,
      'type':        'practical',
      'subType':     widget.subType,
      'mediaType':   _mediaType,
      'videoUrl':    _mediaType == 'video' ? _videoUrlCtrl.text.trim() : null,
      'imageUrls':   _mediaType == 'images' ? _imageUrls : [],
      'createdAt':   FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.collection('topics').add(payload);
    if (mounted) Navigator.pop(context);
  }

  void _addImageUrl() {
    final url = _imageUrlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() { _imageUrls.add(url); _imageUrlCtrl.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
            // Handle
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),

            Text('إضافة درس جديد',
                style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary)),
            const SizedBox(height: 20),

            // Title
            _field(_titleCtrl, 'عنوان الدرس *', Icons.title_rounded, isDark),
            const SizedBox(height: 12),

            // ── Media type toggle ──────────────────────────────
            Text('نوع الوسائط', style: GoogleFonts.cairo(fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                _mediaBtn('بدون', 'none', Icons.text_fields_rounded),
                const SizedBox(width: 8),
                _mediaBtn('فيديو', 'video', Icons.play_circle_rounded),
                const SizedBox(width: 8),
                _mediaBtn('صور', 'images', Icons.photo_library_rounded),
              ],
            ),
            const SizedBox(height: 16),

            // ── Video URL ──────────────────────────────────────
            if (_mediaType == 'video') ...[
              _field(_videoUrlCtrl, 'رابط الفيديو (URL)', Icons.link_rounded, isDark),
              const SizedBox(height: 12),
            ],

            // ── Images carousel ────────────────────────────────
            if (_mediaType == 'images') ...[
              Row(
                children: [
                  Expanded(child: _field(_imageUrlCtrl, 'رابط صورة', Icons.image_rounded, isDark)),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addImageUrl,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white),
                  ),
                ],
              ),
              if (_imageUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imageUrls.length,
                    itemBuilder: (_, i) => Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(image: NetworkImage(_imageUrls[i]), fit: BoxFit.cover,
                              onError: (_, _) {}),
                            color: Colors.grey[200],
                          ),
                        ),
                        Positioned(
                          top: 2, right: 10,
                          child: GestureDetector(
                            onTap: () => setState(() => _imageUrls.removeAt(i)),
                            child: Container(width: 18, height: 18,
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 12, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],

            // ── Description (text) ─────────────────────────────
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              style: GoogleFonts.cairo(fontSize: 14, color: isDark ? Colors.white : AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'الشرح النصي',
                labelStyle: GoogleFonts.cairo(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // ── Save button ────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('حفظ الدرس', style: GoogleFonts.cairo(fontWeight: FontWeight.bold,
                        fontSize: 16, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, bool isDark) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.cairo(fontSize: 14, color: isDark ? Colors.white : AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _mediaBtn(String label, String value, IconData icon) {
    final selected = _mediaType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mediaType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryBlue : Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primaryBlue : Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : Colors.grey),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.cairo(fontSize: 11, color: selected ? Colors.white : Colors.grey,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }
}
