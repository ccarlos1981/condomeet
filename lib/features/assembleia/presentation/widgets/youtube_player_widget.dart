import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Extracts YouTube video ID from various URL formats
String? extractYoutubeId(String url) {
  if (url.isEmpty) return null;

  // youtu.be/VIDEO_ID
  final shortMatch = RegExp(r'youtu\.be/([\w-]{11})').firstMatch(url);
  if (shortMatch != null) return shortMatch.group(1);

  // youtube.com/watch?v=VIDEO_ID
  final longMatch = RegExp(r'[?&]v=([\w-]{11})').firstMatch(url);
  if (longMatch != null) return longMatch.group(1);

  // youtube.com/live/VIDEO_ID
  final liveMatch = RegExp(r'/live/([\w-]{11})').firstMatch(url);
  if (liveMatch != null) return liveMatch.group(1);

  // youtube.com/embed/VIDEO_ID
  final embedMatch = RegExp(r'/embed/([\w-]{11})').firstMatch(url);
  if (embedMatch != null) return embedMatch.group(1);

  // If it's just the video ID itself (11 chars)
  if (RegExp(r'^[\w-]{11}$').hasMatch(url.trim())) return url.trim();

  return null;
}

class YoutubePlayerWidget extends StatefulWidget {
  final String youtubeUrl;
  final bool autoplay;

  const YoutubePlayerWidget({
    super.key,
    required this.youtubeUrl,
    this.autoplay = true,
  });

  @override
  State<YoutubePlayerWidget> createState() => _YoutubePlayerWidgetState();
}

class _YoutubePlayerWidgetState extends State<YoutubePlayerWidget> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    final videoId = extractYoutubeId(widget.youtubeUrl);
    if (videoId == null) return;

    final autoplayParam = widget.autoplay ? '1' : '0';
    final embedUrl = 'https://www.youtube-nocookie.com/embed/$videoId'
        '?autoplay=$autoplayParam&playsinline=1&controls=1&modestbranding=1&rel=0';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(embedUrl));
  }

  @override
  Widget build(BuildContext context) {
    final videoId = extractYoutubeId(widget.youtubeUrl);

    if (videoId == null) {
      return Container(
        height: 200,
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.white54, size: 40),
              SizedBox(height: 8),
              Text(
                'URL do YouTube inválida',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Colors.red),
            ),
        ],
      ),
    );
  }
}
