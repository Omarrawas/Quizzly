import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/subject/data/models/exam_models.dart';

// ─────────────────────────────────────────
//  ExamListTile — بطاقة دورة امتحانية
// ─────────────────────────────────────────
class ExamListTile extends StatelessWidget {
  final ExamItem exam;
  final VoidCallback onTap;

  const ExamListTile({super.key, required this.exam, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isDark ? Border.all(color: Colors.white10) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // ── Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // "جديد" Badge
                    if (exam.isNew) ...[
                      _NewBadge(),
                      const SizedBox(height: 6),
                    ],
                    // Title
                    Text(
                      exam.title,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Date + Question Count row
                    Row(
                      children: [
                        Text(
                          exam.lastUpdated,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _CountChip(count: exam.questionCount),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // ── Lock / File Icon
              _AccessIcon(isAvailable: exam.isAvailable),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  TagListTile — بطاقة وسم / تصنيف
// ─────────────────────────────────────────
class TagListTile extends StatelessWidget {
  final TagItem tag;
  final VoidCallback onTap;

  const TagListTile({super.key, required this.tag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isDark ? Border.all(color: Colors.white10) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // ── Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tag.isNew) ...[
                      _NewBadge(),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      tag.title,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Counts: wrong (red) + total (blue)
                    Row(
                      children: [
                        if (tag.wrongCount > 0) ...[
                          _SmallCount(
                            count: tag.wrongCount,
                            color: const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 8),
                        ],
                        _CountChip(count: tag.questionCount),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // ── Tag Icon (purple)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF9333EA).withValues(alpha: 0.15) : const Color(0xFFF3E8FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.label_rounded,
                  color: isDark ? const Color(0xFFA855F7) : const Color(0xFF9333EA),
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Shared small widgets
// ─────────────────────────────────────────

class _NewBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.2) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFFFB923C).withValues(alpha: 0.3) : const Color(0xFFFED7AA)),
      ),
      child: Text(
        'جديد',
        style: GoogleFonts.cairo(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final int count;
  const _CountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF60A5FA) : AppColors.primaryBlue;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 3),
        Icon(
          Icons.insert_drive_file_rounded,
          size: 13,
          color: color,
        ),
      ],
    );
  }
}

class _SmallCount extends StatelessWidget {
  final int count;
  final Color color;
  const _SmallCount({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count',
      style: GoogleFonts.cairo(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }
}

class _AccessIcon extends StatelessWidget {
  final bool isAvailable;
  const _AccessIcon({required this.isAvailable});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isAvailable
            ? (isDark ? const Color(0xFF1E40AF).withValues(alpha: 0.2) : const Color(0xFFEFF6FF))
            : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F4F6)),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isAvailable ? Icons.insert_drive_file_rounded : Icons.lock_rounded,
        size: 20,
        color: isAvailable 
            ? (isDark ? const Color(0xFF60A5FA) : AppColors.primaryBlue) 
            : (isDark ? Colors.white24 : const Color(0xFF9CA3AF)),
      ),
    );
  }
}
