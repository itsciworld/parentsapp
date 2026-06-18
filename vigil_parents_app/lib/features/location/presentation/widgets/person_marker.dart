import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';

/// Builds (and caches) a teardrop map pin with a white person icon, used to
/// mark the child's current / latest location. Google Maps markers are bitmaps,
/// so the pin is rendered to a [BitmapDescriptor] on a canvas.
///
/// Anchor the marker at `Offset(0.5, 1.0)` so the pin's tip sits on the
/// coordinate.
class PersonMarker {
  PersonMarker._();

  // Cached per device-pixel-ratio so we only rasterise once.
  static final Map<int, BitmapDescriptor> _cache = {};

  static Future<BitmapDescriptor> icon(BuildContext context) async {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final key = (dpr * 100).round();
    final cached = _cache[key];
    if (cached != null) return cached;
    final bmp = await _draw(dpr);
    _cache[key] = bmp;
    return bmp;
  }

  static Future<BitmapDescriptor> _draw(double dpr) async {
    const w = 46.0; // pin bounding box (logical px)
    const h = 58.0;
    const cx = w / 2;
    const headR = w / 2 - 2; // head radius
    const headCy = headR + 2; // head centre y

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);

    final fill = Paint()..color = AppColors.primary;

    // Soft drop shadow under the head.
    canvas.drawCircle(
      const Offset(cx, headCy + 1.5),
      headR + 1.5,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Pointer triangle down to the coordinate.
    canvas.drawPath(
      Path()
        ..moveTo(cx - headR * 0.55, headCy + headR * 0.6)
        ..lineTo(cx + headR * 0.55, headCy + headR * 0.6)
        ..lineTo(cx, h - 2)
        ..close(),
      fill,
    );

    // White ring + coloured head.
    canvas.drawCircle(const Offset(cx, headCy), headR, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(cx, headCy), headR - 2.5, fill);

    // White person glyph centred in the head.
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.person.codePoint),
        style: TextStyle(
          fontSize: headR * 1.3,
          fontFamily: Icons.person.fontFamily,
          package: Icons.person.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, headCy - tp.height / 2));

    final image = await recorder.endRecording().toImage(
      (w * dpr).ceil(),
      (h * dpr).ceil(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: dpr,
    );
  }
}
