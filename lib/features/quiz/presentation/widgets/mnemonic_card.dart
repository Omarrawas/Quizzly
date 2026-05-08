import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MnemonicCard extends StatelessWidget {
  final String? mnemonic;
  final VoidCallback onTap;

  const MnemonicCard({
    super.key,
    required this.mnemonic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasMnemonic = mnemonic != null && mnemonic!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasMnemonic 
            ? const Color(0xFFFFF7ED) // Light Orange
            : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasMnemonic 
              ? const Color(0xFFFB923C).withValues(alpha: 0.5) 
              : Colors.transparent,
          ),
          boxShadow: hasMnemonic ? [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hasMnemonic ? const Color(0xFFFB923C) : Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.psychology_rounded,
                color: hasMnemonic ? Colors.white : Colors.grey,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasMnemonic ? 'رابطك الذهني للحفظ' : 'هل تجد صعوبة في حفظ هذا السؤال؟',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: hasMnemonic ? const Color(0xFF9A3412) : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasMnemonic ? mnemonic! : 'أضف جملة أو كلمة مفتاحية لتسهيل تذكر الإجابة...',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: hasMnemonic ? const Color(0xFFC2410C) : Colors.grey[500],
                      fontStyle: hasMnemonic ? FontStyle.normal : FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              hasMnemonic ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
              color: hasMnemonic ? const Color(0xFFFB923C) : Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
