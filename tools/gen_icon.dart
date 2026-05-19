// Generates assets/icon/icon.png (1024x1024) and a 512x512 splash icon.
// Run with: dart run tools/gen_icon.dart
//
// The output is fed into flutter_launcher_icons and flutter_native_splash.

import 'dart:io';
import 'dart:math';

import 'package:image/image.dart';

void main() {
  Directory('assets/icon').createSync(recursive: true);
  Directory('assets/splash').createSync(recursive: true);

  final master = _drawIcon(1024, padded: false);
  File('assets/icon/icon.png').writeAsBytesSync(encodePng(master));

  // Foreground for Android adaptive icon (transparent background, padded glyph).
  final fg = _drawIcon(1024, padded: true, transparentBackground: true);
  File('assets/icon/icon_foreground.png').writeAsBytesSync(encodePng(fg));

  // Splash glyph (transparent background, glyph only).
  final splash = _drawIcon(512, padded: true, transparentBackground: true);
  File('assets/splash/splash_icon.png').writeAsBytesSync(encodePng(splash));

  stdout.writeln('Wrote:');
  stdout.writeln('  assets/icon/icon.png');
  stdout.writeln('  assets/icon/icon_foreground.png');
  stdout.writeln('  assets/splash/splash_icon.png');
}

// Earthy palette.
final _stoneDark = ColorRgb8(0x6B, 0x4D, 0x2A);
final _stone = ColorRgb8(0x8A, 0x6A, 0x3F);
final _stoneLight = ColorRgb8(0xC9, 0xA8, 0x70);
final _cream = ColorRgb8(0xF5, 0xEB, 0xD6);
final _ink = ColorRgb8(0x3A, 0x29, 0x18);

Image _drawIcon(
  int size, {
  required bool padded,
  bool transparentBackground = false,
}) {
  final img = Image(width: size, height: size, numChannels: 4);
  // Transparent base.
  fill(img, color: ColorRgba8(0, 0, 0, 0));

  if (!transparentBackground) {
    _fillRoundedRect(img, 0, 0, size, size, size ~/ 5, _stone);
    // Soft top-light gradient by overlaying a translucent cream band.
    _softHighlight(img, size);
  }

  final inset = padded ? size * 0.18 : size * 0.16;
  _drawPin(img, inset, size.toDouble() - inset, size: size);

  return img;
}

void _softHighlight(Image img, int size) {
  // Diagonal highlight from top-left, painted as a soft translucent ellipse.
  final cx = size * 0.25;
  final cy = size * 0.18;
  final rx = size * 0.55;
  final ry = size * 0.35;
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final dx = (x - cx) / rx;
      final dy = (y - cy) / ry;
      final d = dx * dx + dy * dy;
      if (d < 1) {
        final a = ((1 - d) * 60).round();
        _blendPixel(img, x, y, ColorRgba8(255, 250, 235, a));
      }
    }
  }
}

void _drawPin(Image img, double left, double right, {required int size}) {
  // Pin geometry: a circle on top with a triangular tip below.
  final cx = (left + right) / 2;
  final width = right - left;
  final headRadius = width * 0.42;
  final headCy = left + headRadius + width * 0.05;
  final tipY = headCy + headRadius * 2.05;

  // Pin shadow underneath.
  _filledEllipse(
    img,
    cx,
    tipY + width * 0.06,
    width * 0.22,
    width * 0.05,
    ColorRgba8(0, 0, 0, 60),
  );

  // Pin body — filled shape: circle + triangle merged.
  _filledCircle(img, cx, headCy, headRadius, _cream);
  _filledTriangle(
    img,
    cx - headRadius * 0.72,
    headCy + headRadius * 0.55,
    cx + headRadius * 0.72,
    headCy + headRadius * 0.55,
    cx,
    tipY,
    _cream,
  );

  // Outline.
  _strokeCircle(img, cx, headCy, headRadius, _stoneDark, 4);
  _strokeLine(
    img,
    cx - headRadius * 0.72,
    headCy + headRadius * 0.55,
    cx,
    tipY,
    _stoneDark,
    4,
  );
  _strokeLine(
    img,
    cx + headRadius * 0.72,
    headCy + headRadius * 0.55,
    cx,
    tipY,
    _stoneDark,
    4,
  );

  // Stratigraphy bands inside the head — three horizontal stripes
  // clipped to the circle interior.
  final stripeColors = [_stoneDark, _stone, _stoneLight];
  for (int i = 0; i < 3; i++) {
    final yTop = headCy - headRadius * 0.35 + i * headRadius * 0.30;
    final yBottom = yTop + headRadius * 0.18;
    _clippedStripe(img, cx, headCy, headRadius * 0.84, yTop, yBottom,
        stripeColors[i]);
  }

  // Rock-hammer accent: a small diagonal hammer head + handle, ink color.
  final hx = cx - headRadius * 0.30;
  final hy = headCy + headRadius * 0.05;
  final hammerLen = headRadius * 0.55;
  // Handle (diagonal line).
  _strokeLine(
    img,
    hx,
    hy,
    hx + hammerLen * 0.86,
    hy + hammerLen * 0.50,
    _ink,
    max(3, headRadius * 0.06).toInt(),
  );
  // Hammer head perpendicular to handle.
  final headHalf = headRadius * 0.22;
  final dx = -0.50;
  final dy = 0.86;
  _strokeLine(
    img,
    hx - dx * headHalf,
    hy - dy * headHalf,
    hx + dx * headHalf,
    hy + dy * headHalf,
    _ink,
    max(4, headRadius * 0.10).toInt(),
  );
}

// --- low-level drawing helpers (pixel-perfect, anti-alias-light) -----------

