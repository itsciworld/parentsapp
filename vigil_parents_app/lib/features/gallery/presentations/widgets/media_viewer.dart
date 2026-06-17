import 'package:flutter/material.dart';
import 'package:vigil_parents_app/features/gallery/models/media_model.dart';
import 'package:vigil_parents_app/features/gallery/presentations/widgets/video_player_view.dart';

/// Full-screen, swipeable viewer for a list of media items.
///
/// Images are pinch-to-zoom (via [InteractiveViewer]). Videos show a poster
/// placeholder with metadata — inline playback isn't wired up because the app
/// doesn't bundle a video player package yet.
class MediaViewer extends StatefulWidget {
  final List<MediaItem> items;
  final int initialIndex;

  const MediaViewer({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  static Future<void> open(
    BuildContext context,
    List<MediaItem> items,
    int index,
  ) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) =>
            MediaViewer(items: items, initialIndex: index),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.items[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final item = widget.items[i];
              if (item.isVideo) {
                return Center(
                  child: VideoPlayerView(
                    key: ValueKey(item.id),
                    url: item.url,
                    autoPlay: i == _index,
                  ),
                );
              }
              return Center(
                child: Hero(
                  tag: 'media_${item.id}',
                  child: _ZoomableImage(url: item.url),
                ),
              );
            },
          ),

          // Top bar: close + counter.
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_index + 1} / ${widget.items.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom info panel. Hidden for videos so it doesn't sit on top of
          // the Chewie playback controls.
          if (!current.isVideo)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _InfoPanel(item: current),
            ),
        ],
      ),
    );
  }
}

/// Pinch-to-zoom + double-tap-to-zoom image. Double-tapping zooms into the
/// tapped point (or resets if already zoomed); pinch gestures still work.
class _ZoomableImage extends StatefulWidget {
  final String url;

  const _ZoomableImage({required this.url});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  late final AnimationController _animController;
  Animation<Matrix4>? _animation;

  static const double _zoomScale = 2.5;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
      if (_animation != null) _controller.value = _animation!.value;
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(Matrix4 target) {
    _animation = Matrix4Tween(
      begin: _controller.value,
      end: target,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward(from: 0);
  }

  void _handleDoubleTap(TapDownDetails details) {
    final isZoomed = _controller.value.getMaxScaleOnAxis() > 1.01;
    if (isZoomed) {
      _animateTo(Matrix4.identity());
    } else {
      // Zoom centered on the tapped position.
      final pos = details.localPosition;
      final target = Matrix4.identity()
        ..translateByDouble(
          -pos.dx * (_zoomScale - 1),
          -pos.dy * (_zoomScale - 1),
          0,
          1,
        )
        ..scaleByDouble(_zoomScale, _zoomScale, _zoomScale, 1);
      _animateTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTap,
      onDoubleTap: () {}, // required so onDoubleTapDown fires reliably
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 4,
        child: Image.network(
          widget.url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            );
          },
          errorBuilder: (context, error, stack) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white38,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final MediaItem item;

  const _InfoPanel({required this.item});

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (item.formattedDate.isNotEmpty) item.formattedDate,
      if (item.formattedTime.isNotEmpty) item.formattedTime,
      if (item.width > 0 && item.height > 0) '${item.width}×${item.height}',
      if (item.formattedSize.isNotEmpty) item.formattedSize,
      if (item.isVideo && item.formattedDuration.isNotEmpty)
        item.formattedDuration,
    ].join('  •  ');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              meta,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          if (item.albumName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.folder_outlined,
                  color: Colors.white54,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  item.albumName,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
