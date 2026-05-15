import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:quizzly/core/services/video_download_service.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/core/widgets/video/video_player_controls.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:quizzly/core/widgets/video/youtube_player_web_windows.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VideoDownloadButton
// ─────────────────────────────────────────────────────────────────────────────

/// Shows download status and allows download/delete of a video for offline use.
/// Displays nothing for YouTube links (cannot be downloaded directly).
class VideoDownloadButton extends StatefulWidget {
  final String lessonId;
  final String videoUrl;
  /// If true, shows only an icon; otherwise shows a full pill button.
  final bool compact;
  final VoidCallback? onDownloadComplete;

  const VideoDownloadButton({
    super.key,
    required this.lessonId,
    required this.videoUrl,
    this.compact = false,
    this.onDownloadComplete,
  });

  @override
  State<VideoDownloadButton> createState() => _VideoDownloadButtonState();
}

class _VideoDownloadButtonState extends State<VideoDownloadButton>
    with SingleTickerProviderStateMixin {
  final _service = VideoDownloadService();
  VideoDownloadStatus _status = VideoDownloadStatus.notDownloaded;
  ValueNotifier<double>? _progressNotifier;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _checkStatus();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final status = await _service.getStatus(widget.lessonId, widget.videoUrl);
    if (mounted) setState(() => _status = status);
  }

  Future<void> _handleTap() async {
    switch (_status) {
      case VideoDownloadStatus.notDownloaded:
      case VideoDownloadStatus.updateAvailable:
      case VideoDownloadStatus.failed:
        await _startDownload();
        break;
      case VideoDownloadStatus.downloaded:
        _showDeleteDialog();
        break;
      case VideoDownloadStatus.downloading:
        _showCancelDialog();
        break;
    }
  }

  Future<void> _startDownload() async {
    setState(() => _status = VideoDownloadStatus.downloading);
    final notifier = await _service.startDownload(
      lessonId: widget.lessonId,
      videoUrl: widget.videoUrl,
    );
    if (notifier == null) {
      if (mounted) setState(() => _status = VideoDownloadStatus.notDownloaded);
      return;
    }
    setState(() => _progressNotifier = notifier);
    notifier.addListener(() {
      if (!mounted) return;
      if (notifier.value >= 1.0) {
        setState(() {
          _status = VideoDownloadStatus.downloaded;
          _progressNotifier = null;
        });
        widget.onDownloadComplete?.call();
        _showSnack('✅ تم تحميل الدرس للمشاهدة أوفلاين', const Color(0xFF0D9488));
      } else if (notifier.value < 0) {
        setState(() {
          _status = VideoDownloadStatus.failed;
          _progressNotifier = null;
        });
        _showSnack('❌ فشل التحميل، حاول مجدداً', Colors.red);
      }
    });
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.cairo()),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('حذف من الأوفلاين', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Text('هل تريد حذف نسخة الأوفلاين من هذا الدرس؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.deleteDownload(widget.lessonId);
              if (mounted) setState(() => _status = VideoDownloadStatus.notDownloaded);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('حذف', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('إيقاف التحميل', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Text('هل تريد إيقاف تحميل هذا الدرس؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('استمرار', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _service.cancelDownload(widget.lessonId);
              if (mounted) {
                setState(() {
                  _status = VideoDownloadStatus.notDownloaded;
                  _progressNotifier = null;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('إيقاف', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color get _color {
    switch (_status) {
      case VideoDownloadStatus.notDownloaded:    return const Color(0xFF6366F1);
      case VideoDownloadStatus.downloading:      return const Color(0xFF0EA5E9);
      case VideoDownloadStatus.downloaded:       return const Color(0xFF0D9488);
      case VideoDownloadStatus.updateAvailable:  return Colors.orange;
      case VideoDownloadStatus.failed:           return Colors.red;
    }
  }

  String get _label {
    switch (_status) {
      case VideoDownloadStatus.notDownloaded:    return 'تحميل للأوفلاين';
      case VideoDownloadStatus.downloading:      return 'جاري التحميل...';
      case VideoDownloadStatus.downloaded:       return 'متاح أوفلاين ✓';
      case VideoDownloadStatus.updateAvailable:  return 'تحديث متاح';
      case VideoDownloadStatus.failed:           return 'أعد المحاولة';
    }
  }

  Widget _buildIcon() {
    switch (_status) {
      case VideoDownloadStatus.downloading:
        return _progressNotifier != null
            ? ValueListenableBuilder<double>(
                valueListenable: _progressNotifier!,
                builder: (_, p, _) => SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    value: p >= 0 ? p : null,
                    strokeWidth: 2.5,
                    color: _color,
                  ),
                ),
              )
            : SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: _color),
              );
      case VideoDownloadStatus.downloaded:
        return AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) => Opacity(opacity: _pulseAnim.value, child: child),
          child: Icon(Icons.offline_pin_rounded, color: _color, size: 22),
        );
      case VideoDownloadStatus.updateAvailable:
        return Icon(Icons.system_update_alt_rounded, color: _color, size: 22);
      case VideoDownloadStatus.failed:
        return Icon(Icons.error_outline_rounded, color: _color, size: 22);
      case VideoDownloadStatus.notDownloaded:
        return Icon(Icons.download_rounded, color: _color, size: 22);
    }
  }

  @override
  Widget build(BuildContext context) {
    // YouTube videos can't be directly downloaded
    if (_service.isYoutubeUrl(widget.videoUrl)) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _handleTap,
      child: widget.compact
          ? _buildIcon()
          : AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _color.withValues(alpha: 0.35), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildIcon(),
                  const SizedBox(width: 8),
                  if (_status == VideoDownloadStatus.downloading && _progressNotifier != null)
                    ValueListenableBuilder<double>(
                      valueListenable: _progressNotifier!,
                      builder: (_, p, _) => Text(
                        '${(p * 100).clamp(0, 100).toInt()}%',
                        style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: _color),
                      ),
                    )
                  else
                    Text(_label, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: _color)),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OfflineAwareVideoWidget
// Plays the video from local storage if available, otherwise streams from net.
// Wraps the full video player logic (YouTube / MP4 / local file).
// ─────────────────────────────────────────────────────────────────────────────

class OfflineAwareVideoWidget extends StatefulWidget {
  final String lessonId;
  final String videoUrl;
  final String title;
  final double height;
  /// Called when download completes so parent can rebuild if needed.
  final VoidCallback? onDownloadComplete;

  const OfflineAwareVideoWidget({
    super.key,
    required this.lessonId,
    required this.videoUrl,
    required this.title,
    this.height = 220,
    this.onDownloadComplete,
  });

  @override
  State<OfflineAwareVideoWidget> createState() => _OfflineAwareVideoWidgetState();
}

class _OfflineAwareVideoWidgetState extends State<OfflineAwareVideoWidget>
    with SingleTickerProviderStateMixin {
  final _service = VideoDownloadService();
  String? _localPath;
  bool _resolved = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _resolveSource();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _resolveSource() async {
    final path = await _service.getLocalPath(widget.lessonId);
    if (mounted) {
      setState(() {
        _localPath = (path != null && File(path).existsSync()) ? path : null;
        _resolved = true;
      });
    }
  }

  bool get _isYoutube =>
      widget.videoUrl.contains('youtu.be') || widget.videoUrl.contains('youtube.com');

  @override
  Widget build(BuildContext context) {
    if (!_resolved) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Video Player ────────────────────────────────────────────────
        Stack(
          children: [
            _buildPlayer(),
            // Offline badge
            if (_localPath != null)
              Positioned(
                top: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.offline_pin_rounded, color: Colors.white, size: 11),
                      const SizedBox(width: 4),
                      Text('أوفلاين', style: GoogleFonts.cairo(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        // ── Download Button ─────────────────────────────────────────────
        if (!_isYoutube) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: VideoDownloadButton(
              lessonId: widget.lessonId,
              videoUrl: widget.videoUrl,
              compact: false,
              onDownloadComplete: () {
                _resolveSource(); // refresh to use local path
                widget.onDownloadComplete?.call();
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlayer() {
    final effectiveUrl = _localPath != null ? 'file://$_localPath' : widget.videoUrl;
    return _EmbeddedVideoPlayer(
      key: ValueKey(effectiveUrl),
      videoUrl: effectiveUrl,
      title: widget.title,
      height: widget.height,
      pulseController: _pulseCtrl,
      pulseAnimation: _pulseAnim,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal self-contained video player (mirrors VideoPreviewWidget behaviour
// but also supports file:// URIs for offline playback)
// ─────────────────────────────────────────────────────────────────────────────

class _EmbeddedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String title;
  final double height;
  final AnimationController pulseController;
  final Animation<double> pulseAnimation;

  const _EmbeddedVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.height,
    required this.pulseController,
    required this.pulseAnimation,
  });

  @override
  State<_EmbeddedVideoPlayer> createState() => _EmbeddedVideoPlayerState();
}

class _EmbeddedVideoPlayerState extends State<_EmbeddedVideoPlayer> {
  YoutubePlayerController? _ytCtrl;
  VideoPlayerController? _vpCtrl;
  ChewieController? _chewieCtrl;
  String? _videoId;
  bool _isYoutube = false;
  bool _hasStarted = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void dispose() {
    _ytCtrl?.dispose();
    _vpCtrl?.dispose();
    _chewieCtrl?.dispose();
    super.dispose();
  }

  void _initPlayer() {
    final url = widget.videoUrl;
    if (url.isEmpty) return;

    final isYt = url.contains('youtu.be') || url.contains('youtube.com');
    final isLocal = url.startsWith('file://');

    if (isYt) {
      _isYoutube = true;
      _videoId = YoutubePlayer.convertUrlToId(url);
      if (_videoId != null && _videoId!.contains('?')) {
        _videoId = _videoId!.split('?').first;
      }
      if (_videoId != null && !kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
        _ytCtrl = YoutubePlayerController(
          initialVideoId: _videoId!,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            forceHD: true,
            enableCaption: false,
            hideControls: true,
            hideThumbnail: true,
            useHybridComposition: true,
          ),
        );
      }
      return;
    }

    _isYoutube = false;
    if (isLocal) {
      // Local file
      final localPath = url.replaceFirst('file://', '');
      _vpCtrl = VideoPlayerController.file(File(localPath));
    } else {
      _vpCtrl = VideoPlayerController.networkUrl(Uri.parse(url));
    }

    _vpCtrl!.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _chewieCtrl = ChewieController(
          videoPlayerController: _vpCtrl!,
          autoPlay: false,
          looping: false,
          aspectRatio: _vpCtrl!.value.aspectRatio,
          placeholder: Container(color: Colors.black),
        );
      });
    }).catchError((e) {
      debugPrint('[OfflineAwareVideoWidget] init error: $e');
    });
  }

  void _startPlayback() {
    setState(() => _hasStarted = true);
    widget.pulseController.stop();
    _ytCtrl?.play();
    _vpCtrl?.play();
  }

  void _enterFullScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenPage(
          isYoutube: _isYoutube,
          ytCtrl: _ytCtrl,
          vpCtrl: _vpCtrl,
          chewieCtrl: _chewieCtrl,
          title: widget.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useWebYt = _isYoutube && (kIsWeb || defaultTargetPlatform == TargetPlatform.windows);

    Widget player;
    if (_isYoutube && !useWebYt && _ytCtrl != null) {
      player = Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: YoutubePlayer(controller: _ytCtrl!, showVideoProgressIndicator: false),
        ),
      );
    } else if (_isYoutube && useWebYt && _videoId != null) {
      player = YoutubePlayerWebWindows(videoId: _videoId!, height: widget.height);
    } else if (_chewieCtrl != null && _isInitialized) {
      player = Center(
        child: AspectRatio(
          aspectRatio: _vpCtrl!.value.aspectRatio,
          child: Chewie(controller: _chewieCtrl!),
        ),
      );
    } else {
      player = Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_hasStarted) player,
            if (_hasStarted)
              VideoPlayerControls(
                isYoutube: _isYoutube,
                youtubeController: _ytCtrl,
                videoController: _vpCtrl,
                onToggleFullScreen: _enterFullScreen,
                title: widget.title,
              ),
            if (!_hasStarted)
              GestureDetector(
                onTap: _startPlayback,
                child: Container(
                  color: Colors.black87,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_isYoutube && _videoId != null)
                        CachedNetworkImage(
                          imageUrl: 'https://img.youtube.com/vi/$_videoId/hqdefault.jpg',
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(color: Colors.black87),
                          errorWidget: (_, _, _) => Container(color: Colors.black87),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.6)],
                          ),
                        ),
                      ),
                      Center(
                        child: AnimatedBuilder(
                          animation: widget.pulseAnimation,
                          builder: (_, child) => Transform.scale(scale: widget.pulseAnimation.value, child: child),
                          child: Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryBlue.withValues(alpha: 0.9),
                              boxShadow: [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 4)],
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12, left: 0, right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              widget.videoUrl.startsWith('file://') ? '📱 أوفلاين - اضغط للمشاهدة' : 'اضغط للمشاهدة',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenPage extends StatelessWidget {
  final bool isYoutube;
  final YoutubePlayerController? ytCtrl;
  final VideoPlayerController? vpCtrl;
  final ChewieController? chewieCtrl;
  final String title;

  const _FullScreenPage({
    required this.isYoutube,
    this.ytCtrl,
    this.vpCtrl,
    this.chewieCtrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    Widget player;
    if (isYoutube && ytCtrl != null) {
      player = Center(child: AspectRatio(aspectRatio: 16 / 9, child: YoutubePlayer(controller: ytCtrl!)));
    } else if (chewieCtrl != null && vpCtrl != null) {
      player = Center(child: AspectRatio(
        aspectRatio: vpCtrl!.value.isInitialized ? vpCtrl!.value.aspectRatio : 16 / 9,
        child: Chewie(controller: chewieCtrl!),
      ));
    } else {
      player = Container(color: Colors.black);
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (_, _) {
        ytCtrl?.pause();
        vpCtrl?.pause();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            player,
            VideoPlayerControls(
              isYoutube: isYoutube,
              youtubeController: ytCtrl,
              videoController: vpCtrl,
              onToggleFullScreen: () => Navigator.pop(context),
              title: title,
            ),
          ],
        ),
      ),
    );
  }
}
