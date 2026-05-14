import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import 'video_player_controls.dart';
import 'youtube_player_web_windows.dart';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_explode;

class VideoPreviewWidget extends StatefulWidget {
  final String videoUrl;
  final bool showHeader;
  final String? thumbnailUrl;
  final String title;

  const VideoPreviewWidget({
    super.key,
    required this.videoUrl,
    this.showHeader = true,
    this.thumbnailUrl,
    this.onDurationFetched,
    this.height = 200,
    this.title = 'معاينة الفيديو',
  });
  
  final Function(Duration)? onDurationFetched;
  final double height;

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget>
    with SingleTickerProviderStateMixin {
  YoutubePlayerController? _youtubeController;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  
  String? _videoId;
  bool _isYoutube = false;
  bool _hasStarted = false;
  bool _isInitialized = false;
  final GlobalKey _youtubePlayerKey = GlobalKey();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(VideoPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _youtubeController?.removeListener(_onControllerChange);
      _youtubeController?.dispose();
      _videoController?.dispose();
      _chewieController?.dispose();
      _youtubeController = null;
      _videoController = null;
      _chewieController = null;
      _isInitialized = false;
      _hasStarted = false;
      _initPlayer();
      if (mounted) setState(() {});
    }
  }

  void _initPlayer() {
    final url = widget.videoUrl;
    if (url.isEmpty) return;

    if (url.contains('youtu.be') || url.contains('youtube.com')) {
      _isYoutube = true;
      _videoId = YoutubePlayer.convertUrlToId(url);
      if (_videoId != null && _videoId!.contains('?')) {
        _videoId = _videoId!.split('?').first;
      }
      
      if (_videoId != null) {
        if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
          _youtubeController = YoutubePlayerController(
            initialVideoId: _videoId!,
            flags: const YoutubePlayerFlags(
              autoPlay: false,
              mute: false,
              forceHD: true,
              enableCaption: false,
              isLive: false,
              disableDragSeek: false,
              hideControls: true, 
              hideThumbnail: true,
              useHybridComposition: true,
            ),
          )..addListener(_onControllerChange);
        } else {
          _fetchYoutubeDurationWeb();
        }
      }
      return;
    }

