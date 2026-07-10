import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'dart:io';
import 'package:quizzly/main.dart';
import 'package:in_app_update/in_app_update.dart';

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  bool _isInitialized = false;
  Future<void>? _initFuture;

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_initFuture != null) return _initFuture;

    _initFuture = _initializeInternal();
    return _initFuture;
  }

  Future<void> _initializeInternal() async {
    try {
      await _remoteConfig.setDefaults({
        'latest_version': '1.0.0',
        'update_url': 'https://play.google.com/store/apps/details?id=com.Quizzly.app',
        'update_notes': 'تحسينات عامة وإصلاح أخطاء',
        'is_mandatory': false,
      });
      
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 1),
      ));
      
      await _remoteConfig.fetchAndActivate();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Remote Config initialization failed: $e');
    }
  }

  Future<void> checkForUpdates(BuildContext context, {bool showNoUpdateDialog = false}) async {
    // 1. Try Native Android Update first (Most reliable for Android)
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final updateInfo = await InAppUpdate.checkForUpdate();
        if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
          // If update is available, use Play Store's native workflow
          if (updateInfo.immediateUpdateAllowed) {
            await InAppUpdate.performImmediateUpdate();
            return; // Done
          } else if (updateInfo.flexibleUpdateAllowed) {
            await InAppUpdate.startFlexibleUpdate();
            await InAppUpdate.completeFlexibleUpdate();
            return; // Done
          }
        }
      } catch (e) {
        debugPrint('Native Android update check failed, falling back to Remote Config: $e');
      }
    }

    // 2. Fallback to Firebase Remote Config (For iOS or if Android Play Store check fails)
    try {
      // Ensure initialized before checking
      if (!_isInitialized) {
        await initialize();
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = "${packageInfo.version}+${packageInfo.buildNumber}";
      
      final latestVersion = _remoteConfig.getString('latest_version');
      final updateUrl = _remoteConfig.getString('update_url');
      final updateNotes = _remoteConfig.getString('update_notes');
      final isMandatory = _remoteConfig.getBool('is_mandatory');

      final activeContext = navigatorKey.currentContext ?? context;

      if (_isNewerVersion(currentVersion, latestVersion)) {
        if (activeContext.mounted) {
          _showUpdateDialog(
            activeContext,
            latestVersion: latestVersion,
            downloadUrl: updateUrl,
            updateNotes: updateNotes,
            isMandatory: isMandatory,
          );
        }
      } else if (showNoUpdateDialog && activeContext.mounted) {
        ScaffoldMessenger.of(activeContext).showSnackBar(
          const SnackBar(
            content: Text('أنت تستخدم أحدث إصدار من التطبيق'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Remote update check failed: $e');
    }
  }

  bool _isNewerVersion(String current, String latest) {
    try {
      // Format: 1.0.7+8
      final currentParts = current.split('+');
      final latestParts = latest.split('+');

      final currentV = currentParts[0].split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final latestV = latestParts[0].split('.').map((e) => int.tryParse(e) ?? 0).toList();
      
      // Compare semantic version (1.0.7)
      for (int i = 0; i < 3; i++) {
        final c = i < currentV.length ? currentV[i] : 0;
        final l = i < latestV.length ? latestV[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }

      // Compare build number (8)
      final currentB = currentParts.length > 1 ? int.tryParse(currentParts[1]) ?? 0 : 0;
      final latestB = latestParts.length > 1 ? int.tryParse(latestParts[1]) ?? 0 : 0;
      
      return latestB > currentB;
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
                ? const Color(0xFF131A26).withValues(alpha: 0.9) 
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
