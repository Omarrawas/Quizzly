import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/subject/data/models/practical_models.dart';

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

class _PracticalManagementScreenState extends State<PracticalManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة المحتوى العملي - ${widget.subjectName}', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'المذاكرات', icon: Icon(Icons.description_rounded)),
            Tab(text: 'الأطلس', icon: Icon(Icons.biotech_rounded)),
            Tab(text: 'التجارب', icon: Icon(Icons.science_rounded)),
            Tab(text: 'المقابلات', icon: Icon(Icons.record_voice_over_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryList(PracticalCategory.summary, isDark),
          _buildCategoryList(PracticalCategory.drawing, isDark),
          _buildCategoryList(PracticalCategory.experiment, isDark),
          _buildCategoryList(PracticalCategory.interview, isDark),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(_tabController.index),
        label: Text('إضافة جديد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  Widget _buildCategoryList(PracticalCategory category, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('topics')
          .where('subjectId', isEqualTo: widget.subjectId)
          .where('sectionId', isEqualTo: widget.sectionId)
          .where('type', isEqualTo: 'practical')
          .where('subType', isEqualTo: category.name)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(child: Text('لا يوجد محتوى في هذا القسم بعد', style: GoogleFonts.cairo(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final item = PracticalItem.fromFirestore(docs[index]);
            return _buildItemTile(item, isDark);
          },
        );
      },
    );
  }

  Widget _buildItemTile(PracticalItem item, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: Text(item.title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        subtitle: Text(item.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_note_rounded, color: Colors.blue), onPressed: () => _showEditDialog(item)),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red), onPressed: () => _confirmDelete(item)),
          ],
        ),
      ),
    );
  }

  // --- Dialogs ---

  void _showAddDialog(int tabIndex) {
    PracticalCategory category;
    switch (tabIndex) {
      case 0: category = PracticalCategory.summary; break;
      case 1: category = PracticalCategory.drawing; break;
      case 2: category = PracticalCategory.experiment; break;
      default: category = PracticalCategory.interview;
    }
    
    _showEditorDialog(category: category);
  }

  void _showEditDialog(PracticalItem item) {
    _showEditorDialog(item: item, category: item.category);
  }

  void _showEditorDialog({PracticalItem? item, required PracticalCategory category}) {
    final titleController = TextEditingController(text: item?.title);
    final descController = TextEditingController(text: item?.description);
    final contentController = TextEditingController(text: item?.content);
    final imageUrlController = TextEditingController(text: item?.imageUrl);
    
    // For Steps and Questions, we'll use local state in a StatefulBuilder
    List<String> localSteps = List.from(item?.steps ?? []);
    List<OralQuestion> localQuestions = List.from(item?.oralQuestions ?? []);
    List<MicroscopicLabel> localLabels = List.from(item?.labels ?? []);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'إضافة محتوى جديد' : 'تعديل المحتوى', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: InputDecoration(labelText: 'العنوان', labelStyle: GoogleFonts.cairo())),
                TextField(controller: descController, decoration: InputDecoration(labelText: 'الوصف', labelStyle: GoogleFonts.cairo())),
                
                if (category == PracticalCategory.summary)
                  TextField(controller: contentController, maxLines: 5, decoration: InputDecoration(labelText: 'المحتوى المكتوب', labelStyle: GoogleFonts.cairo())),
                
                if (category == PracticalCategory.drawing || category == PracticalCategory.experiment)
                  TextField(controller: imageUrlController, decoration: InputDecoration(labelText: 'رابط الصورة', labelStyle: GoogleFonts.cairo())),

                if (category == PracticalCategory.experiment) ...[
                  const Divider(height: 32),
                  Text('خطوات العمل', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  ...localSteps.asMap().entries.map((entry) => Row(
                    children: [
                      Expanded(child: Text(entry.value, style: GoogleFonts.cairo(fontSize: 12))),
                      IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18), onPressed: () => setDialogState(() => localSteps.removeAt(entry.key))),
                    ],
                  )),
                  TextButton.icon(
                    onPressed: () => _showAddStepDialog(context, (step) => setDialogState(() => localSteps.add(step))),
                    icon: const Icon(Icons.add),
                    label: Text('إضافة خطوة', style: GoogleFonts.cairo()),
                  ),
                ],

                if (category == PracticalCategory.interview) ...[
                  const Divider(height: 32),
                  Text('الأسئلة والأجوبة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  ...localQuestions.asMap().entries.map((entry) => ListTile(
                    dense: true,
                    title: Text(entry.value.question, style: GoogleFonts.cairo(fontSize: 12)),
                    subtitle: Text(entry.value.answer, style: GoogleFonts.cairo(fontSize: 10)),
                    trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18), onPressed: () => setDialogState(() => localQuestions.removeAt(entry.key))),
                  )),
                  TextButton.icon(
                    onPressed: () => _showAddQADialog(context, (q, a) => setDialogState(() => localQuestions.add(OralQuestion(question: q, answer: a)))),
                    icon: const Icon(Icons.add),
                    label: Text('إضافة سؤال', style: GoogleFonts.cairo()),
                  ),
                ],
                
                if (category == PracticalCategory.drawing) ...[
                  const Divider(height: 32),
                  Text('المسميات (Labels)', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  ...localLabels.asMap().entries.map((entry) => ListTile(
                    dense: true,
                    title: Text(entry.value.label, style: GoogleFonts.cairo(fontSize: 12)),
                    subtitle: Text('X: ${entry.value.x.toStringAsFixed(2)}, Y: ${entry.value.y.toStringAsFixed(2)}', style: GoogleFonts.cairo(fontSize: 10)),
                    trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18), onPressed: () => setDialogState(() => localLabels.removeAt(entry.key))),
                  )),
                  TextButton.icon(
                    onPressed: () => _showAddLabelDialog(context, (l, x, y) => setDialogState(() => localLabels.add(MicroscopicLabel(label: l, x: x, y: y)))),
                    icon: const Icon(Icons.add),
                    label: Text('إضافة مسمى', style: GoogleFonts.cairo()),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
            ElevatedButton(
              onPressed: () async {
                final newItem = PracticalItem(
                  id: item?.id ?? '',
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  category: category,
                  content: contentController.text.trim(),
                  imageUrl: imageUrlController.text.trim(),
                  steps: localSteps,
                  oralQuestions: localQuestions,
                  labels: localLabels,
                  lastUpdated: DateTime.now().toString(),
                );

                if (item == null) {
                  await FirebaseFirestore.instance.collection('topics').add({
                    ...newItem.toFirestore(),
                    'subjectId': widget.subjectId,
                    'sectionId': widget.sectionId,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                } else {
                  await FirebaseFirestore.instance.collection('topics').doc(item.id).update(newItem.toFirestore());
                }
                
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('حفظ', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStepDialog(BuildContext context, Function(String) onAdd) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('خطوة جديدة', style: GoogleFonts.cairo()),
        content: TextField(controller: controller, decoration: InputDecoration(labelText: 'نص الخطوة')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          TextButton(onPressed: () { onAdd(controller.text); Navigator.pop(context); }, child: Text('إضافة')),
        ],
      ),
    );
  }

  void _showAddQADialog(BuildContext context, Function(String, String) onAdd) {
    final qController = TextEditingController();
    final aController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('سؤال جديد', style: GoogleFonts.cairo()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: qController, decoration: InputDecoration(labelText: 'السؤال')),
            TextField(controller: aController, decoration: InputDecoration(labelText: 'الإجابة')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          TextButton(onPressed: () { onAdd(qController.text, aController.text); Navigator.pop(context); }, child: Text('إضافة')),
        ],
      ),
    );
  }

  void _showAddLabelDialog(BuildContext context, Function(String, double, double) onAdd) {
    final lController = TextEditingController();
    final xController = TextEditingController(text: '0.5');
    final yController = TextEditingController(text: '0.5');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('مسمى جديد', style: GoogleFonts.cairo()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: lController, decoration: InputDecoration(labelText: 'المسمى')),
            Row(
              children: [
                Expanded(child: TextField(controller: xController, decoration: InputDecoration(labelText: 'X (0-1)'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: yController, decoration: InputDecoration(labelText: 'Y (0-1)'))),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          TextButton(onPressed: () { 
            onAdd(lController.text, double.tryParse(xController.text) ?? 0.5, double.tryParse(yController.text) ?? 0.5); 
            Navigator.pop(context); 
          }, child: Text('إضافة')),
        ],
      ),
    );
  }

  void _confirmDelete(PracticalItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف', style: GoogleFonts.cairo(color: Colors.red)),
        content: Text('هل أنت متأكد من حذف (${item.title})؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          TextButton(onPressed: () async {
            await FirebaseFirestore.instance.collection('topics').doc(item.id).delete();
            if (context.mounted) Navigator.pop(context);
          }, child: Text('حذف', style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
