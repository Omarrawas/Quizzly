import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

/// Status of a video download
enum VideoDownloadStatus {
  notDownloaded,
  downloading,
  downloaded,
  updateAvailable,
  failed,
}

/// Metadata about a downloaded video
class VideoDownloadInfo {
  final String lessonId;
  final String videoUrl;
  final String localPath;
  final DateTime downloadedAt;
  final String urlHash; // to detect URL changes = content updates

  const VideoDownloadInfo({
    required this.lessonId,
    required this.videoUrl,
    required this.localPath,
    required this.downloadedAt,
    required this.urlHash,
  });

  Map<String, dynamic> toJson() => {
        'lessonId': lessonId,
        'videoUrl': videoUrl,
        'localPath': localPath,
        'downloadedAt': downloadedAt.toIso8601String(),
        'urlHash': urlHash,
      };

  factory VideoDownloadInfo.fromJson(Map<String, dynamic> json) =>
      VideoDownloadInfo(
        lessonId: json['lessonId'] as String,
        videoUrl: json['videoUrl'] as String,
        localPath: json['localPath'] as String,
        downloadedAt: DateTime.parse(json['downloadedAt'] as String),
        urlHash: json['urlHash'] as String,
      );
}

/// Service to manage hidden offline video downloads.
/// Videos are stored in the app's private documents directory –
/// they are NOT visible in the device gallery or file manager.
class VideoDownloadService {
  static final VideoDownloadService _instance =
      VideoDownloadService._internal();
  factory VideoDownloadService() => _instance;
  VideoDownloadService._internal();

  static const String _prefsKey = 'video_download_registry';
  static const String _videosSubDir = 'quizzly_videos';

  final Dio _dio = Dio();

  // Active download progress notifiers: lessonId -> 0.0..1.0
  final Map<String, ValueNotifier<double>> _progressNotifiers = {};

