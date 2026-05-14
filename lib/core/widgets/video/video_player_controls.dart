import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class VideoPlayerControls extends StatefulWidget {
  final YoutubePlayerController? youtubeController;
  final VideoPlayerController? videoController;
  final bool isYoutube;
  final VoidCallback? onToggleFullScreen;
  final String title;

  const VideoPlayerControls({
    super.key,
    this.youtubeController,
    this.videoController,
    required this.isYoutube,
    this.onToggleFullScreen,
    this.title = '',
  });

  @override
  State<VideoPlayerControls> createState() => _VideoPlayerControlsState();
}

class _VideoPlayerControlsState extends State<VideoPlayerControls> {
  bool _isVisible = true;
  bool _isLocked = false;
  Timer? _hideTimer;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _isVisible = true;
    _isLocked = false;
    _playbackSpeed = 1.0;
    _startHideTimer();

    widget.youtubeController?.addListener(_onControllerUpdate);
    widget.videoController?.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(VideoPlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.youtubeController != widget.youtubeController) {
      oldWidget.youtubeController?.removeListener(_onControllerUpdate);
      widget.youtubeController?.addListener(_onControllerUpdate);
    }
    if (oldWidget.videoController != widget.videoController) {
      oldWidget.videoController?.removeListener(_onControllerUpdate);
      widget.videoController?.addListener(_onControllerUpdate);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.youtubeController?.removeListener(_onControllerUpdate);
    widget.videoController?.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isVisible) {
        setState(() => _isVisible = false);
      }
    });
  }

  void _toggleVisibility() {
    if (_isLocked) return;
    setState(() {
      _isVisible = !_isVisible;
      if (_isVisible) _startHideTimer();
    });
  }

  void _togglePlayPause() {
    if (widget.isYoutube) {
      final controller = widget.youtubeController;
      if (controller == null) return;
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    } else {
      final controller = widget.videoController;
      if (controller == null) return;
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    }
    setState(() {});
    _startHideTimer();
  }

  void _seekRelative(int seconds) {
    HapticFeedback.lightImpact();
    if (widget.isYoutube) {
      final controller = widget.youtubeController;
      if (controller == null) return;
      final current = controller.value.position;
      controller.seekTo(current + Duration(seconds: seconds));
    } else {
      final controller = widget.videoController;
      if (controller == null) return;
      final current = controller.value.position;
      controller.seekTo(current + Duration(seconds: seconds));
    }
    _startHideTimer();
  }

  void _changeSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    if (!widget.isYoutube && widget.videoController != null) {
      widget.videoController!.setPlaybackSpeed(speed);
    }
    Navigator.pop(context);
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    final bool isFullScreen =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final Widget content = GestureDetector(
      onTap: _toggleVisibility,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        setState(() {
          _isLocked = !_isLocked;
          if (!_isLocked) {
            _isVisible = true;
            _startHideTimer();
          }
        });
      },
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (details) {
        if (_isLocked) return;
        final screenWidth = MediaQuery.of(context).size.width;
        if (details.globalPosition.dx < screenWidth / 2) {
          _seekRelative(-10);
        } else {
          _seekRelative(10);
        }
      },
      child: Container(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedOpacity(
              opacity: _isVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(color: Colors.black54),
            ),

            if (_isVisible)
              SafeArea(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Top Bar
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black54, Colors.transparent],
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back,
                                  color: Colors.white),
                              onPressed: () {
                                if (isFullScreen && widget.onToggleFullScreen != null) {
                                  widget.onToggleFullScreen!();
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            if (!_isLocked)
                              Expanded(
                                child: Text(
                                  widget.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (!_isLocked && !widget.isYoutube) ...[
                              _buildSpeedButton(),
                            ],
                            IconButton(
                              icon: Icon(_isLocked ? Icons.lock : Icons.lock_open,
                                  color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _isLocked = !_isLocked;
                                  if (!_isLocked) _startHideTimer();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Center Controls
                    if (!_isLocked)
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildControlButton(
                                Icons.replay_10, () => _seekRelative(-10)),
                            const SizedBox(width: 40),
                            _buildPlayPauseButton(),
                            const SizedBox(width: 40),
                            _buildControlButton(
                                Icons.forward_10, () => _seekRelative(10)),
                          ],
                        ),
                      ),

                    // Bottom Progress Bar
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black54, Colors.transparent],
                          ),
                        ),
                        child: _buildControlBar(isFullScreen),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    return PointerInterceptor(child: content);
  }

  Widget _buildControlBar(bool isFullScreen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: widget.isYoutube
                    ? (widget.youtubeController != null
                        ? ProgressBar(
                            controller: widget.youtubeController!,
                            colors: const ProgressBarColors(
                              playedColor: AppColors.primaryBlue,
                              handleColor: AppColors.primaryBlue,
                              bufferedColor: Colors.white24,
                              backgroundColor: Colors.white12,
                            ),
                          )
                        : const SizedBox.shrink())
                    : (widget.videoController != null
                        ? VideoProgressIndicator(widget.videoController!,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: AppColors.primaryBlue,
                              bufferedColor: Colors.white24,
                              backgroundColor: Colors.white12,
                            ))
                        : const SizedBox.shrink()),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTimeDisplay(),
              if (widget.onToggleFullScreen != null)
                IconButton(
                  icon: Icon(
                    isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () {
                    widget.onToggleFullScreen!();
                    _startHideTimer();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDisplay() {
    String formatDuration(Duration d) {
      String twoDigits(int n) => n.toString().padLeft(2, "0");
      String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
      String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
      if (d.inHours > 0) {
        return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
      }
      return "$twoDigitMinutes:$twoDigitSeconds";
    }

    Duration position = Duration.zero;
    Duration total = Duration.zero;

    if (widget.isYoutube && widget.youtubeController != null) {
      position = widget.youtubeController!.value.position;
      total = widget.youtubeController!.metadata.duration;
    } else if (widget.videoController != null) {
      position = widget.videoController!.value.position;
      total = widget.videoController!.value.duration;
    }

    return Text(
      '${formatDuration(position)} / ${formatDuration(total)}',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            offset: Offset(0, 1),
            blurRadius: 4,
            color: Colors.black,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 36),
      onPressed: onTap,
    );
  }

  Widget _buildPlayPauseButton() {
    final bool isPlaying = widget.isYoutube
        ? (widget.youtubeController?.value.isPlaying ?? false)
        : (widget.videoController?.value.isPlaying ?? false);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.8),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            spreadRadius: 2,
          )
        ]
      ),
      child: IconButton(
        icon: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 48,
        ),
        onPressed: _togglePlayPause,
      ),
    );
  }

  Widget _buildSpeedButton() {
    return TextButton(
      onPressed: () => _showSpeedMenu(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.24),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${_playbackSpeed}x',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showSpeedMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'سرعة التشغيل',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...[0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) => ListTile(
              title: Text('${speed}x', style: const TextStyle(color: Colors.white)),
              trailing: _playbackSpeed == speed 
                ? const Icon(Icons.check, color: AppColors.primaryBlue) 
                : null,
              onTap: () => _changeSpeed(speed),
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
