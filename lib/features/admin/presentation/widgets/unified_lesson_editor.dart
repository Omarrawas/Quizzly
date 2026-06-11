import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/services/firebase_storage_service.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/core/widgets/rich_text_editor.dart';

class UnifiedLessonEditorSheet extends StatefulWidget {
  final String subjectId;
  final String sectionId;
  final String type; // 'lesson' or 'practical'
  final String? docId;
  final Map<String, dynamic>? initialData;
  final String? parentId; // For theoretical sub-lessons

  const UnifiedLessonEditorSheet({
    super.key,
    required this.subjectId,
    required this.sectionId,
    required this.type,
    this.docId,
    this.initialData,
    this.parentId,
  });

  @override
  State<UnifiedLessonEditorSheet> createState() => _UnifiedLessonEditorSheetState();
}

class _UnifiedLessonEditorSheetState extends State<UnifiedLessonEditorSheet> {
  final _storage = FirebaseStorageService();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _videoUrlCtrl = TextEditingController();
  
  bool _isFree = false;
  bool _saving = false;
  
  List<String> _imageUrls = [];
  List<Map<String, dynamic>> _attachments = [];
  
  // For tracking files to upload
  PlatformFile? _videoFile;
  final List<PlatformFile> _newImageFiles = [];
  
  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _titleCtrl.text = data['title'] ?? data['name'] ?? '';
      _descriptionCtrl.text = data['description'] ?? '';
      _videoUrlCtrl.text = data['videoUrl'] ?? '';
      _isFree = data['isFree'] == true;
      _imageUrls = List<String>.from(data['imageUrls'] ?? []);
      _attachments = List<Map<String, dynamic>>.from(data['attachments'] ?? []);
    }
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null) {
      setState(() {
        _videoFile = result.files.first;
        _videoUrlCtrl.text = 'سيتم رفع الفيديو عند الحفظ: ${_videoFile!.name}';
      });
    }
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (result != null) {
      setState(() {
        _newImageFiles.addAll(result.files);
      });
    }
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'mp3', 'wav', 'mp4', 'html'],
    );
    
    if (result != null) {
      final file = result.files.first;
      String type = 'other';
      final ext = file.extension?.toLowerCase();
      if (ext == 'pdf') {
        type = 'pdf';
      } else if (ext == 'mp3' || ext == 'wav') {
        type = 'audio';
      } else if (ext == 'mp4') {
        type = 'video';
      } else if (ext == 'html') {
        type = 'html';
      }

      setState(() {
        _attachments.add({
          'title': file.name,
          'type': type,
          'isNewFile': true,
          'file': file,
        });
      });
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال عنوان الدرس')));
      return;
    }

    setState(() => _saving = true);

    try {
      // 1. Upload Video if picked
      String? finalVideoUrl = _videoUrlCtrl.text.startsWith('سيتم رفع') ? null : _videoUrlCtrl.text.trim();
      if (_videoFile != null) {
        final bytes = _videoFile!.bytes ?? await _videoFile!.xFile.readAsBytes();
        finalVideoUrl = await _storage.uploadFile(
          fileBytes: bytes,
          fileExtension: _videoFile!.extension ?? 'mp4',
          folderName: 'lessons/videos',
          contentType: 'video/${_videoFile!.extension ?? 'mp4'}',
        );
      }

      // 2. Upload New Images
      for (var file in _newImageFiles) {
        final bytes = file.bytes ?? await file.xFile.readAsBytes();
        final url = await _storage.uploadFile(
          fileBytes: bytes,
          fileExtension: file.extension ?? 'jpg',
          folderName: 'lessons/images',
          contentType: 'image/${file.extension ?? 'jpg'}',
        );
        if (url != null) {
          _imageUrls.add(url);
        }
      }

      // 3. Upload New Attachments
      for (var i = 0; i < _attachments.length; i++) {
        if (_attachments[i]['isNewFile'] == true) {
          final file = _attachments[i]['file'] as PlatformFile;
          final bytes = file.bytes ?? await file.xFile.readAsBytes();
          final url = await _storage.uploadFile(
            fileBytes: bytes,
            fileExtension: file.extension ?? 'bin',
            folderName: 'lessons/attachments',
          );
          if (url != null) {
            _attachments[i]['url'] = url;
            _attachments[i].remove('isNewFile');
            _attachments[i].remove('file');
          }
        }
      }

      // 4. Prepare Final Data
      final data = {
        'title': _titleCtrl.text.trim(),
        'name': _titleCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'videoUrl': finalVideoUrl,
        'imageUrls': _imageUrls,
        'attachments': _attachments,
        'isFree': _isFree,
        'type': widget.type,
        'subjectId': widget.subjectId,
        'sectionId': widget.sectionId,
        'lastUpdated': DateTime.now().toString().split(' ')[0],
        'mediaType': finalVideoUrl != null && finalVideoUrl.isNotEmpty 
            ? 'video' 
            : (_imageUrls.isNotEmpty ? 'images' : 'text'),
      };

      if (widget.parentId != null) {
        data['parentId'] = widget.parentId!;
      }

      if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('topics').doc(widget.docId).update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        
        // Calculate order to place at bottom
        final countSnap = await FirebaseFirestore.instance.collection('topics')
            .where('subjectId', isEqualTo: widget.subjectId)
            .where('sectionId', isEqualTo: widget.sectionId)
            .where('parentId', isEqualTo: widget.parentId)
            .count()
            .get();
        data['order'] = countSnap.count;
        
        await FirebaseFirestore.instance.collection('topics').add(data);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 24),
                
                // --- Title ---
                _buildSectionHeader('عنوان الدرس', Icons.title_rounded, isDark),
                _buildTextField(_titleCtrl, 'أدخل عنوان الدرس هنا...', isDark),
                const SizedBox(height: 24),

                // --- Free Toggle ---
                _buildFreeToggle(isDark),
                const SizedBox(height: 24),

                // --- Video ---
                _buildSectionHeader('رابط فيديو أو رفع ملف', Icons.play_circle_fill_rounded, isDark),
                Row(
                  children: [
                    Expanded(child: _buildTextField(_videoUrlCtrl, 'رابط فيديو يوتيوب أو مباشر...', isDark)),
                    const SizedBox(width: 8),
                    _buildIconButton(Icons.upload_file_rounded, 'رفع فيديو', _pickVideo, isDark),
                  ],
                ),
                const SizedBox(height: 24),

                // --- Images ---
                _buildSectionHeader('صور الدرس', Icons.image_rounded, isDark),
                _buildImageGrid(isDark),
                const SizedBox(height: 12),
                _buildActionButton(Icons.add_photo_alternate_rounded, 'إضافة صورة', _pickImages, isDark),
                const SizedBox(height: 24),

                // --- Description ---
                _buildSectionHeader('الشرح النصي (WYSIWYG)', Icons.description_rounded, isDark),
                RichTextEditor(
                  initialHtml: _descriptionCtrl.text,
                  placeholder: 'اكتب الشرح المفصل هنا...',
                  height: 300,
                  onContentChanged: (html) => _descriptionCtrl.text = html,
                ),
                const SizedBox(height: 24),

                // --- Attachments ---
                _buildSectionHeader('مرفقات الدرس (PDF, صوت، ملفات تفاعلية)', Icons.attach_file_rounded, isDark),
                _buildAttachmentsList(isDark),
                const SizedBox(height: 12),
                _buildActionButton(Icons.note_add_rounded, 'إضافة مرفق جديد', _pickAttachment, isDark),
                
                const SizedBox(height: 24 * 2), // Extra space for save button
              ],
            ),
          ),

          // --- Top Pull Bar ---
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[isDark ? 700 : 300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // --- Save Button ---
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                ),
                child: _saving 
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Text(
                        'حفظ الدرس وكافة المرفقات',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final label = widget.type == 'lesson' ? 'نظري' : 'عملي';
    final action = widget.docId == null ? 'إضافة' : 'تعديل';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            widget.type == 'lesson' ? Icons.menu_book_rounded : Icons.biotech_rounded,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$action درس $label بمرفقات متكاملة',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            Text(
              'صور، فيديو، ملفات PDF وشرح WYSIWYG',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primaryBlue),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, bool isDark) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.cairo(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(fontSize: 13, color: Colors.grey),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!),
        ),
      ),
    );
  }

  Widget _buildFreeToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          'درس مجاني للجميع',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          'يمكن للطلاب مشاهدة هذا الدرس دون الحاجة لاشتراك مفعل',
          style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
        ),
        value: _isFree,
        activeThumbColor: Colors.green,
        onChanged: (val) => setState(() => _isFree = val),
      ),
    );
  }

  Widget _buildImageGrid(bool isDark) {
    final allItems = [..._imageUrls, ..._newImageFiles];
    if (allItems.isEmpty) {
      return Container(
        height: 80,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text('لا توجد صور مضافة', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: allItems.length,
        itemBuilder: (context, index) {
          final item = allItems[index];
          return Container(
            width: 100,
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: item is String 
                      ? Image.network(item, width: 100, height: 100, fit: BoxFit.cover)
                      : Image.memory((item as PlatformFile).bytes!, width: 100, height: 100, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: InkWell(
                    onTap: () => setState(() {
                      if (item is String) {
                        _imageUrls.removeAt(index);
                      } else {
                        _newImageFiles.remove(item);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 12),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttachmentsList(bool isDark) {
    if (_attachments.isEmpty) return const SizedBox();
    return Column(
      children: _attachments.asMap().entries.map((entry) {
        final i = entry.key;
        final att = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Icon(_getAttachmentIcon(att['type']), color: AppColors.primaryBlue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  att['title'] ?? 'بدون عنوان',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                onPressed: () => setState(() => _attachments.removeAt(i)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _getAttachmentIcon(String? type) {
    switch (type) {
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'audio': return Icons.audiotrack_rounded;
      case 'video': return Icons.play_circle_rounded;
      case 'html': return Icons.html_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  Widget _buildIconButton(IconData icon, String label, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primaryBlue, size: 20),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primaryBlue),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
            ),
          ],
        ),
      ),
    );
  }
}
