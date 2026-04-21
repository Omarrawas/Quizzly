import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';

class ManageCodesScreen extends StatefulWidget {
  const ManageCodesScreen({super.key});

  @override
  State<ManageCodesScreen> createState() => _ManageCodesScreenState();
}

class _ManageCodesScreenState extends State<ManageCodesScreen> {
  int _selectedIndex = 0; // 0: الأكواد, 1: التفعيلات التجريبية

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () {}, // Refresh logic
          icon: const Icon(
            Icons.refresh_rounded,
            color: AppColors.textSecondary,
            size: 24,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textPrimary,
              size: 20,
            ),
          ),
        ],
        title: Text(
          'إدارة الأكواد',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _buildTabs(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner_rounded, // Assuming an icon that looks like crossed barcode
              size: 80,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'لا يوجد',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9), // Light grey
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildTab(
              title: 'التفعيلات التجريبية',
              index: 1,
              icon: Icons.science_outlined,
            ),
            _buildTab(
               title: 'الأكواد',
               index: 0,
               icon: Icons.qr_code_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab({required String title, required int index, required IconData icon}) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
