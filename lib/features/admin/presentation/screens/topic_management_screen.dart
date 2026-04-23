import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';

class TopicManagementScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final List<String> breadcrumbs;

  const TopicManagementScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.breadcrumbs,
  });

  @override
  State<TopicManagementScreen> createState() => _TopicManagementScreenState();
}

enum TopicLevel { chapter, lesson, sublesson }

class _TopicManagementScreenState extends State<TopicManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  TopicLevel _currentLevel = TopicLevel.chapter;
  
  final Map<TopicLevel, String> _parentIds = {};
  final Map<TopicLevel, String> _levelNames = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(_currentLevel == TopicLevel.chapter ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (_currentLevel == TopicLevel.chapter) {
              Navigator.pop(context);
            } else {
              _goBack();
            }
          },
        ),
        title: Text(
          _getLevelTitle(),
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildBreadcrumbs(isDark),
          Expanded(child: _buildTopicsList(isDark)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTopicDialog(context),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('إضافة ${_getAddLabel()}', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  String _getLevelTitle() {
    switch (_currentLevel) {
      case TopicLevel.chapter: return 'الفصول';
      case TopicLevel.lesson: return 'الدروس';
      case TopicLevel.sublesson: return 'الفقرات';
    }
  }

  String _getAddLabel() {
    switch (_currentLevel) {
      case TopicLevel.chapter: return 'فصل';
      case TopicLevel.lesson: return 'درس';
      case TopicLevel.sublesson: return 'فقرة';
    }
  }

  void _goBack() {
    setState(() {
      if (_currentLevel == TopicLevel.sublesson) {
        _currentLevel = TopicLevel.lesson;
      } else if (_currentLevel == TopicLevel.lesson) {
        _currentLevel = TopicLevel.chapter;
      }
    });
  }

  Widget _buildBreadcrumbs(bool isDark) {
    List<String> path = [widget.subjectName];
    for (var level in TopicLevel.values) {
      if (level.index < _currentLevel.index && _levelNames.containsKey(level)) {
        path.add(_levelNames[level]!);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: path.asMap().entries.map((entry) {
            return Row(
              children: [
                if (entry.key > 0) Icon(Icons.chevron_left_rounded, size: 16, color: Colors.grey[400]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.value,
                    style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTopicsList(bool isDark) {
    String? parentId;
    if (_currentLevel == TopicLevel.lesson) parentId = _parentIds[TopicLevel.chapter];
    if (_currentLevel == TopicLevel.sublesson) parentId = _parentIds[TopicLevel.lesson];

    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getTopics(widget.subjectId, parentId: parentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) {
          return _emptyState('حدث خطأ أثناء جلب المواضيع: ${snapshot.error}', isDark, isError: true);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyState('لا توجد ${_getLevelTitle()} حالياً', isDark);
        }

        final docs = snapshot.data!.docs;
        return ReorderableListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            return _buildTopicCard(id, data, isDark, key: ValueKey(id));
          },
          onReorder: (oldIndex, newIndex) => _handleReorder(docs, oldIndex, newIndex),
        );
      },
    );
  }

  Future<void> _handleReorder(List<QueryDocumentSnapshot> docs, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final List<String> ids = docs.map((d) => d.id).toList();
    final item = ids.removeAt(oldIndex);
    ids.insert(newIndex, item);
    try {
      await _dbService.updateOrder(DatabaseService.colTopics, ids);
      _showStatusSnackBar('تم تحديث الترتيب', isError: false);
    } catch (e) {
      _showStatusSnackBar('فشل تحديث الترتيب: $e', isError: true);
    }
  }

  Widget _buildTopicCard(String id, Map<String, dynamic> data, bool isDark, {required Key key}) {
    final name = data['name'] ?? '';
    final desc = data['description'] ?? '';

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
      ),
      child: ListTile(
        onTap: _currentLevel != TopicLevel.sublesson ? () => _onTopicTap(id, name) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(name, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        subtitle: desc.isNotEmpty ? Text(desc, style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary)) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_note_rounded, color: Colors.blue), onPressed: () => _showEditTopicDialog(id, data)),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red), onPressed: () => _confirmDelete(id, name)),
            if (_currentLevel != TopicLevel.sublesson) const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
            const Icon(Icons.drag_indicator_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _onTopicTap(String id, String name) {
    setState(() {
      _parentIds[_currentLevel] = id;
      _levelNames[_currentLevel] = name;
      _currentLevel = TopicLevel.values[_currentLevel.index + 1];
    });
  }

  Widget _emptyState(String message, bool isDark, {bool isError = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.account_tree_outlined,
              size: 48,
              color: isError ? Colors.red.withValues(alpha: 0.5) : (isDark ? Colors.white24 : Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            SelectableText(
              message,
              style: GoogleFonts.cairo(color: isError ? Colors.red : AppColors.textSecondary, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      ),
    );
  }

  void _showAddTopicDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('إضافة ${_getAddLabel()} جديد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: 'الاسم', labelStyle: GoogleFonts.cairo())),
            const SizedBox(height: 16),
            TextField(controller: descController, decoration: InputDecoration(labelText: 'الوصف (اختياري)', labelStyle: GoogleFonts.cairo())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                String? parentId;
                if (_currentLevel == TopicLevel.lesson) parentId = _parentIds[TopicLevel.chapter];
                if (_currentLevel == TopicLevel.sublesson) parentId = _parentIds[TopicLevel.lesson];

                try {
                  await _dbService.addTopic(widget.subjectId, parentId, {
                    'name': name,
                    'description': descController.text.trim(),
                    'type': _currentLevel.name,
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    _showStatusSnackBar('تمت إضافة ${_getAddLabel()} بنجاح', isError: false);
                  }
                } catch (e) {
                  if (context.mounted) _showStatusSnackBar('فشل الإضافة: $e', isError: true);
                }
              }
            },
            child: Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showEditTopicDialog(String id, Map<String, dynamic> data) {
    final nameController = TextEditingController(text: data['name']);
    final descController = TextEditingController(text: data['description']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تعديل ${_getAddLabel()}', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: 'الاسم', labelStyle: GoogleFonts.cairo())),
            const SizedBox(height: 16),
            TextField(controller: descController, decoration: InputDecoration(labelText: 'الوصف', labelStyle: GoogleFonts.cairo())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _dbService.updateDoc(DatabaseService.colTopics, id, {
                  'name': nameController.text.trim(),
                  'description': descController.text.trim(),
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  _showStatusSnackBar('تمت عملية التعديل بنجاح', isError: false);
                }
              } catch (e) {
                if (context.mounted) _showStatusSnackBar('فشل التعديل: $e', isError: true);
              }
            },
            child: Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تأكيد الحذف', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('هل أنت متأكد من حذف ($name)؟\nسيتم حذف جميع المواضيع والأسئلة المرتبطة بها.', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          TextButton(
            onPressed: () async {
              try {
                await _dbService.deleteDoc(DatabaseService.colTopics, id);
                if (context.mounted) {
                  Navigator.pop(context);
                  _showStatusSnackBar('تم حذف الموضوع بنجاح', isError: false);
                }
              } catch (e) {
                if (context.mounted) _showStatusSnackBar('فشل الحذف: $e', isError: true);
              }
            },
            child: Text('حذف', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
