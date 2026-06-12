import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:file_picker/file_picker.dart';
import 'package:quizzly/core/services/firebase_storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/math_utils.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'math/editor/quizzly_math_editor.dart';
import 'math/editor/widgets/safe_math_preview.dart';



// ═══════════════════════════════════════════════════════════════
// MATH EMBED BUILDER
// ═══════════════════════════════════════════════════════════════

class PasteIntent extends Intent {
  const PasteIntent();
}

class MathEmbedBuilder extends quill.EmbedBuilder {
  MathEmbedBuilder();

  @override
  String get key => 'math';

@override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final rawData = embedContext.node.value.data;
    final latex = rawData is String ? rawData : '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    // Wrap in Directionality with LTR to ensure math renders correctly
    // regardless of surrounding RTL text direction
    return Directionality(
      textDirection: TextDirection.ltr,
      child: InkWell(
        onTap: () async {
          final resultLatex = await showDialog<String>(
            context: context,
            builder: (context) => QuizzlyMathEditorProvider(initialLatex: latex),
          );
          if (resultLatex != null) {
            final offset = embedContext.node.documentOffset;
            embedContext.controller.replaceText(offset, 1, quill.Embeddable('math', resultLatex), null);
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3), width: 0.5),
          ),
          child: SafeMathPreview(latex: latex, textColor: textColor, mathSize: 18),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// IMAGE EMBED BUILDER (with delete button)
// ═══════════════════════════════════════════════════════════════

class ImageBlockEmbedBuilder extends quill.EmbedBuilder {
  final void Function(String imageUrl)? onDeleteImage;

  ImageBlockEmbedBuilder({this.onDeleteImage});

  @override
  String get key => quill.BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final imageUrl = embedContext.node.value.data as String;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final editorDirection = Directionality.of(context);
    final isRtl = editorDirection == TextDirection.rtl;

    return Container(
      width: double.infinity,
      alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Image Container ──
          Container(
            constraints: const BoxConstraints(
              maxHeight: 400,
              minHeight: 100,
              minWidth: 100,
            ),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade300,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => Container(
                  height: 150,
                  width: 200,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryBlue,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 120,
                  width: 200,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_rounded, color: Colors.red.shade300, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        kIsWeb 
                          ? 'خطأ CORS (يرجى مراجعة إعدادات Firebase)'
                          : 'خطأ في تحميل الصورة',
                        style: TextStyle(fontSize: 10, color: Colors.red.shade300),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Delete Button ──
          Positioned(
            top: -10,
            left: isRtl ? null : -10,
            right: isRtl ? -10 : null,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  final offset = embedContext.node.documentOffset;
                  embedContext.controller.replaceText(offset, 1, '', null);
                  onDeleteImage?.call(imageUrl);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 14,
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

// ═══════════════════════════════════════════════════════════════
// RICH TEXT EDITOR
// ═══════════════════════════════════════════════════════════════

class RichTextEditor extends StatefulWidget {
  final String? initialHtml;
  final Function(String) onContentChanged;
  final String placeholder;
  final double height;
  final bool isCompact;
  final Color? textColor;
  final Function(String imageUrl)? onImageDeleted;

  const RichTextEditor({
    super.key,
    this.initialHtml,
    required this.onContentChanged,
    this.placeholder = 'اكتب هنا...',
    this.height = 200,
    this.isCompact = false,
    this.textColor,
    this.onImageDeleted,
  });

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  late quill.QuillController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isFocused = false;
  final List<String> _deletedImageUrls = [];
  int _previousLength = 1;

  /// List of image URLs that were deleted from this editor
  List<String> get deletedImageUrls => List.unmodifiable(_deletedImageUrls);

  quill.Style get _selectionStyle => _controller.getSelectionStyle();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    _initializeController();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.removeListener(_onContentChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
  }

  Delta _applyDefaultRtl(Delta delta) {
    final newDelta = Delta();
    for (final op in delta.toList()) {
      if (op.isInsert && op.data is String) {
        final text = op.data as String;
        if (text == '\n') {
          final attrs = Map<String, dynamic>.from(op.attributes ?? {});
          if (!attrs.containsKey(quill.Attribute.rtl.key)) {
            attrs[quill.Attribute.rtl.key] = true;
          }
          if (!attrs.containsKey(quill.Attribute.align.key) || attrs[quill.Attribute.align.key] == 'left') {
            attrs[quill.Attribute.align.key] = 'right';
          }
          newDelta.insert('\n', attrs);
        } else if (text.contains('\n')) {
          final parts = text.split('\n');
          for (int i = 0; i < parts.length; i++) {
            if (parts[i].isNotEmpty) {
              newDelta.insert(parts[i], op.attributes);
            }
            if (i < parts.length - 1) {
              final attrs = Map<String, dynamic>.from(op.attributes ?? {});
              if (!attrs.containsKey(quill.Attribute.rtl.key)) {
                attrs[quill.Attribute.rtl.key] = true;
              }
              if (!attrs.containsKey(quill.Attribute.align.key) || attrs[quill.Attribute.align.key] == 'left') {
                attrs[quill.Attribute.align.key] = 'right';
              }
              newDelta.insert('\n', attrs);
            }
          }
        } else {
          newDelta.push(op);
        }
      } else {
        newDelta.push(op);
      }
    }
    return newDelta;
  }

  void _initializeController() {
    try {
      if (widget.initialHtml != null && widget.initialHtml!.isNotEmpty) {
        String html = MathUtils.normalizeMathContent(widget.initialHtml!);
        var delta = HtmlToDelta().convert(html);
        delta = _convertTextDelimitersToMathEmbeds(delta);
        delta = _applyDefaultRtl(delta);
        _controller = quill.QuillController(
          document: quill.Document.fromDelta(delta),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } else {
        final delta = Delta()..insert('\n', {
          quill.Attribute.rtl.key: true,
          quill.Attribute.align.key: 'right',
        });
        _controller = quill.QuillController(
          document: quill.Document.fromDelta(delta),
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } catch (_) {
      final delta = Delta()..insert('\n', {
        quill.Attribute.rtl.key: true,
        quill.Attribute.align.key: 'right',
      });
      _controller = quill.QuillController(
        document: quill.Document.fromDelta(delta),
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
    _previousLength = _controller.document.length;
    _controller.addListener(_onContentChanged);
  }

  Delta _convertTextDelimitersToMathEmbeds(Delta delta) {
    final newDelta = Delta();
    final ops = delta.toList();
    
    for (final op in ops) {
      if (op.isInsert && op.data is String) {
        final text = op.data as String;
        final matches = MathUtils.latexRegex.allMatches(text);
        
        if (matches.isEmpty) {
          newDelta.insert(text, op.attributes);
        } else {
          int lastMatchEnd = 0;
          for (final match in matches) {
            final beforeText = text.substring(lastMatchEnd, match.start);
            if (beforeText.isNotEmpty) {
              newDelta.insert(beforeText, op.attributes);
            }
            
            String mathContent = match.group(0)!;
            // Handle various delimiters and strip them
            if (mathContent.startsWith(r'\\(') && mathContent.endsWith(r'\\)')) {
              mathContent = mathContent.substring(3, mathContent.length - 3);
            } else if (mathContent.startsWith(r'\\[') && mathContent.endsWith(r'\\]')) {
              mathContent = mathContent.substring(3, mathContent.length - 3);
            } else if (mathContent.startsWith(r'\(') && mathContent.endsWith(r'\)')) {
              mathContent = mathContent.substring(2, mathContent.length - 2);
            } else if (mathContent.startsWith(r'\[') && mathContent.endsWith(r'\]')) {
              mathContent = mathContent.substring(2, mathContent.length - 2);
            } else if (mathContent.startsWith(r'$$') && mathContent.endsWith(r'$$')) {
              mathContent = mathContent.substring(2, mathContent.length - 2);
            } else if (mathContent.startsWith(r'$') && mathContent.endsWith(r'$')) {
              mathContent = mathContent.substring(1, mathContent.length - 1);
            }
            
            newDelta.insert(quill.BlockEmbed('math', mathContent), op.attributes);
            lastMatchEnd = match.end;
          }
          final remainingText = text.substring(lastMatchEnd);
          if (remainingText.isNotEmpty) {
            newDelta.insert(remainingText, op.attributes);
          }
        }
      } else {
        newDelta.push(op);
      }
    }
    return newDelta;
  }

  void _onContentChanged() {
    final currentLength = _controller.document.length;
    if (currentLength == 1 && _previousLength > 1) {
      _controller.removeListener(_onContentChanged);
      _controller.formatSelection(quill.Attribute.rtl);
      _controller.formatSelection(quill.Attribute.rightAlignment);
      _controller.addListener(_onContentChanged);
    }
    _previousLength = currentLength;

    final delta = _controller.document.toDelta();
    final List<Map<String, dynamic>> processedOps = [];

    for (final op in delta.toJson()) {
      final insert = op['insert'];
      if (insert is Map && insert.containsKey('math')) {
        final latex = insert['math'].toString();
        processedOps.add({
          'insert': 'MATH_LATEX_START${latex}MATH_LATEX_END',
          'attributes': op['attributes'],
        });
      } else {
        processedOps.add(Map<String, dynamic>.from(op));
      }
    }

    final converter = QuillDeltaToHtmlConverter(
      processedOps,
      ConverterOptions(converterOptions: OpConverterOptions(inlineStylesFlag: true)),
    );

    String html = converter.convert();
    html = html.replaceAll('MATH_LATEX_START', '\\(');
    html = html.replaceAll('MATH_LATEX_END', '\\)');
    widget.onContentChanged(html);
  }

  void _toggleInlineStyle(quill.Attribute attribute) {
    _focusNode.requestFocus();
    final isActive = _selectionStyle.attributes.containsKey(attribute.key);
    _controller.formatSelection(isActive ? quill.Attribute.clone(attribute, null) : attribute);
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    try {
      // Compress to around 70% quality, max 1200px width/height
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1200,
        minHeight: 1200,
        quality: 70,
      );
      return compressed;
    } catch (e) {
      debugPrint('Compression error: $e');
      return bytes; // Fallback to original
    }
  }

  Future<void> _uploadAndInsertImage({Uint8List? rawBytes, String? extension}) async {
    try {
      Uint8List? bytes = rawBytes;
      String? ext = extension;

      if (bytes == null) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image, 
          allowMultiple: false, 
          withData: true
        );
        if (result != null && result.files.isNotEmpty) {
          bytes = result.files.first.bytes;
          ext = result.files.first.extension;
        }
      }

      if (bytes == null) return;
      if (!mounted) return;

      showDialog(
        context: context, 
        barrierDismissible: false, 
        builder: (_) => const Center(child: CircularProgressIndicator())
      );

      // 1. Compress
      final compressedBytes = await _compressImage(bytes);

      // 2. Upload
      final storageService = FirebaseStorageService();
      final url = await storageService.uploadFile(
        fileBytes: compressedBytes, 
        fileExtension: ext ?? 'png', 
        folderName: 'question_images'
      );

      if (mounted) Navigator.pop(context);

      if (url != null) {
        final index = _controller.selection.baseOffset;
        _controller.replaceText(index, 0, quill.BlockEmbed.image(url), null);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      debugPrint('Upload error: $e');
    }
  }

  Future<void> _handlePaste() async {
    try {
      // 1. Check for image
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null) {
        await _uploadAndInsertImage(rawBytes: imageBytes, extension: 'png');
        return;
      }

      // 2. Wrap plain text paste with math detection
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null) {
        final text = data!.text!;
        final index = _controller.selection.baseOffset;
        final length = _controller.selection.extentOffset - index;
        
        // Convert the text being pasted if it contains math delimiters
        final tempDelta = Delta()..insert(text);
        var convertedDelta = _convertTextDelimitersToMathEmbeds(tempDelta);
        convertedDelta = _applyDefaultRtl(convertedDelta);
        
        _controller.replaceText(
          index, 
          length >= 0 ? length : 0, 
          convertedDelta, 
          null
        );
      }
    } catch (e) {
      debugPrint('Paste error: $e');
    }
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isSelected,
    String? tooltip,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isSelected ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary);
    final background = isSelected ? AppColors.primaryBlue : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        style: IconButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: background,
          minimumSize: const Size(34, 34),
          padding: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final editorBackground = isDark ? const Color(0xFF0F172A) : Colors.white;
    final toolbarBackground = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    return Container(
      decoration: BoxDecoration(
        color: editorBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isFocused ? AppColors.primaryBlue : AppColors.borderLight,
          width: _isFocused ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // ═══ TOP TOOLBAR ═══
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: toolbarBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.5))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildToolbarButton(
                    icon: Icons.format_bold,
                    isSelected: _selectionStyle.attributes.containsKey(quill.Attribute.bold.key),
                    onPressed: () => _toggleInlineStyle(quill.Attribute.bold),
                    tooltip: 'غامق',
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_italic,
                    isSelected: _selectionStyle.attributes.containsKey(quill.Attribute.italic.key),
                    onPressed: () => _toggleInlineStyle(quill.Attribute.italic),
                    tooltip: 'مائل',
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_underline,
                    isSelected: _selectionStyle.attributes.containsKey(quill.Attribute.underline.key),
                    onPressed: () => _toggleInlineStyle(quill.Attribute.underline),
                    tooltip: 'تسطير',
                  ),
                  const VerticalDivider(width: 12),
                  _buildToolbarButton(
                    icon: Icons.format_list_bulleted,
                    isSelected: _selectionStyle.attributes[quill.Attribute.list.key]?.value == 'bullet',
                    onPressed: () {
                      final isActive = _selectionStyle.attributes[quill.Attribute.list.key]?.value == 'bullet';
                      _controller.formatSelection(isActive ? quill.Attribute.clone(quill.Attribute.ol, null) : quill.Attribute.ul);
                    },
                    tooltip: 'قائمة نقطية',
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_list_numbered,
                    isSelected: _selectionStyle.attributes[quill.Attribute.list.key]?.value == 'ordered',
                    onPressed: () {
                      final isActive = _selectionStyle.attributes[quill.Attribute.list.key]?.value == 'ordered';
                      _controller.formatSelection(isActive ? quill.Attribute.clone(quill.Attribute.ol, null) : quill.Attribute.ol);
                    },
                    tooltip: 'قائمة مرقّمة',
                  ),
                  const VerticalDivider(width: 12),
                  _buildToolbarButton(
                    icon: Icons.format_align_right,
                    isSelected: _selectionStyle.attributes[quill.Attribute.align.key]?.value == 'right',
                    onPressed: () => _controller.formatSelection(quill.Attribute.rightAlignment),
                    tooltip: 'محاذاة يمين',
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_align_center,
                    isSelected: _selectionStyle.attributes[quill.Attribute.align.key]?.value == 'center',
                    onPressed: () => _controller.formatSelection(quill.Attribute.centerAlignment),
                    tooltip: 'توسيط',
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_align_left,
                    isSelected: _selectionStyle.attributes[quill.Attribute.align.key]?.value == 'left',
                    onPressed: () => _controller.formatSelection(quill.Attribute.leftAlignment),
                    tooltip: 'محاذاة يسار',
                  ),
                  const VerticalDivider(width: 8),
                  _buildToolbarButton(
                    icon: Icons.format_textdirection_r_to_l,
                    isSelected: _selectionStyle.attributes[quill.Attribute.rtl.key] != null,
                    onPressed: () {
                      _controller.formatSelection(quill.Attribute.rtl);
                      _controller.formatSelection(quill.Attribute.rightAlignment);
                    },
                    tooltip: 'من اليمين لليسار (RTL)',
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_textdirection_l_to_r,
                    isSelected: _selectionStyle.attributes[quill.Attribute.rtl.key] == null,
                    onPressed: () {
                      _controller.formatSelection(quill.Attribute.clone(quill.Attribute.rtl, null));
                      _controller.formatSelection(quill.Attribute.leftAlignment);
                    },
                    tooltip: 'من اليسار لليمين (LTR)',
                  ),
                  const VerticalDivider(width: 12),
                  _buildToolbarButton(
                    icon: Icons.image_rounded,
                    isSelected: false,
                    onPressed: _uploadAndInsertImage,
                    tooltip: 'إضافة صورة',
                  ),
                  _buildToolbarButton(
                    icon: Icons.functions_rounded,
                    isSelected: false,
                    onPressed: () async {
                      final resultLatex = await showDialog<String>(
                        context: context,
                        builder: (context) => const QuizzlyMathEditorProvider(),
                      );
                      if (resultLatex != null && resultLatex.isNotEmpty) {
                        _insertMathLatex(resultLatex);
                      }
                    },
                    tooltip: 'إدراج معادلة',
                  ),
                ],
              ),
            ),
          ),

          // ═══ EDITOR AREA ═══
          Stack(
            children: [
              Shortcuts(
                shortcuts: <LogicalKeySet, Intent>{
                  LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV): const PasteIntent(),
                },
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    PasteIntent: CallbackAction<PasteIntent>(
                      onInvoke: (intent) async {
                        await _handlePaste();
                        return null;
                      },
                    ),
                  },
                  child: SizedBox(
                    height: widget.height,
                    child: DefaultTextStyle(
                      style: TextStyle(
                        color: widget.textColor ?? (isDark ? Colors.white : AppColors.textPrimary),
                        fontSize: 16,
                      ),
                      child: Directionality(
                        textDirection: TextDirection.ltr, // Enforce LTR ambient direction to fix flutter_quill RTL bug
                        child: quill.QuillEditor.basic(
                          controller: _controller,
                          focusNode: _focusNode,
                          scrollController: _scrollController,
                          config: quill.QuillEditorConfig(
                            placeholder: widget.placeholder,
                            padding: const EdgeInsets.all(12),
                            autoFocus: false,
                            expands: false,
                            embedBuilders: [
                              ImageBlockEmbedBuilder(
                                onDeleteImage: (url) {
                                  _deletedImageUrls.add(url);
                                  widget.onImageDeleted?.call(url);
                                },
                              ),
                              MathEmbedBuilder(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _insertMathLatex(String latex) {
    final index = _controller.selection.baseOffset;
    _controller.replaceText(index, 0, quill.Embeddable('math', latex), null);
  }
}
