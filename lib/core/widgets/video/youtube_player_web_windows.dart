import 'package:flutter/material.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';
import 'platform_view_registry_stub.dart'
    if (dart.library.js_util) 'dart:ui_web' as ui_web;

class YoutubePlayerWebWindows extends StatefulWidget {
  final String videoId;
  final double? height;

  const YoutubePlayerWebWindows({
    super.key,
    required this.videoId,
    this.height,
  });

  @override
  State<YoutubePlayerWebWindows> createState() =>
      _YoutubePlayerWebWindowsState();
}

class _YoutubePlayerWebWindowsState extends State<YoutubePlayerWebWindows> {
  static int _viewCounter = 0;
  late String _viewId;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _viewCounter++;
    _viewId = 'youtube-${widget.videoId}-$_viewCounter';

    if (kIsWeb) {
      // Register the view factory for Web
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId,
        (int viewId) {
          final iframe = html.IFrameElement()
            ..src =
                'https://www.youtube.com/embed/${widget.videoId}?autoplay=0&rel=0&modestbranding=1&fs=1&controls=1&disablekb=0&iv_load_policy=3'
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%';

          iframe.setAttribute(
              'allow',
              'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share; fullscreen');

          return iframe;
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double playerHeight = widget.height ??
        (MediaQuery.of(context).size.width * 9 / 16).clamp(200, 500);

    if (kIsWeb) {
      return SizedBox(
        height: playerHeight,
        child: HtmlElementView(viewType: _viewId),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.windows) {
      if (_hasError) {
        return _buildFallbackPlayer(playerHeight);
      }

      return SizedBox(
        height: playerHeight,
        child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(
                'https://www.youtube.com/embed/${widget.videoId}?autoplay=0&rel=0&modestbranding=1&fs=1&controls=1&disablekb=0&iv_load_policy=3'),
          ),
          initialSettings: InAppWebViewSettings(
            useWideViewPort: true,
            loadWithOverviewMode: true,
            javaScriptEnabled: true,
            transparentBackground: true,
            isElementFullscreenEnabled: true,
          ),
          onReceivedError: (controller, request, error) {
            debugPrint('❌ InAppWebView error: ${error.description}');
            if (mounted) {
              setState(() {
                _hasError = true;
                _errorMessage = error.description;
              });
            }
          },
          onWebViewCreated: (controller) {
            debugPrint('✅ InAppWebView created for Windows');
          },
        ),
      );
    }

    return _buildFallbackPlayer(playerHeight);
  }

  /// Fallback when WebView2 is not available or any error occurs
  Widget _buildFallbackPlayer(double height) {
    final youtubeUrl = 'https://www.youtube.com/watch?v=${widget.videoId}';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_circle_outline,
              color: AppColors.primaryBlue.withValues(alpha: 0.5), size: 64),
          const SizedBox(height: 16),
          Text(
            'تعذّر تشغيل الفيديو داخل التطبيق',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage,
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'قد يحتاج جهازك إلى تثبيت Microsoft Edge WebView2',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _openInBrowser(youtubeUrl),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('فتح في المتصفح'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _openInBrowser(
                    'https://aka.ms/microsoft-edge-webview2-runtime'),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('تثبيت WebView2',
                    style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  side: const BorderSide(color: AppColors.primaryBlue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
