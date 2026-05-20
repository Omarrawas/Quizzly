import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  Future<void> initialize() async {
    try {
      await _remoteConfig.setDefaults({
        'latest_version': '1.0.0',
        'update_url': 'https://quizzly.app/download',
        'update_notes': 'تحسينات عامة وإصلاح أخطاء',
        'is_mandatory': false,
      });
      
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 1),
      ));
      
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('Remote Config initialization failed: $e');
    }
  }

  Future<void> checkForUpdates(BuildContext context, {bool showNoUpdateDialog = false}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      final latestVersion = _remoteConfig.getString('latest_version');
      final updateUrl = _remoteConfig.getString('update_url');
      final updateNotes = _remoteConfig.getString('update_notes');
      final isMandatory = _remoteConfig.getBool('is_mandatory');

      if (_isNewerVersion(currentVersion, latestVersion)) {
        if (context.mounted) {
          _showUpdateDialog(
            context,
            latestVersion: latestVersion,
            downloadUrl: updateUrl,
            updateNotes: updateNotes,
            isMandatory: isMandatory,
          );
        }
      } else if (showNoUpdateDialog && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('أنت تستخدم أحدث إصدار من التطبيق'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  bool _isNewerVersion(String current, String latest) {
    try {
      final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      
      for (int i = 0; i < 3; i++) {
        final currentPart = i < currentParts.length ? currentParts[i] : 0;
        final latestPart = i < latestParts.length ? latestParts[i] : 0;
        if (latestPart > currentPart) return true;
        if (latestPart < currentPart) return false;
      }
    } catch (_) {}
    return false;
  }

  void _showUpdateDialog(
    BuildContext context, {
    required String latestVersion,
    required String downloadUrl,
    String? updateNotes,
    bool isMandatory = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (context) => PopScope(
        canPop: !isMandatory,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF1E293B).withValues(alpha: 0.9) 
                : Colors.white.withValues(alpha: 0.9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    color: AppColors.primaryBlue,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'تحديث جديد متاح',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'يتوفر إصدار جديد من التطبيق ($latestVersion). يرجى التحديث للحصول على آخر المميزات والتحسينات.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                  ),
                ),
                if (updateNotes != null && updateNotes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ما الجديد:',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          updateNotes,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              if (!isMandatory)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'لاحقاً',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ElevatedButton(
                onPressed: () async {
                  final uri = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'تحديث الآن',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