    _isYoutube = false;
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(url),
    );

    _videoController!.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: false,
          looping: false,
          aspectRatio: _videoController!.value.aspectRatio,
          placeholder: Container(color: Colors.black),
          errorBuilder: (context, errorMessage) {
            return const Center(
              child: Text('فشل تحميل الفيديو', style: TextStyle(color: Colors.white)),
            );
          },
        );
      });
      widget.onDurationFetched?.call(_videoController!.value.duration);
    }).catchError((e) {
      debugPrint('Error initializing video: $e');
    });
  }

  void _onControllerChange() {
    if (_youtubeController != null && 
        _youtubeController!.value.isReady && 
        _youtubeController!.metadata.duration.inSeconds > 0) {
      widget.onDurationFetched?.call(_youtubeController!.metadata.duration);
    }
  }

  Future<void> _fetchYoutubeDurationWeb() async {
    if (_videoId == null) return;
    try {
      final yt = yt_explode.YoutubeExplode();
      final video = await yt.videos.get(_videoId!);
      if (video.duration != null && mounted) {
        widget.onDurationFetched?.call(video.duration!);
      }
      yt.close();
    } catch (e) {
      debugPrint('Error fetching youtube duration: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _youtubeController?.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _startPlayback() {
    setState(() => _hasStarted = true);
    _pulseController.stop();
    if (_isYoutube) {
      _youtubeController?.play();
    } else {
      _videoController?.play();
    }
  }

  void _enterFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenVideoPage(
          isYoutube: _isYoutube,
          youtubeController: _youtubeController,
          videoController: _videoController,
          chewieController: _chewieController,
          youtubePlayerKey: _youtubePlayerKey,
          title: widget.title,
        ),
      ),
    );
  }

  String get _thumbnailUrl =>
      (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty)
          ? widget.thumbnailUrl!
          : 'https://img.youtube.com/vi/$_videoId/hqdefault.jpg';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isYoutube && _videoId == null) {
      return _buildErrorWidget();
    }

    final bool useExternalYoutube =
        _isYoutube && (kIsWeb || defaultTargetPlatform == TargetPlatform.windows);

    return OrientationBuilder(
      builder: (context, orientation) {
        final bool isLandscape = orientation == Orientation.landscape;

        Widget playerWidget;
        if (_isYoutube && !useExternalYoutube && _youtubeController != null) {
          playerWidget = Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: YoutubePlayer(
                key: _youtubePlayerKey,
                controller: _youtubeController!,
                showVideoProgressIndicator: false,
              ),
            ),
          );
        } else if (useExternalYoutube) {
          playerWidget = YoutubePlayerWebWindows(
            videoId: _videoId!,
            height: widget.height,
          );
        } else {
          if (_chewieController != null &&
              _videoController != null &&
              _isInitialized) {
            playerWidget = Center(
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: Chewie(controller: _chewieController!),
              ),
            );
          } else {
            playerWidget = Container(
              color: Colors.black,
              child: const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primaryBlue)),
            );
          }
        }

        return _buildMainLayout(context, playerWidget, isLandscape, isDark);
      },
    );
  }

  Widget _buildMainLayout(BuildContext context, Widget player, bool isLandscape, bool isDark,
      {bool showThumbnailOverlay = true}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showHeader)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.play_circle_filled_rounded, color: AppColors.primaryBlue.withOpacity(0.7)),
                    const SizedBox(width: 8),
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (_hasStarted && showThumbnailOverlay)
                      GestureDetector(
                        onTap: _enterFullScreen,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.fullscreen_rounded, 
                            color: isDark ? Colors.white70 : AppColors.textSecondary, size: 20),
                        ),
                      ),
                  ],
                ),
              ),

            SizedBox(
              height: widget.height,
              child: ClipRRect(
                borderRadius: widget.showHeader
                    ? const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))
                    : BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_hasStarted || !showThumbnailOverlay) player,
                    if (_hasStarted && showThumbnailOverlay)
                      VideoPlayerControls(
                        isYoutube: _isYoutube,
                        youtubeController: _youtubeController,
                        videoController: _videoController,
                        onToggleFullScreen: _enterFullScreen,
                        title: widget.title,
                      ),
                    if (!_hasStarted && showThumbnailOverlay)
                      GestureDetector(
                        onTap: _startPlayback,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: _thumbnailUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(color: Colors.black87),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.black87,
                                child: const Icon(Icons.image_not_supported, color: Colors.white24, size: 48),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.black.withOpacity(0.15), Colors.black.withOpacity(0.6)],
                                ),
                              ),
                            ),
                            Center(
                              child: AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, child) => Transform.scale(scale: _pulseAnimation.value, child: child),
                                child: Container(
                                  width: 64, height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primaryBlue.withOpacity(0.9),
                                    boxShadow: [BoxShadow(color: AppColors.primaryBlue.withOpacity(0.3), blurRadius: 20, spreadRadius: 4)],
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
                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20)),
                                  child: const Text('اضغط للمشاهدة', 
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
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
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
      ),
      child: const Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 12),
          Expanded(child: Text('رابط الفيديو غير صحيح أو غير مدعوم', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

class _FullScreenVideoPage extends StatelessWidget {
  final bool isYoutube;
  final YoutubePlayerController? youtubeController;
  final VideoPlayerController? videoController;
  final ChewieController? chewieController;
  final GlobalKey? youtubePlayerKey;
  final String title;

  const _FullScreenVideoPage({
    required this.isYoutube,
    this.youtubeController,
    this.videoController,
    this.chewieController,
    this.youtubePlayerKey,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final bool useExternalYoutube = isYoutube && (kIsWeb || defaultTargetPlatform == TargetPlatform.windows);

    Widget playerWidget;
    if (isYoutube && !useExternalYoutube && youtubeController != null) {
      playerWidget = Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: YoutubePlayer(
            key: youtubePlayerKey,
            controller: youtubeController!,
            showVideoProgressIndicator: false,
          ),
        ),
      );
    } else if (isYoutube && useExternalYoutube) {
      final videoId = youtubeController?.initialVideoId;
      if (videoId != null) {
        playerWidget = YoutubePlayerWebWindows(videoId: videoId);
      } else {
        playerWidget = Container(color: Colors.black);
      }
    } else if (videoController != null && chewieController != null) {
      playerWidget = Center(
        child: AspectRatio(
          aspectRatio: videoController!.value.isInitialized ? videoController!.value.aspectRatio : 16 / 9,
          child: Chewie(controller: chewieController!),
        ),
      );
    } else {
      playerWidget = Container(color: Colors.black);
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (isYoutube && youtubeController != null) {
          youtubeController!.pause();
        } else if (videoController != null) {
          videoController!.pause();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            playerWidget,
            VideoPlayerControls(
              isYoutube: isYoutube,
              youtubeController: youtubeController,
              videoController: videoController,
              onToggleFullScreen: () => Navigator.pop(context),
              title: title,
            ),
          ],
        ),
      ),
    );
  }
}
