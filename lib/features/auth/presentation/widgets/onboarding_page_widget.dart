import 'package:flutter/material.dart';
import 'package:quizzly/core/theme/app_colors.dart';

class OnboardingPageWidget extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final String title;
  final String description;
  final List<String> bulletPoints;
  final String pageNumber;

  const OnboardingPageWidget({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.title,
    required this.description,
    required this.bulletPoints,
    required this.pageNumber,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page Indicator (e.g., 1/7)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              pageNumber,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 48),
          
          // Icon Container
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                icon,
                size: 72,
                color: iconColor,
              ),
            ),
          ),
          const SizedBox(height: 48),

          // Title & Description
          Center(
            child: Text(
              title,
              style: Theme.of(context).textTheme.displayMedium,
              textAlign: TextAlign.center,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 32),

          // Bullet Points
          ...bulletPoints.map((point) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.checkBlue,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        point,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