  // Active cancel tokens
  final Map<String, CancelToken> _cancelTokens = {};

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<Directory> _getVideosDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_videosSubDir');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _hashUrl(String url) {
    final bytes = utf8.encode(url);
    return md5.convert(bytes).toString();
  }

  Future<Map<String, VideoDownloadInfo>> _loadRegistry() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json == null) return {};
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return map.map(
        (k, v) => MapEntry(k, VideoDownloadInfo.fromJson(v as Map<String, dynamic>)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveRegistry(Map<String, VideoDownloadInfo> registry) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(
      registry.map((k, v) => MapEntry(k, v.toJson())),
    );
    await prefs.setString(_prefsKey, json);
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns the current status of a video for a lesson.
  Future<VideoDownloadStatus> getStatus(String lessonId, String videoUrl) async {
    // YouTube videos cannot be downloaded (only direct MP4 URLs)
    if (_isYoutubeUrl(videoUrl)) return VideoDownloadStatus.notDownloaded;

    if (_progressNotifiers.containsKey(lessonId)) {
      return VideoDownloadStatus.downloading;
    }

    final registry = await _loadRegistry();
    final info = registry[lessonId];
    if (info == null) return VideoDownloadStatus.notDownloaded;

    // Check if the file still exists on disk
    if (!File(info.localPath).existsSync()) {
      registry.remove(lessonId);
      await _saveRegistry(registry);
      return VideoDownloadStatus.notDownloaded;
    }

    // Check if the URL changed → new version available
    final currentHash = _hashUrl(videoUrl);
    if (info.urlHash != currentHash) {
      return VideoDownloadStatus.updateAvailable;
    }

    return VideoDownloadStatus.downloaded;
  }

  /// Returns a [ValueNotifier<double>] for download progress (0.0 – 1.0).
  /// Returns null if not currently downloading.
  ValueNotifier<double>? getProgressNotifier(String lessonId) {
    return _progressNotifiers[lessonId];
  }

  /// Returns the local file path if the video is downloaded, otherwise null.
  Future<String?> getLocalPath(String lessonId) async {
    final registry = await _loadRegistry();
    final info = registry[lessonId];
    if (info == null) return null;
    if (!File(info.localPath).existsSync()) return null;
    return info.localPath;
  }

  /// Starts downloading a video. Only works for direct MP4/video URLs.
  /// YouTube links are not supported for download.
  /// Returns the progress notifier so the caller can track progress.
  Future<ValueNotifier<double>?> startDownload({
    required String lessonId,
    required String videoUrl,
  }) async {
    if (_isYoutubeUrl(videoUrl)) return null;
    if (_progressNotifiers.containsKey(lessonId)) {
      return _progressNotifiers[lessonId];
    }

    final dir = await _getVideosDir();
    final fileName = '${lessonId}_${_hashUrl(videoUrl)}.mp4';
    final filePath = '${dir.path}/$fileName';

    final progressNotifier = ValueNotifier<double>(0.0);
    _progressNotifiers[lessonId] = progressNotifier;

    final cancelToken = CancelToken();
    _cancelTokens[lessonId] = cancelToken;

    // Delete old file for this lesson if exists
    final registry = await _loadRegistry();
    final oldInfo = registry[lessonId];
    if (oldInfo != null && File(oldInfo.localPath).existsSync()) {
      try {
        await File(oldInfo.localPath).delete();
      } catch (_) {}
    }

    // Start download in background
    _runDownload(
      lessonId: lessonId,
      videoUrl: videoUrl,
      filePath: filePath,
      fileName: fileName,
      progressNotifier: progressNotifier,
      cancelToken: cancelToken,
      registry: registry,
    );

    return progressNotifier;
  }

  Future<void> _runDownload({
    required String lessonId,
    required String videoUrl,
    required String filePath,
    required String fileName,
    required ValueNotifier<double> progressNotifier,
    required CancelToken cancelToken,
    required Map<String, VideoDownloadInfo> registry,
  }) async {
    try {
      await _dio.download(
        videoUrl,
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            progressNotifier.value = received / total;
          }
        },
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      // Save to registry
      registry[lessonId] = VideoDownloadInfo(
        lessonId: lessonId,
        videoUrl: videoUrl,
        localPath: filePath,
        downloadedAt: DateTime.now(),
        urlHash: _hashUrl(videoUrl),
      );
      await _saveRegistry(registry);

      progressNotifier.value = 1.0;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        // User cancelled – clean up partial file
        try {
          if (File(filePath).existsSync()) await File(filePath).delete();
        } catch (_) {}
      } else {
        debugPrint('[VideoDownloadService] Download failed: $e');
      }
      progressNotifier.value = -1; // Error sentinel
    } catch (e) {
      debugPrint('[VideoDownloadService] Unexpected error: $e');
      progressNotifier.value = -1;
    } finally {
      _progressNotifiers.remove(lessonId);
      _cancelTokens.remove(lessonId);
    }
  }

  /// Cancels an active download.
  void cancelDownload(String lessonId) {
    _cancelTokens[lessonId]?.cancel('User cancelled');
    _progressNotifiers.remove(lessonId);
    _cancelTokens.remove(lessonId);
  }

  /// Deletes the locally downloaded video for a lesson.
  Future<void> deleteDownload(String lessonId) async {
    final registry = await _loadRegistry();
    final info = registry.remove(lessonId);
    await _saveRegistry(registry);
    if (info != null && File(info.localPath).existsSync()) {
      try {
        await File(info.localPath).delete();
      } catch (_) {}
    }
  }

  /// Returns total storage used by downloaded videos in bytes.
  Future<int> getTotalStorageUsed() async {
    final registry = await _loadRegistry();
    int total = 0;
    for (final info in registry.values) {
      final file = File(info.localPath);
      if (file.existsSync()) {
        total += file.lengthSync();
      }
    }
    return total;
  }

  /// Returns a list of all downloaded videos.
  Future<List<VideoDownloadInfo>> getAllDownloads() async {
    final registry = await _loadRegistry();
    final List<VideoDownloadInfo> validDownloads = [];
    bool registryModified = false;

    for (final entry in registry.entries) {
      if (File(entry.value.localPath).existsSync()) {
        validDownloads.add(entry.value);
      } else {
        registryModified = true; // file was deleted externally
      }
    }

    if (registryModified) {
      final newRegistry = Map.fromEntries(validDownloads.map((i) => MapEntry(i.lessonId, i)));
      await _saveRegistry(newRegistry);
    }
    
    // Sort by downloadedAt descending
    validDownloads.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return validDownloads;
  }

  /// Deletes ALL downloaded videos
  Future<void> deleteAllDownloads() async {
    final registry = await _loadRegistry();
    for (final info in registry.values) {
      final file = File(info.localPath);
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
    await _saveRegistry({});
  }

  /// Checks if a URL is a YouTube link (not downloadable directly).
  bool _isYoutubeUrl(String url) {
    return url.contains('youtu.be') || url.contains('youtube.com');
  }

  bool isYoutubeUrl(String url) => _isYoutubeUrl(url);
}
