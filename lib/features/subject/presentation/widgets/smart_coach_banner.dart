import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SmartCoachBanner extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const SmartCoachBanner({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2), // Light red/pink
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFEE2E2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.psychology_rounded, color: Color(0xFFDC2626), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تنبيه المدرب الذكي 🧠',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF991B1B)),
                ),
                Text(
                  message,
                  style: GoogleFonts.cairo(fontSize: 11, color: const Color(0xFFB91C1C)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(actionLabel, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
