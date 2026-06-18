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
import 'package:http/http.dart' as http;
import 'package:file_saver/file_saver.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image/image.dart' as img_lib;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_math_fork/flutter_math.dart' as math_fork;

class PasteIntent extends Intent {
  const PasteIntent();
}

// ═══════════════════════════════════════════════════════════════
// IMAGE EMBED BUILDER (with delete button)
// ═══════════════════════════════════════════════════════════════

class ImageBlockEmbedBuilder extends quill.EmbedBuilder {
  final void Function(String imageUrl)? onDeleteImage;
  final void Function(String imageUrl, quill.EmbedContext embedContext)?
  onEditImage;

  ImageBlockEmbedBuilder({this.onDeleteImage, this.onEditImage});

  @override
  String get key => quill.BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final imageUrl = embedContext.node.value.data as String;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final editorDirection = Directionality.of(context);
    final isRtl = editorDirection == TextDirection.rtl;

    // Read the width attribute
    final style = embedContext.node.style;
    final widthAttr = style.attributes['width']?.value;

    double? width;
    if (widthAttr != null) {
      width = double.tryParse(widthAttr.toString());
    }

    return Container(
      width: double.infinity,
      alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Image Container ──
          GestureDetector(
            onTap: () => _showImageOptionsMenu(context, imageUrl, embedContext),
            child: Container(
              width: width,
              constraints: BoxConstraints(
                maxHeight: 400,
                minHeight: 100,
                minWidth: width != null ? 0 : 100,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.grey.shade50,
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
                        Icon(
                          Icons.broken_image_rounded,
                          color: Colors.red.shade300,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          kIsWeb
                              ? 'خطأ CORS (يرجى مراجعة إعدادات Firebase)'
                              : 'خطأ في تحميل الصورة',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red.shade300,
                          ),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
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

  void _showImageOptionsMenu(
    BuildContext context,
    String imageUrl,
    quill.EmbedContext embedContext,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF6E56FF);
    final errorColor = const Color(0xFFFF4C6A);
    final surfaceColor = const Color(0xFF222329);

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'خيارات الصورة',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                // 1. Resize (تعديل الحجم)
                ListTile(
                  leading: Icon(
                    Icons.photo_size_select_large_rounded,
                    color: primaryColor,
                  ),
                  title: const Text(
                    'تعديل الحجم',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showResizeDialog(context, embedContext);
                  },
                ),

                // إزالة الخلفية للصورة المرفوعة مسبقاً
                if (onEditImage != null)
                  ListTile(
                    leading: Icon(Icons.blur_off_rounded, color: primaryColor),
                    title: const Text(
                      'إزالة الخلفية',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 16),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onEditImage!(imageUrl, embedContext);
                    },
                  ),

                // 2. Zoom (معاينة)
                ListTile(
                  leading: Icon(Icons.zoom_in_rounded, color: primaryColor),
                  title: const Text(
                    'معاينة وتكبير',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showZoomDialog(context, imageUrl);
                  },
                ),

                // 3. Copy (نسخ الرابط)
                ListTile(
                  leading: Icon(Icons.copy_rounded, color: primaryColor),
                  title: const Text(
                    'نسخ رابط الصورة',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 16),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await Clipboard.setData(ClipboardData(text: imageUrl));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'تم نسخ رابط الصورة إلى الحافظة',
                          style: TextStyle(fontFamily: 'Tajawal'),
                          textDirection: TextDirection.rtl,
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Color(0xFF6E56FF),
                      ),
                    );
                  },
                ),

                // 4. Save (حفظ)
                ListTile(
                  leading: Icon(Icons.save_rounded, color: primaryColor),
                  title: const Text(
                    'حفظ الصورة في الجهاز',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _saveImage(context, imageUrl);
                  },
                ),

                // Divider
                Divider(color: const Color(0xFF2D2E36)),

