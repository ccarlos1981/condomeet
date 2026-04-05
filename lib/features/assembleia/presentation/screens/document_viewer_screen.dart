import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:condomeet/core/design_system/app_colors.dart';

class DocumentViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  const DocumentViewerScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  late bool _isPdf;
  late bool _isVideo;
  
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoadingVideo = false;
  bool _videoError = false;

  @override
  void initState() {
    super.initState();
    
    // Simplistic check based on URL extension headers or known types
    final lowerUrl = widget.url.toLowerCase();
    _isPdf = lowerUrl.contains('.pdf');
    _isVideo = lowerUrl.contains('.mp4') || lowerUrl.contains('.webm') || lowerUrl.contains('.mov');

    if (!_isPdf && !_isVideo) {
      // Fallback inference (often gravacoes are webm)
      if (lowerUrl.contains('gravacao')) {
        _isVideo = true;
      } else {
        _isPdf = true; // Assumes Edital/Ata are PDFs
      }
    }

    if (_isVideo) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    setState(() {
      _isLoadingVideo = true;
      _videoError = false;
    });

    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        allowFullScreen: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Erro ao reproduzir: $errorMessage',
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      setState(() {
        _isLoadingVideo = false;
      });
    } catch (e) {
      debugPrint('Video init error: $e');
      setState(() {
        _isLoadingVideo = false;
        _videoError = true;
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isVideo ? Colors.black : AppColors.surface,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: _isVideo ? Colors.black : AppColors.surface,
        foregroundColor: _isVideo ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Abrir Externamente',
            onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
          )
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isPdf) {
      return SfPdfViewer.network(
        widget.url,
        canShowScrollHead: true,
        canShowScrollStatus: true,
      );
    } 
    
    if (_isVideo) {
      if (_isLoadingVideo) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }
      
      if (_videoError) {
        return _buildErrorState();
      }

      if (_chewieController != null) {
        return Chewie(controller: _chewieController!);
      }
    }

    return _buildErrorState();
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Formato não suportado nativamente pelo seu dispositivo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir no Navegador/Aplicativo Externo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            )
          ],
        ),
      ),
    );
  }
}
