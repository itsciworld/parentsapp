import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Inline network-video player built on `video_player` + `chewie`.
///
/// Handles its own initialization, loading spinner and error fallback so the
/// media viewer can just drop one in for each video page.
class VideoPlayerView extends StatefulWidget {
  final String url;

  /// Only the visible page should auto-play; off-screen pages stay paused.
  final bool autoPlay;

  const VideoPlayerView({super.key, required this.url, this.autoPlay = true});

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _initializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
      );
      _videoController = controller;
      await controller.initialize();

      if (!mounted) {
        controller.dispose();
        return;
      }

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: widget.autoPlay,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        aspectRatio: controller.value.aspectRatio == 0
            ? 16 / 9
            : controller.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.white,
          handleColor: Colors.white,
          bufferedColor: Colors.white38,
          backgroundColor: Colors.white24,
        ),
        errorBuilder: (_, msg) => _errorView(msg),
      );

      setState(() => _initializing = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to play this video';
        _initializing = false;
      });
    }
  }

  @override
  void didUpdateWidget(VideoPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pause when this page scrolls off-screen; resume when it becomes active.
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (widget.autoPlay && !oldWidget.autoPlay) {
      controller.play();
    } else if (!widget.autoPlay && oldWidget.autoPlay) {
      controller.pause();
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Widget _errorView(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.videocam_off_outlined,
            color: Colors.white38,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }

    if (_error != null || _chewieController == null) {
      return _errorView(_error ?? 'Unable to play this video');
    }

    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio == 0
          ? 16 / 9
          : _videoController!.value.aspectRatio,
      child: Chewie(controller: _chewieController!),
    );
  }
}