                // 5. Remove (حذف)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: errorColor,
                  ),
                  title: Text(
                    'حذف الصورة',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 16,
                      color: errorColor,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    final offset = embedContext.node.documentOffset;
                    embedContext.controller.replaceText(offset, 1, '', null);
                    onDeleteImage?.call(imageUrl);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showResizeDialog(
    BuildContext context,
    quill.EmbedContext embedContext,
  ) {
    final surfaceColor = const Color(0xFF222329);
    final primaryColor = const Color(0xFF6E56FF);
    final currentStyle = embedContext.node.style;
    final currentWidthVal = currentStyle.attributes['width']?.value;

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'اختر حجم الصورة',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildResizeOption(
                  context,
                  embedContext,
                  'ملء العرض (100%)',
                  null,
                  currentWidthVal == null,
                ),
                _buildResizeOption(
                  context,
                  embedContext,
                  'كبير (400 بكسل)',
                  '400',
                  currentWidthVal?.toString() == '400',
                ),
                _buildResizeOption(
                  context,
                  embedContext,
                  'متوسط (300 بكسل)',
                  '300',
                  currentWidthVal?.toString() == '300',
                ),
                _buildResizeOption(
                  context,
                  embedContext,
                  'صغير (200 بكسل)',
                  '200',
                  currentWidthVal?.toString() == '200',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'إلغاء',
                  style: TextStyle(fontFamily: 'Tajawal', color: primaryColor),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResizeOption(
    BuildContext context,
    quill.EmbedContext embedContext,
    String label,
    String? widthValue,
    bool isSelected,
  ) {
    final primaryColor = const Color(0xFF6E56FF);
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? primaryColor : null,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: primaryColor)
          : null,
      onTap: () {
        Navigator.pop(context);
        final offset = embedContext.node.documentOffset;
        if (widthValue == null) {
          embedContext.controller.formatText(
            offset,
            1,
            quill.Attribute.clone(quill.Attribute.width, null),
          );
        } else {
          embedContext.controller.formatText(
            offset,
            1,
            quill.Attribute.clone(quill.Attribute.width, widthValue),
          );
        }
      },
    );
  }

  void _showZoomDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  style: IconButton.styleFrom(backgroundColor: Colors.black38),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveImage(BuildContext context, String imageUrl) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF6E56FF)),
        ),
      );

      final response = await http.get(Uri.parse(imageUrl));
      if (!context.mounted) return;
      Navigator.pop(context); // close loader

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final fileName =
            'quizzly_image_${DateTime.now().millisecondsSinceEpoch}';

        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: bytes,
          ext: 'png',
          mimeType: MimeType.png,
        );

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم حفظ الصورة بنجاح',
              style: TextStyle(fontFamily: 'Tajawal'),
              textDirection: TextDirection.rtl,
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF7DFFA2),
          ),
        );
      } else {
        throw Exception('Failed to download image');
      }
    } catch (e) {
      if (!context.mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل حفظ الصورة: $e',
            style: const TextStyle(fontFamily: 'Tajawal'),
            textDirection: TextDirection.rtl,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFFF4C6A),
        ),
      );
    }
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
  TextSelection _previousSelection = const TextSelection.collapsed(offset: 0);
  String? _lastGeneratedHtml;
  int? _lastKnownInsertionOffset;
  bool _isAutoFormatting = false;
  bool _isNormalizingSelection = false;
  bool _isProgrammaticInsert =
      false; // prevents cursor normalization during equation/image inserts

  /// List of image URLs that were deleted from this editor
  List<String> get deletedImageUrls => List.unmodifiable(_deletedImageUrls);

  quill.Style get _selectionStyle => _controller.getSelectionStyle();

  int get _activeInsertionOffset {
    final selectionOffset = _controller.selection.extentOffset;
    if (selectionOffset >= 0) {
      return selectionOffset.clamp(0, _controller.document.length - 1);
    }
    if (_lastKnownInsertionOffset != null) {
      return _lastKnownInsertionOffset!.clamp(
        0,
        _controller.document.length - 1,
      );
    }
    return _controller.document.length - 1;
  }

  String _getCurrentLineText() {
    try {
      final text = _controller.document.toPlainText();
      final offset = _controller.selection.extentOffset;
      if (offset < 0 || offset > text.length) return '';

      int start = text.lastIndexOf('\n', offset - 1);
      if (start == -1) {
        start = 0;
      } else {
        start += 1;
      }

      int end = text.indexOf('\n', offset);
      if (end == -1) {
        end = text.length;
      }

      if (start >= end) return '';
      return text.substring(start, end);
    } catch (_) {
      return '';
    }
  }

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

  @override
  void didUpdateWidget(covariant RichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Do NOT reinitialize while we are doing a programmatic insert (equation/image).
    // The programmatic insert fires onContentChanged which updates the parent's
    // initialHtml; if we reinitialize here we would reload the OLD html and lose
    // (or reorder) the just-inserted embed.
    if (_isProgrammaticInsert) return;
    if (widget.initialHtml != oldWidget.initialHtml) {
      if (widget.initialHtml != _lastGeneratedHtml) {
        final currentSelection = _controller.selection;
        _controller.removeListener(_onContentChanged);
        _controller.dispose();
        _initializeController(currentSelection);
        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  void _onFocusChanged() {
    if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
  }

  // Direction helpers removed to let the editor layout handle directionality naturally

  void _initializeController([TextSelection? preserveSelection]) {
    try {
      if (widget.initialHtml != null && widget.initialHtml!.isNotEmpty) {
        // Math equations are stored as plain LaTeX text \(...\) inside HTML.
        // No embed conversion needed – just load HTML as-is into Quill.
        String html = MathUtils.normalizeMathContent(widget.initialHtml!);
        var delta = HtmlToDelta().convert(html);
        delta = _applyRtlToDeltaBlocks(delta);

        final doc = delta.isEmpty
            ? quill.Document()
            : quill.Document.fromDelta(delta);
        final docLength = doc.length;
        TextSelection finalSelection =
            preserveSelection ?? const TextSelection.collapsed(offset: 0);
        if (finalSelection.baseOffset > docLength - 1 ||
            finalSelection.extentOffset > docLength - 1) {
          finalSelection = TextSelection.collapsed(offset: docLength - 1);
        }

        _controller = quill.QuillController(
          document: doc,
          selection: finalSelection,
        );
      } else {
        final delta = Delta()..insert('\n', {'rtl': true, 'align': 'right'});
        _controller = quill.QuillController(
          document: quill.Document.fromDelta(delta),
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } catch (_) {
      final delta = Delta()..insert('\n', {'rtl': true, 'align': 'right'});
      _controller = quill.QuillController(
        document: quill.Document.fromDelta(delta),
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
    _previousLength = _controller.document.length;
    _previousSelection = _controller.selection;
    _lastKnownInsertionOffset = _controller.selection.extentOffset >= 0
        ? _controller.selection.extentOffset
        : null;
    _lastGeneratedHtml = _getCurrentHtml();
    _controller.addListener(_onContentChanged);
  }

  Delta _applyRtlToDeltaBlocks(Delta delta) {
    try {
      final newDelta = Delta();
      final ops = delta.toList();

      final plainText = _getPlainTextOfDelta(delta);
      final lines = plainText.split('\n');
      final lineIsArabic = lines.map((line) {
        return true; // Always RTL for Quizzly to comply with global dark fintech rules
      }).toList();

      int currentLineIndex = 0;
      for (final op in ops) {
        if (op.isInsert) {
          final data = op.data;
          if (data is String) {
            if (data.contains('\n')) {
              final parts = data.split('\n');
              for (int i = 0; i < parts.length; i++) {
                final part = parts[i];
                if (part.isNotEmpty) {
                  newDelta.insert(part, op.attributes);
                }
                if (i < parts.length - 1) {
                  final isRtl =
                      currentLineIndex < lineIsArabic.length &&
                      lineIsArabic[currentLineIndex];
                  final newAttrs = Map<String, dynamic>.from(
                    op.attributes ?? {},
                  );
                  if (isRtl) {
                    newAttrs['rtl'] = true;
                    newAttrs['align'] = 'right';
                  }
                  newDelta.insert('\n', newAttrs);
                  currentLineIndex++;
                }
              }
            } else {
              newDelta.push(op);
            }
          } else {
            newDelta.push(op);
          }
        } else {
          newDelta.push(op);
        }
      }
      return newDelta;
    } catch (_) {
      return delta;
    }
  }

  String _getPlainTextOfDelta(Delta delta) {
    final buffer = StringBuffer();
    for (final op in delta.toList()) {
      if (op.isInsert) {
        if (op.data is String) {
          buffer.write(op.data as String);
        } else {
          buffer.write(' ');
        }
      }
    }
    return buffer.toString();
  }

  String _getCurrentHtml() {
    try {
      final delta = _controller.document.toDelta();
      final List<Map<String, dynamic>> processedOps = [];

      for (final op in delta.toJson()) {
        final Map<String, dynamic> opMap = Map<String, dynamic>.from(op);
        var insert = opMap['insert'];

        // Serialize Embeddable objects (images only now)
        if (insert is quill.Embeddable) {
          insert = insert.toJson();
          opMap['insert'] = insert;
        }
        processedOps.add(opMap);
      }

      final converter = QuillDeltaToHtmlConverter(
        processedOps,
        ConverterOptions(
          converterOptions: OpConverterOptions(inlineStylesFlag: true),
        ),
      );

      // Math equations are plain text \(...\) – no substitution needed.
      return converter.convert();
    } catch (e, stackTrace) {
      debugPrint('Error in _getCurrentHtml: $e\n$stackTrace');
      try {
        return _controller.document.toPlainText();
      } catch (_) {
        return '';
      }
    }
  }

  void _onContentChanged() {
    final currentLength = _controller.document.length;
    final currentSelection = _controller.selection;

    // Update last known insertion offset if selection is valid and editor is focused
    if (_focusNode.hasFocus && currentSelection.extentOffset >= 0) {
      _lastKnownInsertionOffset = currentSelection.extentOffset;
    }

    // Dynamic auto-directionality formatting based on text content.
    // Skip during programmatic inserts: formatSelection triggers another
    // _onContentChanged → onContentChanged → parent rebuild → didUpdateWidget
    // which can reload stale HTML and swap/erase the inserted embed.
    if (!_isAutoFormatting &&
        !_isProgrammaticInsert &&
        _focusNode.hasFocus &&
        currentSelection.isCollapsed &&
        currentSelection.extentOffset >= 0) {
      _isAutoFormatting = true;
      try {
        final lineText = _getCurrentLineText();
        // Default to RTL if line is empty or spaces, otherwise check for Arabic
        final isArabic =
            lineText.trim().isEmpty ||
            MathUtils.getDirection(lineText) == TextDirection.rtl;

        final selectionStyle = _controller.getSelectionStyle();
        final hasRtlAttr = selectionStyle.attributes.containsKey(
          quill.Attribute.rtl.key,
        );
        final hasRightAlign =
            selectionStyle.attributes[quill.Attribute.align.key]?.value ==
            'right';

        if (isArabic) {
          if (!hasRtlAttr || !hasRightAlign) {
            _controller.formatSelection(quill.Attribute.rtl);
            _controller.formatSelection(quill.Attribute.rightAlignment);
          }
        } else {
          if (hasRtlAttr) {
            _controller.formatSelection(
              quill.Attribute.clone(quill.Attribute.rtl, null),
            );
            _controller.formatSelection(
              quill.Attribute.clone(quill.Attribute.align, null),
            );
          }
        }
      } catch (e) {
        debugPrint('Auto format error: $e');
      } finally {
        _isAutoFormatting = false;
      }
    }

    final wasTypingAtEnd =
        _previousSelection.isCollapsed &&
        _previousSelection.extentOffset >= _previousLength - 1 &&
        currentLength > _previousLength;

    // Only normalize cursor if user is actively typing at the end,
    // NOT during programmatic inserts like equations or images which
    // deliberately insert content in the middle of the document.
    if (!_isNormalizingSelection &&
        !_isProgrammaticInsert &&
        wasTypingAtEnd &&
        currentSelection.extentOffset < currentLength - 1) {
      _isNormalizingSelection = true;
      _controller.updateSelection(
        TextSelection.collapsed(offset: currentLength - 1),
        quill.ChangeSource.local,
      );
      _isNormalizingSelection = false;
    }

    // Let natural directionality handle empty documents
    _previousLength = currentLength;
    _previousSelection = _controller.selection;

    // Do NOT propagate to parent during a programmatic insert.
    // The insert itself will call _notifyParentAfterInsert() once it is
    // fully done so the parent sees the final, correct document.
    if (_isProgrammaticInsert) return;

    final html = _getCurrentHtml();
    _lastGeneratedHtml = html;
    widget.onContentChanged(html);
  }

  /// Called after a programmatic insert (equation / image) completes to push
  /// the final document HTML to the parent exactly once.
  void _notifyParentAfterInsert() {
    if (!mounted) return;
    final html = _getCurrentHtml();
    _lastGeneratedHtml = html;
    widget.onContentChanged(html);
  }

  void _toggleInlineStyle(quill.Attribute attribute) {
    _focusNode.requestFocus();
    final isActive = _selectionStyle.attributes.containsKey(attribute.key);
    _controller.formatSelection(
      isActive ? quill.Attribute.clone(attribute, null) : attribute,
    );
  }

  Future<Uint8List> _compressImage(
    Uint8List bytes, {
    String formatStr = 'jpeg',
  }) async {
    try {
      final compressFormat = (formatStr.toLowerCase() == 'png')
          ? CompressFormat.png
          : CompressFormat.jpeg;

      // Compress to around 70% quality, max 1200px width/height
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1200,
        minHeight: 1200,
        quality: 70,
        format: compressFormat,
      );
      return compressed;
    } catch (e) {
      debugPrint('Compression error: $e');
      return bytes; // Fallback to original
    }
  }

  Future<void> _uploadAndInsertImage({
    Uint8List? rawBytes,
    String? extension,
  }) async {
    final index = _activeInsertionOffset;
    try {
      Uint8List? bytes = rawBytes;
      String? ext = extension;

      if (bytes == null) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );
        if (result != null && result.files.isNotEmpty) {
          bytes = result.files.first.bytes;
          ext = result.files.first.extension;
        }
      }

      if (bytes == null) return;
      if (!mounted) return;

      // Show the Background Removal and Optimizer dialog!
      final processingResult = await showDialog<ImageProcessResult>(
        context: context,
        barrierDismissible: false,
        builder: (context) => ImageOptimizerDialog(imageBytes: bytes!),
      );

      if (processingResult == null) return; // user cancelled

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF6E56FF)),
        ),
      );

      Uint8List finalBytes = processingResult.processedBytes;
      String finalExt = processingResult.removeBackground
          ? 'png'
          : (ext ?? 'png');

      // 1. Compress
      final compressedBytes = await _compressImage(
        finalBytes,
        formatStr: finalExt,
      );

      // 2. Upload
      final storageService = FirebaseStorageService();
      final url = await storageService.uploadFile(
        fileBytes: compressedBytes,
        fileExtension: finalExt,
        folderName: 'question_images',
      );

      if (mounted) Navigator.pop(context);

      if (url != null) {
        _isProgrammaticInsert = true;
        try {
          _controller.replaceText(
            index,
            0,
            quill.BlockEmbed.image(url),
            TextSelection.collapsed(offset: index + 1),
          );
          _lastKnownInsertionOffset = index + 1;
        } finally {
          _isProgrammaticInsert = false;
          // Notify parent once with the settled document.
          _notifyParentAfterInsert();
        }
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      debugPrint('Upload error: $e');
    }
  }

  Future<void> _editExistingImage(
    String imageUrl,
    quill.EmbedContext embedContext,
  ) async {
    // Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF6E56FF)),
      ),
    );

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (response.statusCode != 200) {
        throw Exception('فشل تحميل الصورة من الخادم');
      }

      final bytes = response.bodyBytes;
      if (!mounted) return;

      final processingResult = await showDialog<ImageProcessResult>(
        context: context,
        barrierDismissible: false,
        builder: (context) => ImageOptimizerDialog(imageBytes: bytes),
      );

      if (processingResult == null) return; // user cancelled

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF6E56FF)),
        ),
      );

      Uint8List finalBytes = processingResult.processedBytes;
      String finalExt = 'png'; // background removal outputs png

      // Compress
      final compressedBytes = await _compressImage(
        finalBytes,
        formatStr: finalExt,
      );

      // Upload
      final storageService = FirebaseStorageService();
      final url = await storageService.uploadFile(
        fileBytes: compressedBytes,
        fileExtension: finalExt,
        folderName: 'question_images',
      );

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (url != null) {
        final offset = embedContext.node.documentOffset;

        // Preserve width attributes if any
        final style = embedContext.node.style;
        final widthAttr = style.attributes['width'];

        // Replace the existing image block embed
        _controller.replaceText(offset, 1, quill.BlockEmbed.image(url), null);

        if (widthAttr != null) {
          _controller.formatText(offset, 1, widthAttr);
        }

        // Delete the old image
        _deletedImageUrls.add(imageUrl);
        widget.onImageDeleted?.call(imageUrl);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      debugPrint('Edit existing image error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل تعديل الصورة: $e',
              style: const TextStyle(fontFamily: 'Tajawal'),
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: const Color(0xFFFF4C6A),
          ),
        );
      }
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

      // 2. Paste plain text as-is. LaTeX delimiters \(...\) are stored as text.
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null) {
        final text = data!.text!;
        final selection = _controller.selection;
        final index = selection.start;
        final length = selection.end - selection.start;
        _controller.replaceText(index, length, text, null);
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
    final foreground = isSelected
        ? Colors.white
        : (isDark ? Colors.white : AppColors.textPrimary);
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
    final toolbarBackground = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF8FAFC);

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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.borderLight.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildToolbarButton(
                    icon: Icons.format_bold,
                    isSelected: _selectionStyle.attributes.containsKey(
                      quill.Attribute.bold.key,
                    ),
                    onPressed: () => _toggleInlineStyle(quill.Attribute.bold),
                    tooltip: 'غامق',
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_italic,
                    isSelected: _selectionStyle.attributes.containsKey(
                      quill.Attribute.italic.key,
                    ),
                    onPressed: () => _toggleInlineStyle(quill.Attribute.italic),
                    tooltip: 'مائل',
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_underline,
                    isSelected: _selectionStyle.attributes.containsKey(
                      quill.Attribute.underline.key,
                    ),
                    onPressed: () =>
                        _toggleInlineStyle(quill.Attribute.underline),
                    tooltip: 'تسطير',
                  ),
                  const VerticalDivider(width: 12),
                  _buildToolbarButton(
                    icon: Icons.format_list_bulleted,
                    isSelected:
                        _selectionStyle
                            .attributes[quill.Attribute.list.key]
                            ?.value ==
                        'bullet',
                    onPressed: () {
                      final isActive =
                          _selectionStyle
                              .attributes[quill.Attribute.list.key]
                              ?.value ==
                          'bullet';
                      _controller.formatSelection(
                        isActive
                            ? quill.Attribute.clone(quill.Attribute.ol, null)
                            : quill.Attribute.ul,
                      );
                    },
                    tooltip: 'قائمة نقطية',
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_list_numbered,
                    isSelected:
                        _selectionStyle
                            .attributes[quill.Attribute.list.key]
                            ?.value ==
                        'ordered',
                    onPressed: () {
                      final isActive =
                          _selectionStyle
                              .attributes[quill.Attribute.list.key]
                              ?.value ==
                          'ordered';
                      _controller.formatSelection(
                        isActive
                            ? quill.Attribute.clone(quill.Attribute.ol, null)
                            : quill.Attribute.ol,
                      );
                    },
                    tooltip: 'قائمة مرقّمة',
                  ),
                  const VerticalDivider(width: 12),
                  _buildToolbarButton(
                    icon: Icons.format_align_right,
                    isSelected:
                        _selectionStyle
                            .attributes[quill.Attribute.align.key]
                            ?.value ==
                        'right',
                    onPressed: () => _controller.formatSelection(
                      quill.Attribute.rightAlignment,
                    ),
                    tooltip: 'محاذاة يمين',
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_align_center,
                    isSelected:
                        _selectionStyle
                            .attributes[quill.Attribute.align.key]
                            ?.value ==
                        'center',
                    onPressed: () => _controller.formatSelection(
                      quill.Attribute.centerAlignment,
                    ),
                    tooltip: 'توسيط',
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_align_left,
                    isSelected:
                        _selectionStyle
                            .attributes[quill.Attribute.align.key]
                            ?.value ==
                        'left',
                    onPressed: () => _controller.formatSelection(
                      quill.Attribute.leftAlignment,
                    ),
                    tooltip: 'محاذاة يسار',
                  ),
                  const VerticalDivider(width: 8),
                  _buildToolbarButton(
                    icon: Icons.format_textdirection_r_to_l,
                    isSelected: _selectionStyle.attributes.containsKey(
                      quill.Attribute.rtl.key,
                    ),
                    onPressed: () {
                      _controller.formatSelection(quill.Attribute.rtl);
                      _controller.formatSelection(
                        quill.Attribute.rightAlignment,
                      );
                    },
                    tooltip: 'من اليمين لليسار (RTL)',
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_textdirection_l_to_r,
                    isSelected: !_selectionStyle.attributes.containsKey(
                      quill.Attribute.rtl.key,
                    ),
                    onPressed: () {
                      _controller.formatSelection(
                        quill.Attribute.clone(quill.Attribute.rtl, null),
                      );
                      _controller.formatSelection(
                        quill.Attribute.leftAlignment,
                      );
                    },
                    tooltip: 'من اليسار لليمين (LTR)',
                  ),
                  const VerticalDivider(width: 12),
                  _buildToolbarButton(
                    icon: Icons.format_color_text_rounded,
                    isSelected: _selectionStyle.attributes.containsKey(
                      quill.Attribute.color.key,
                    ),
                    onPressed: () =>
                        _showColorPickerDialog(isBackground: false),
                    tooltip: 'لون النص',
                  ),
                  _buildToolbarButton(
                    icon: Icons.border_color_rounded,
                    isSelected: _selectionStyle.attributes.containsKey(
                      quill.Attribute.background.key,
                    ),
                    onPressed: () => _showColorPickerDialog(isBackground: true),
                    tooltip: 'لون التظليل',
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
                      final index = _activeInsertionOffset;
                      final resultLatex = await showDialog<String>(
                        context: context,
                        builder: (context) => const QuizzlyMathEditorProvider(),
                      );
                      if (resultLatex != null && resultLatex.isNotEmpty) {
                        _insertMathLatex(resultLatex, index);
                      }
                    },
                    tooltip: 'إدراج معادلة',
                  ),
                  _buildToolbarButton(
                    icon: Icons.preview_rounded,
                    isSelected: false,
                    onPressed: _showMathPreview,
                    tooltip: 'معاينة المعادلات',
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
                  LogicalKeySet(
                    LogicalKeyboardKey.control,
                    LogicalKeyboardKey.keyV,
                  ): const PasteIntent(),
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
                        color:
                            widget.textColor ??
                            (isDark ? Colors.white : AppColors.textPrimary),
                        fontSize: 16,
                      ),
                      child: Directionality(
                        textDirection: TextDirection.rtl,
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
                                onEditImage: _editExistingImage,
                              ),
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

  /// Inserts a math equation as plain LaTeX text \(formula\) at the cursor.
  /// This is simple, reliable, and free from embed↔HTML conversion issues.
  /// The student-facing renderer (TexViewWidget) parses and renders the LaTeX.
  void _insertMathLatex(String latex, [int? customOffset]) {
    final index = customOffset ?? _activeInsertionOffset;
    // Insert as plain text: \(formula\) followed by a space
    final textToInsert = '\\($latex\\) ';
    _controller.replaceText(
      index,
      0,
      textToInsert,
      TextSelection.collapsed(offset: index + textToInsert.length),
    );
    _lastKnownInsertionOffset = index + textToInsert.length;
  }

  /// Shows a preview dialog rendering all \(...\) equations in the current text.
  void _showMathPreview() {
    final html = _getCurrentHtml();
    final plainText = _controller.document.toPlainText();
    showDialog(
      context: context,
      builder: (context) =>
          _MathPreviewDialog(content: plainText, htmlContent: html),
    );
  }

  void _showColorPickerDialog({required bool isBackground}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = const Color(0xFF222329);
    final primaryColor = const Color(0xFF6E56FF);

    // Get current color from selection style
    final attributeKey = isBackground
        ? quill.Attribute.background.key
        : quill.Attribute.color.key;
    final currentHex = _selectionStyle.attributes[attributeKey]?.value
        ?.toString();
    Color initialColor = Colors.red; // default color
    if (currentHex != null && currentHex.startsWith('#')) {
      try {
        initialColor = Color(
          int.parse(currentHex.substring(1), radix: 16) + 0xFF000000,
        );
      } catch (_) {}
    }

    Color tempColor = initialColor;

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              isBackground ? 'اختر لون الخلفية (التظليل)' : 'اختر لون النص',
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 320,
                height: 400,
                child: MaterialPicker(
                  pickerColor: tempColor,
                  onColorChanged: (color) {
                    tempColor = color;
                  },
                ),
              ),
            ),
            actions: [
              // Clear color option
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  final targetAttribute = isBackground
                      ? quill.Attribute.background
                      : quill.Attribute.color;
                  _controller.formatSelection(
                    quill.Attribute.clone(targetAttribute, null),
                  );
                },
                child: const Text(
                  'مسح اللون',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: Colors.redAccent,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'إلغاء',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  final hexString =
                      '#${(tempColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
                  final targetAttribute = isBackground
                      ? quill.Attribute.background
                      : quill.Attribute.color;
                  _controller.formatSelection(
                    quill.Attribute.clone(targetAttribute, hexString),
                  );
                },
                child: Text(
                  'موافق',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// IMAGE OPTIMIZER AND BACKGROUND REMOVER DIALOG
// ═══════════════════════════════════════════════════════════════

class ImageProcessResult {
  final Uint8List processedBytes;
  final bool removeBackground;

  ImageProcessResult({
    required this.processedBytes,
    required this.removeBackground,
  });
}

class ImageOptimizerDialog extends StatefulWidget {
  final Uint8List imageBytes;

  const ImageOptimizerDialog({super.key, required this.imageBytes});

  @override
  State<ImageOptimizerDialog> createState() => _ImageOptimizerDialogState();
}

class _ImageOptimizerDialogState extends State<ImageOptimizerDialog> {
  bool _removeBackground = false;
  String _bgType = 'white'; // 'white' or 'black'
  double _threshold = 240.0;
  bool _isInitializing = true;
  bool _isProcessingFull = false;

  img_lib.Image? _originalFullImage;
  img_lib.Image? _previewImage;
  Uint8List? _previewBytes;

  @override
  void initState() {
    super.initState();
    _initializeImages();
  }

  Future<void> _initializeImages() async {
    try {
      final decoded = await compute(img_lib.decodeImage, widget.imageBytes);
      if (decoded != null) {
        _originalFullImage = decoded;
        // If image is larger than 1000px wide, downscale the preview to 1000px.
        // Otherwise use the original image directly to preserve maximum clarity.
        if (decoded.width > 1000) {
          _previewImage = img_lib.copyResize(
            decoded,
            width: 1000,
            interpolation: img_lib.Interpolation.average,
          );
        } else {
          _previewImage = decoded;
        }
        _previewBytes = widget.imageBytes;
      }
    } catch (e) {
      debugPrint('Error decoding image for optimizer: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  void _updatePreview() {
    if (_previewImage == null) return;

    if (!_removeBackground) {
      setState(() {
        _previewBytes = widget.imageBytes;
      });
      return;
    }

    final thresholdVal = _threshold.toInt();
    final processed = _previewImage!.convert(numChannels: 4);
    const int tolerance = 25; // anti-aliasing transition range

    for (final pixel in processed) {
      final num r = pixel.r;
      final num g = pixel.g;
      final num b = pixel.b;

      if (_bgType == 'white') {
        final int minVal = thresholdVal - tolerance;
        // W represents the level of whiteness/brightness in the darkest channel.
        // A high minimum of R, G, B implies neutral white or very light grey.
        final num w = r < g ? (r < b ? r : b) : (g < b ? g : b);
        if (w >= thresholdVal) {
          pixel.a = 0;
        } else if (w > minVal) {
          final double ratio = (w - minVal) / tolerance;
          final int newAlpha = (255 * (1.0 - ratio)).round();
          if (newAlpha < pixel.a) {
            pixel.a = newAlpha;
          }
        }
      } else {
        // For black background removal
        final num bMax = r > g ? (r > b ? r : b) : (g > b ? g : b);
        if (bMax <= thresholdVal) {
          pixel.a = 0;
        } else if (bMax < thresholdVal + tolerance) {
          final double ratio = (bMax - thresholdVal) / tolerance;
          final int newAlpha = (255 * ratio).round();
          if (newAlpha < pixel.a) {
            pixel.a = newAlpha;
          }
        }
      }
    }

    setState(() {
      _previewBytes = Uint8List.fromList(img_lib.encodePng(processed));
    });
  }

  Future<void> _confirmAndProcess() async {
    if (!_removeBackground || _originalFullImage == null) {
      Navigator.pop(
        context,
        ImageProcessResult(
          processedBytes: widget.imageBytes,
          removeBackground: false,
        ),
      );
      return;
    }

    setState(() {
      _isProcessingFull = true;
    });

    try {
      final thresholdVal = _threshold.toInt();
      final processedBytes = await compute(_processFullImageStatic, {
        'image': _originalFullImage!,
        'threshold': thresholdVal,
        'bgType': _bgType,
      });

      if (mounted) {
        Navigator.pop(
          context,
          ImageProcessResult(
            processedBytes: processedBytes,
            removeBackground: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error processing full image: $e');
      if (mounted) {
        Navigator.pop(
          context,
          ImageProcessResult(
            processedBytes: widget.imageBytes,
            removeBackground: false,
          ),
        );
      }
    }
  }

  static Uint8List _processFullImageStatic(Map<String, dynamic> params) {
    final img_lib.Image original = params['image'] as img_lib.Image;
    final int threshold = params['threshold'] as int;
    final String bgType = params['bgType'] as String;

    final processed = original.convert(numChannels: 4);
    const int tolerance = 25; // anti-aliasing transition range

    for (final pixel in processed) {
      final num r = pixel.r;
      final num g = pixel.g;
      final num b = pixel.b;

      if (bgType == 'white') {
        final int minVal = threshold - tolerance;
        final num w = r < g ? (r < b ? r : b) : (g < b ? g : b);
        if (w >= threshold) {
          pixel.a = 0;
        } else if (w > minVal) {
          final double ratio = (w - minVal) / tolerance;
          final int newAlpha = (255 * (1.0 - ratio)).round();
          if (newAlpha < pixel.a) {
            pixel.a = newAlpha;
          }
        }
      } else {
        final num bMax = r > g ? (r > b ? r : b) : (g > b ? g : b);
        if (bMax <= threshold) {
          pixel.a = 0;
        } else if (bMax < threshold + tolerance) {
          final double ratio = (bMax - threshold) / tolerance;
          final int newAlpha = (255 * ratio).round();
          if (newAlpha < pixel.a) {
            pixel.a = newAlpha;
          }
        }
      }
    }
    return Uint8List.fromList(img_lib.encodePng(processed));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF6E56FF);
    final surfaceColor = const Color(0xFF222329);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: surfaceColor,
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'تحسين وتجهيز الصورة',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        content: _isProcessingFull
            ? SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF6E56FF)),
                      const SizedBox(height: 16),
                      Text(
                        'جاري معالجة الصورة وإزالة الخلفية...',
                        style: GoogleFonts.tajawal(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: _isInitializing
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF6E56FF),
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _previewBytes != null
                                ? Image.memory(
                                    _previewBytes!,
                                    fit: BoxFit.contain,
                                  )
                                : const Icon(
                                    Icons.image,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(
                      'إزالة خلفية الصورة',
                      style: GoogleFonts.tajawal(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      'يجعل خلفية الصورة البيضاء أو السوداء شفافة',
                      style: GoogleFonts.tajawal(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                    value: _removeBackground,
                    activeThumbColor: primaryColor,
                    onChanged: _isInitializing
                        ? null
                        : (val) {
                            setState(() {
                              _removeBackground = val;
                            });
                            _updatePreview();
                          },
                  ),
                  if (_removeBackground) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'نوع الخلفية المراد إزالتها:',
                            style: GoogleFonts.tajawal(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          Row(
                            children: [
                              ChoiceChip(
                                label: Text(
                                  'بيضاء',
                                  style: GoogleFonts.tajawal(fontSize: 11),
                                ),
                                selected: _bgType == 'white',
                                selectedColor: primaryColor,
                                labelStyle: TextStyle(
                                  color: _bgType == 'white'
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                                backgroundColor: Colors.white10,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _bgType = 'white';
                                      _threshold = 240.0;
                                    });
                                    _updatePreview();
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: Text(
                                  'سوداء/داكنة',
                                  style: GoogleFonts.tajawal(fontSize: 11),
                                ),
                                selected: _bgType == 'black',
                                selectedColor: primaryColor,
                                labelStyle: TextStyle(
                                  color: _bgType == 'black'
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                                backgroundColor: Colors.white10,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _bgType = 'black';
                                      _threshold = 40.0;
                                    });
                                    _updatePreview();
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _bgType == 'white'
                                ? 'حساسية اللون الأبيض'
                                : 'حساسية اللون الأسود',
                            style: GoogleFonts.tajawal(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            '${_threshold.toInt()}',
                            style: GoogleFonts.tajawal(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Slider(
                      value: _threshold,
                      min: _bgType == 'white' ? 150.0 : 0.0,
                      max: _bgType == 'white' ? 255.0 : 120.0,
                      activeColor: primaryColor,
                      inactiveColor: Colors.white10,
                      onChanged: (val) {
                        setState(() {
                          _threshold = val;
                        });
                        _updatePreview();
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: primaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'هذه الأداة تقوم بتحويل لون الخلفية المختار إلى شفاف بالكامل وتضغط حجم الصورة لتسريع التصفح وتوفير المساحة.',
                            style: GoogleFonts.tajawal(
                              fontSize: 10,
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: GoogleFonts.tajawal(color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isInitializing ? null : _confirmAndProcess,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'إدراج الصورة',
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MATH PREVIEW DIALOG  –  "كيف يراها الطالب؟"
// ═══════════════════════════════════════════════════════════════

class _MathPreviewDialog extends StatelessWidget {
  final String content; // plain text from the editor
  final String htmlContent; // html output

  const _MathPreviewDialog({required this.content, required this.htmlContent});

  /// Splits plain-text content into segments of normal text and LaTeX spans.
  List<InlineSpan> _buildSpans(BuildContext context) {
    final textColor = Colors.white.withValues(alpha: 0.92);
    final latexRegex = RegExp(r'(\\\(.*?\\\)|\\\[.*?\\\])', dotAll: true);

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in latexRegex.allMatches(content)) {
      // Text before the equation
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: content.substring(lastEnd, match.start),
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 17,
              color: textColor,
              height: 1.7,
            ),
          ),
        );
      }

      // Extract raw LaTeX between delimiters
      String raw = match.group(0)!;
      String latex = raw;
      if (raw.startsWith(r'\(') && raw.endsWith(r'\)')) {
        latex = raw.substring(2, raw.length - 2);
      } else if (raw.startsWith(r'\[') && raw.endsWith(r'\]')) {
        latex = raw.substring(2, raw.length - 2);
      }

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: math_fork.Math.tex(
                latex,
                textStyle: TextStyle(fontSize: 18, color: textColor),
                onErrorFallback: (e) => Text(
                  raw,
                  style: TextStyle(
                    color: Colors.red.shade300,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      lastEnd = match.end;
    }

    // Remaining text after last equation
    if (lastEnd < content.length) {
      spans.add(
        TextSpan(
          text: content.substring(lastEnd),
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 17,
            color: textColor,
            height: 1.7,
          ),
        ),
      );
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF222329),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header ───
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1B1F),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF2D2E36), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.preview_rounded,
                      color: Color(0xFF6E56FF),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'معاينة كما يراها الطالب',
                      style: GoogleFonts.tajawal(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 18,
                      ),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // ─── Content ───
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: RichText(
                      textDirection: TextDirection.rtl,
                      text: TextSpan(children: _buildSpans(context)),
                    ),
                  ),
                ),
              ),
              // ─── Footer ───
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1B1F),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(color: Color(0xFF2D2E36), width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'هذه المعاينة تُظهر المعادلات كما ستظهر للطالب',
                      style: GoogleFonts.tajawal(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6E56FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      child: Text(
                        'إغلاق',
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