void _fillRoundedRect(
    Image img, int x, int y, int w, int h, int r, Color c) {
  for (int j = 0; j < h; j++) {
    for (int i = 0; i < w; i++) {
      final px = x + i;
      final py = y + j;
      final dx = max(0, max(x + r - px, px - (x + w - 1 - r)));
      final dy = max(0, max(y + r - py, py - (y + h - 1 - r)));
      final d = sqrt(dx * dx + dy * dy);
      if (d <= r) {
        // soft edge: 1px AA
        final a = (d > r - 1) ? ((r - d).clamp(0.0, 1.0) * 255).round() : 255;
        _blendPixel(img, px, py,
            ColorRgba8(c.r.toInt(), c.g.toInt(), c.b.toInt(), a));
      }
    }
  }
}

void _filledCircle(Image img, double cx, double cy, double r, Color c) {
  final r2 = r * r;
  final x0 = (cx - r).floor();
  final x1 = (cx + r).ceil();
  final y0 = (cy - r).floor();
  final y1 = (cy + r).ceil();
  for (int y = y0; y <= y1; y++) {
    for (int x = x0; x <= x1; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final d2 = dx * dx + dy * dy;
      if (d2 <= r2) {
        final edge = r - sqrt(d2);
        final a = (edge < 1 ? edge.clamp(0.0, 1.0) * 255 : 255).round();
        _blendPixel(img, x, y,
            ColorRgba8(c.r.toInt(), c.g.toInt(), c.b.toInt(), a));
      }
    }
  }
}

void _filledEllipse(
    Image img, double cx, double cy, double rx, double ry, Color c) {
  for (int y = (cy - ry).floor(); y <= (cy + ry).ceil(); y++) {
    for (int x = (cx - rx).floor(); x <= (cx + rx).ceil(); x++) {
      final ddx = (x - cx) / rx;
      final ddy = (y - cy) / ry;
      final d = ddx * ddx + ddy * ddy;
      if (d <= 1) {
        final a = (c.a.toInt() * (1 - d).clamp(0.0, 1.0)).round();
        _blendPixel(img, x, y,
            ColorRgba8(c.r.toInt(), c.g.toInt(), c.b.toInt(), a));
      }
    }
  }
}

void _filledTriangle(Image img, double x0, double y0, double x1, double y1,
    double x2, double y2, Color c) {
  final minX = [x0, x1, x2].reduce(min).floor();
  final maxX = [x0, x1, x2].reduce(max).ceil();
  final minY = [y0, y1, y2].reduce(min).floor();
  final maxY = [y0, y1, y2].reduce(max).ceil();
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= maxX; x++) {
      if (_pointInTriangle(x + 0.5, y + 0.5, x0, y0, x1, y1, x2, y2)) {
        _blendPixel(img, x, y,
            ColorRgba8(c.r.toInt(), c.g.toInt(), c.b.toInt(), 255));
      }
    }
  }
}

bool _pointInTriangle(double px, double py, double x0, double y0, double x1,
    double y1, double x2, double y2) {
  final d1 = (px - x1) * (y0 - y1) - (x0 - x1) * (py - y1);
  final d2 = (px - x2) * (y1 - y2) - (x1 - x2) * (py - y2);
  final d3 = (px - x0) * (y2 - y0) - (x2 - x0) * (py - y0);
  final hasNeg = d1 < 0 || d2 < 0 || d3 < 0;
  final hasPos = d1 > 0 || d2 > 0 || d3 > 0;
  return !(hasNeg && hasPos);
}

void _strokeCircle(
    Image img, double cx, double cy, double r, Color c, int thickness) {
  final inner = r - thickness;
  final outer = r;
  for (int y = (cy - outer).floor(); y <= (cy + outer).ceil(); y++) {
    for (int x = (cx - outer).floor(); x <= (cx + outer).ceil(); x++) {
      final dx = x - cx;
      final dy = y - cy;
      final d = sqrt(dx * dx + dy * dy);
      if (d <= outer && d >= inner) {
        _blendPixel(img, x, y,
            ColorRgba8(c.r.toInt(), c.g.toInt(), c.b.toInt(), 255));
      }
    }
  }
}

void _strokeLine(Image img, double x0, double y0, double x1, double y1,
    Color c, int thickness) {
  final steps = (max((x1 - x0).abs(), (y1 - y0).abs()) * 2).ceil();
  for (int i = 0; i <= steps; i++) {
    final t = i / steps;
    final x = x0 + (x1 - x0) * t;
    final y = y0 + (y1 - y0) * t;
    _filledCircle(img, x, y, thickness / 2, c);
  }
}

void _clippedStripe(Image img, double cx, double cy, double r, double yTop,
    double yBottom, Color c) {
  final r2 = r * r;
  for (int y = yTop.floor(); y <= yBottom.ceil(); y++) {
    for (int x = (cx - r).floor(); x <= (cx + r).ceil(); x++) {
      final dx = x - cx;
      final dy = y - cy;
      if (dx * dx + dy * dy <= r2) {
        _blendPixel(img, x, y,
            ColorRgba8(c.r.toInt(), c.g.toInt(), c.b.toInt(), 200));
      }
    }
  }
}

void _blendPixel(Image img, int x, int y, ColorRgba8 c) {
  if (x < 0 || y < 0 || x >= img.width || y >= img.height) return;
  final a = c.a / 255.0;
  if (a <= 0) return;
  final p = img.getPixel(x, y);
  final r = (c.r * a + p.r * (1 - a)).round();
  final g = (c.g * a + p.g * (1 - a)).round();
  final b = (c.b * a + p.b * (1 - a)).round();
  final aOut = max(p.a.toInt(), c.a.toInt());
  img.setPixelRgba(x, y, r, g, b, aOut);
}
