import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:jsonschema/widget/miro_like/models/block_model.dart';
import 'package:jsonschema/widget/miro_like/widget_miro_like.dart';

class BlockWidget extends StatelessWidget {
  final Block block;
  final bool isSelected;
  final double zoomLevel;
  final VoidCallback? onInfoTap;

  static final Map<String, Uint8List?> _decodedIconCache =
      <String, Uint8List?>{};

  const BlockWidget({
    super.key,
    required this.block,
    required this.isSelected,
    required this.zoomLevel,
    this.onInfoTap,
  });

  Color _shiftLightness(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final shifted = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(shifted).toColor();
  }

  Widget _buildTagIndicators() {
    final validTagKeys = block.tagColorKeys
        .where((key) => kBlockTagColorMap.containsKey(key))
        .toList(growable: false);
    if (validTagKeys.isEmpty) {
      return const SizedBox.shrink();
    }

    final textScale = zoomLevel;
    final indicatorSize = (9.0 * textScale).clamp(4.0, 22.0);
    final spacing = (5.0 * textScale).clamp(2.0, 12.0);
    final indicatorTextSize = (9.0 * textScale).clamp(6.0, 22.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxByHeight =
            ((constraints.maxHeight - 18) / (indicatorSize + spacing))
                .floor()
                .clamp(1, validTagKeys.length);
        final visibleTags = validTagKeys.take(maxByHeight).toList();
        final hiddenCount = validTagKeys.length - visibleTags.length;

        return Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...visibleTags.map((key) {
                  final color = kBlockTagColorMap[key] ?? Colors.white;
                  return Padding(
                    padding: EdgeInsets.only(bottom: spacing),
                    child: Container(
                      width: indicatorSize,
                      height: indicatorSize,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(1.5),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.75),
                          width: 0.8,
                        ),
                      ),
                    ),
                  );
                }),
                if (hiddenCount > 0)
                  Text(
                    '+$hiddenCount',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: indicatorTextSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Uint8List? _iconBytes() {
    String? iconFromJson;
    final rawJson = (block.propertiesJson ?? '').trim();
    if (rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map<String, dynamic>) {
          final dynamicIcon = decoded['iconBase64'];
          if (dynamicIcon != null) {
            final resolved = dynamicIcon.toString().trim();
            if (resolved.isNotEmpty) {
              iconFromJson = resolved;
            }
          }
        }
      } catch (_) {
        // Ignore malformed JSON and fallback to iconBase64 field.
      }
    }

    final raw = (iconFromJson ?? block.iconBase64 ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    if (_decodedIconCache.containsKey(raw)) {
      return _decodedIconCache[raw];
    }

    try {
      final decoded = base64Decode(raw);
      _decodedIconCache[raw] = decoded;
      return decoded;
    } catch (_) {
      _decodedIconCache[raw] = null;
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textScale = zoomLevel;
    final normalTitleFontSize = miroCanvasPrimaryLabelSize(textScale);
    if (block.isZone) {
      if (block.zoneType == BlockZoneType.sticky) {
        final stickyBaseColor =
            kBlockColorMap[block.colorKey] ?? const Color(0xFFEAB308);
        final stickyFill = isSelected
            ? Color.alphaBlend(
                colorBlockBackgroundSelected.withValues(alpha: 0.20),
                stickyBaseColor.withValues(alpha: 0.95),
              )
            : stickyBaseColor.withValues(alpha: 0.96);
        final stickyBorder = isSelected
            ? colorBlockBorderSelected.withValues(alpha: 0.95)
            : _shiftLightness(stickyBaseColor, -0.10).withValues(alpha: 0.80);
        final stickyTextColor = Colors.brown.shade900.withValues(alpha: 0.92);
        final foldColor = Color.alphaBlend(
          Colors.white.withValues(alpha: 0.35),
          stickyBaseColor.withValues(alpha: 0.90),
        );
        final radius = BorderRadius.circular(10);

        return Container(
          width: block.size.width,
          height: block.size.height,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: stickyFill,
            border: Border.all(
              color: stickyBorder,
              width: isSelected ? 2 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 2 * textScale,
                right: 2 * textScale,
                child: CustomPaint(
                  size: Size(34 * textScale, 34 * textScale),
                  painter: _StickyFoldPainter(
                    color: foldColor,
                    borderColor: stickyBorder,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  14 * textScale,
                  14 * textScale,
                  20 * textScale,
                  14 * textScale,
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    block.title,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: miroCanvasPrimaryLabelSize(textScale),
                      fontWeight: FontWeight.w700,
                      color: stickyTextColor,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      final zoneBaseColor =
          kBlockColorMap[block.colorKey] ?? colorBlockBackground;
      final zoneBorderBase = _shiftLightness(zoneBaseColor, 0.20);
      final zoneBorder = isSelected
          ? colorBlockBorderSelected.withValues(alpha: 0.95)
          : zoneBorderBase.withValues(alpha: 0.80);
      final styledZoneFill = isSelected
          ? Color.alphaBlend(
              colorBlockBackgroundSelected.withValues(alpha: 0.45),
              zoneBaseColor.withValues(alpha: 0.22),
            )
          : zoneBaseColor.withValues(alpha: 0.18);
      final zoneFill = block.zoneTransparent
          ? Colors.transparent
          : styledZoneFill;
      final radius = BorderRadius.circular(14);
      final labelPadX = 10.0 * textScale;
      final labelPadTop = 8.0 * textScale;
      final labelFontSize = miroCanvasPrimaryLabelSize(textScale);
      final borderWidth = isSelected ? 2.0 : 1.2;
      final zoneShadow = BoxShadow(
        color: Colors.black.withValues(alpha: 0.18),
        blurRadius: 8,
        offset: const Offset(0, 3),
      );

      return Container(
        width: block.size.width,
        height: block.size.height,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: zoneFill,
          boxShadow: block.zoneTransparent ? const [] : [zoneShadow],
        ),
        child: CustomPaint(
          painter: _ZoneBorderPainter(
            style: block.zoneBorderStyle,
            borderColor: zoneBorder,
            borderWidth: borderWidth,
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.only(left: labelPadX, top: labelPadTop),
              child: FractionallySizedBox(
                widthFactor: 0.78,
                alignment: Alignment.topLeft,
                child: Text(
                  block.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: labelFontSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final paletteColor = kBlockColorMap[block.colorKey] ?? colorBlockBackground;
    final baseColor = isSelected
        ? Color.alphaBlend(colorBlockBackgroundSelected, paletteColor)
        : paletteColor;
    final borderColor = isSelected
        ? colorBlockBorderSelected
        : colorBlockBorder;
    final iconBytes = _iconBytes();
    final iconSize = 42.0 * textScale;
    final infoIconSize = (15.0 * textScale).clamp(1.0, 22.0);
    final titleTopInset = block.nodeShape == BlockNodeShape.person
        ? (14.0 * textScale).clamp(5.0, 26.0)
        : 0.0;

    return SizedBox(
      width: block.size.width,
      height: block.size.height,
      child: CustomPaint(
        painter: _NodeShapePainter(
          shape: block.nodeShape,
          baseColor: baseColor,
          borderColor: borderColor.withValues(alpha: isSelected ? 0.95 : 0.65),
          borderWidth: isSelected ? 2 : 1.2,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipPath(
                clipper: _NodeShapeClipper(shape: block.nodeShape),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(-0.55, -0.8),
                              radius: 1.05,
                              colors: [
                                Colors.white.withValues(alpha: 0.14),
                                Colors.white.withValues(alpha: 0.04),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 10,
                          right: block.tagColorKeys.isEmpty ? 10 : 30,
                          top: titleTopInset,
                        ),
                        child: Text(
                          block.title,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: normalTitleFontSize,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? colorBlockTextSelected
                                : colorBlockText,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                offset: const Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildTagIndicators(),
                    if (iconBytes != null)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          width: iconSize,
                          height: iconSize,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.black.withValues(alpha: 0.12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.memory(
                            iconBytes,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: GestureDetector(
                onTap: onInfoTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.38),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.info_outline,
                    color: Colors.white.withValues(alpha: 0.98),
                    size: infoIconSize,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickyFoldPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  const _StickyFoldPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawLine(
      Offset(0, 0),
      Offset(size.width, size.height),
      Paint()
        ..color = borderColor.withValues(alpha: 0.65)
        ..strokeWidth = 1.1,
    );
  }

  @override
  bool shouldRepaint(covariant _StickyFoldPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.borderColor != borderColor;
  }
}

class _NodeShapeClipper extends CustomClipper<Path> {
  final BlockNodeShape shape;

  const _NodeShapeClipper({required this.shape});

  @override
  Path getClip(Size size) => _buildNodeShapePath(size, shape);

  @override
  bool shouldReclip(covariant _NodeShapeClipper oldClipper) {
    return oldClipper.shape != shape;
  }
}

class _NodeShapePainter extends CustomPainter {
  final BlockNodeShape shape;
  final Color baseColor;
  final Color borderColor;
  final double borderWidth;

  const _NodeShapePainter({
    required this.shape,
    required this.baseColor,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (shape == BlockNodeShape.database) {
      _paintDatabaseNode(canvas, size);
      return;
    }

    if (shape == BlockNodeShape.horizontalTube) {
      _paintHorizontalTubeNode(canvas, size);
      return;
    }

    final path = _buildNodeShapePath(size, shape);
    canvas.drawShadow(path, colorShadow1.withValues(alpha: 0.42), 8.0, false);
    canvas.drawShadow(path, baseColor.withValues(alpha: 0.28), 4.0, false);

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _shiftStaticLightness(baseColor, 0.16),
          baseColor,
          _shiftStaticLightness(baseColor, -0.18),
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..color = borderColor;
    canvas.drawPath(path, borderPaint);

    if (shape == BlockNodeShape.doubleCircle) {
      final inset = math.max(6.0, size.shortestSide * 0.07);
      final inner = _buildNodeShapePath(
        size,
        BlockNodeShape.circle,
        inset: inset,
      );
      canvas.drawPath(inner, borderPaint);
    }

    if (shape == BlockNodeShape.subroutine) {
      final inset = math.max(8.0, size.width * 0.08);
      final left = Offset(inset, borderWidth);
      final leftBottom = Offset(inset, size.height - borderWidth);
      final right = Offset(size.width - inset, borderWidth);
      final rightBottom = Offset(size.width - inset, size.height - borderWidth);
      canvas.drawLine(left, leftBottom, borderPaint);
      canvas.drawLine(right, rightBottom, borderPaint);
    }
  }

  void _paintDatabaseNode(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = borderWidth;
    final rx = _clampSafe(w * 0.5 - stroke, 10.0, w * 0.5);
    final ry = _clampSafe(h * 0.12, 8.0, h * 0.22);
    final left = stroke * 0.9;
    final right = w - stroke * 0.9;
    final topY = ry + stroke;
    final bottomY = h - ry - stroke;

    final bodyPath = Path()
      ..moveTo(left, topY)
      ..arcToPoint(
        Offset(right, topY),
        radius: Radius.elliptical(rx, ry),
        clockwise: false,
      )
      ..lineTo(right, bottomY)
      ..arcToPoint(
        Offset(left, bottomY),
        radius: Radius.elliptical(rx, ry),
        clockwise: false,
      )
      ..close();

    canvas.drawShadow(
      bodyPath,
      colorShadow1.withValues(alpha: 0.45),
      8.0,
      false,
    );

    final bodyFill = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _shiftStaticLightness(baseColor, 0.12),
          baseColor,
          _shiftStaticLightness(baseColor, -0.24),
        ],
        stops: const [0.0, 0.46, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawPath(bodyPath, bodyFill);

    final sideShade = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.10);
    final sideBandW = math.max(6.0, w * 0.06);
    canvas.drawRect(
      Rect.fromLTWH(left, topY, sideBandW, math.max(0.0, bottomY - topY)),
      sideShade,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        right - sideBandW,
        topY,
        sideBandW,
        math.max(0.0, bottomY - topY),
      ),
      sideShade,
    );

    final topCapRect = Rect.fromLTRB(left, stroke, right, stroke + 2 * ry);
    final topCapFill = Paint()
      ..style = PaintingStyle.fill
      ..color = _shiftStaticLightness(baseColor, 0.18).withValues(alpha: 0.95);
    canvas.drawOval(topCapRect, topCapFill);

    final socleHeight = _clampSafe(ry * 1.2, 10.0, h * 0.24);
    final socleTopY = _clampSafe(
      bottomY - ry * 0.06,
      topY + ry,
      h - socleHeight,
    );
    //final socleRect = Rect.fromLTRB(left, socleTopY, right, h - stroke * 0.4);
    final bottomRingRect = Rect.fromLTRB(
      left,
      bottomY - ry,
      right,
      bottomY + ry,
    );

    // Ensure the lower tube slice is visually solid (no hollow/transparent feel).
    final bottomDiskFill = Paint()
      ..style = PaintingStyle.fill
      ..color = _shiftStaticLightness(baseColor, -0.20).withValues(alpha: 0.95);
    canvas.drawOval(bottomRingRect, bottomDiskFill);

    // Bridge the tube and pedestal with a dense body tone.
    final bridgeTop = _clampSafe(bottomY - ry * 0.25, topY, socleTopY);
    final bridgeRect = Rect.fromLTRB(
      left + stroke,
      bridgeTop,
      right - stroke,
      socleTopY,
    );
    final bridgeFill = Paint()
      ..style = PaintingStyle.fill
      ..color = _shiftStaticLightness(baseColor, -0.24).withValues(alpha: 0.96);
    canvas.drawRect(bridgeRect, bridgeFill);

    final neckRect = Rect.fromLTRB(
      left + w * 0.06,
      _clampSafe(bottomY - ry * 0.30, topY, socleTopY),
      right - w * 0.06,
      socleTopY,
    );
    final neckFill = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _shiftStaticLightness(baseColor, -0.06).withValues(alpha: 0.92),
          _shiftStaticLightness(baseColor, -0.22).withValues(alpha: 0.95),
        ],
      ).createShader(neckRect);
    canvas.drawRect(neckRect, neckFill);

    // final socleFill = Paint()
    //   ..style = PaintingStyle.fill
    //   ..color = _shiftStaticLightness(baseColor, -0.30).withValues(alpha: 0.96);
    // canvas.drawOval(socleRect, socleFill);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = borderColor;
    canvas.drawPath(bodyPath, borderPaint);
    canvas.drawOval(topCapRect, borderPaint);
    canvas.drawArc(bottomRingRect, 0, math.pi, false, borderPaint);

    // final neckBorderPaint = Paint()
    //   ..style = PaintingStyle.stroke
    //   ..strokeWidth = math.max(1.0, stroke * 0.9)
    //   ..color = borderColor.withValues(alpha: 0.82);
    // canvas.drawLine(
    //   Offset(neckRect.left, neckRect.top),
    //   Offset(neckRect.left, neckRect.bottom),
    //   neckBorderPaint,
    // );
    // canvas.drawLine(
    //   Offset(neckRect.right, neckRect.top),
    //   Offset(neckRect.right, neckRect.bottom),
    //   neckBorderPaint,
    // );

    // final socleTopArcRect = Rect.fromLTRB(
    //   socleRect.left,
    //   socleRect.top,
    //   socleRect.right,
    //   socleRect.top + 2 * ry,
    // );
    // canvas.drawArc(socleTopArcRect, 0, math.pi, false, neckBorderPaint);
    //canvas.drawArc(socleRect, 0, math.pi, false, borderPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(3.0, stroke * 0.75)
      ..color = borderColor.withValues(alpha: 0.72);
    final yStops = <double>[0.40, 0.57, 0.72, 0.84]
        .map((f) => _clampSafe(h * f, topY + 3.0, bottomY - 2.0))
        .toList(growable: false);
    for (final y in yStops) {
      final ringRect = Rect.fromLTRB(left, y - ry, right, y + ry);
      canvas.drawArc(ringRect, 0, math.pi, false, ringPaint);
    }

    final topHighlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, stroke * 0.60)
      ..color = Colors.white.withValues(alpha: 0.24);
    canvas.drawArc(topCapRect, math.pi, math.pi, false, topHighlight);
  }

  void _paintHorizontalTubeNode(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = borderWidth;
    final outerPath = _buildNodeShapePath(size, BlockNodeShape.horizontalTube);
    canvas.drawShadow(
      outerPath,
      colorShadow1.withValues(alpha: 0.42),
      8.0,
      false,
    );

    final capRadius = _clampSafe(h * 0.30 - stroke * 0.6, 6.0, h * 0.5);
    final leftCenterX = stroke + capRadius;
    final rightCenterX = w - stroke - capRadius;

    if (rightCenterX <= leftCenterX) {
      final fallbackFill = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _shiftStaticLightness(baseColor, 0.18),
            baseColor,
            _shiftStaticLightness(baseColor, -0.24),
          ],
        ).createShader(Offset.zero & size);
      canvas.drawPath(outerPath, fallbackFill);
      final fallbackBorder = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = borderColor;
      canvas.drawPath(outerPath, fallbackBorder);
      return;
    }

    final bodyRect = Rect.fromLTRB(
      leftCenterX,
      stroke,
      rightCenterX,
      h - stroke,
    );
    final leftCapRect = Rect.fromCenter(
      center: Offset(leftCenterX, h / 2),
      width: capRadius * 2,
      height: _clampSafe(h - stroke * 2, 4.0, h),
    );
    final rightCapRect = Rect.fromCenter(
      center: Offset(rightCenterX, h / 2),
      width: capRadius * 2,
      height: _clampSafe(h - stroke * 2, 4.0, h),
    );

    final bodyFill = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _shiftStaticLightness(baseColor, 0.20),
          _shiftStaticLightness(baseColor, 0.04),
          _shiftStaticLightness(baseColor, -0.26),
        ],
        stops: const [0.0, 0.46, 1.0],
      ).createShader(bodyRect);
    canvas.drawRect(bodyRect, bodyFill);

    final separatorCount = bodyRect.width >= h * 1.6 ? 3 : 2;
    final separatorStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, stroke * 0.55)
      ..color = borderColor.withValues(alpha: 0.22);
    final separatorHighlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, stroke * 0.35)
      ..color = Colors.white.withValues(alpha: 0.12);
    for (var i = 1; i <= separatorCount; i++) {
      final t = i / (separatorCount + 1);
      final x = bodyRect.left + bodyRect.width * t;
      canvas.drawLine(
        Offset(x, bodyRect.top + stroke * 0.35),
        Offset(x, bodyRect.bottom - stroke * 0.35),
        separatorStroke,
      );
      canvas.drawLine(
        Offset(x - 0.7, bodyRect.top + stroke * 0.5),
        Offset(x - 0.7, bodyRect.bottom - stroke * 0.5),
        separatorHighlight,
      );
    }

    final leftCapFill = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _shiftStaticLightness(baseColor, 0.18),
          _shiftStaticLightness(baseColor, 0.02),
          _shiftStaticLightness(baseColor, -0.20),
        ],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(leftCapRect);
    canvas.drawOval(leftCapRect, leftCapFill);

    final rightCapFill = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _shiftStaticLightness(baseColor, 0.14),
          _shiftStaticLightness(baseColor, -0.02),
          _shiftStaticLightness(baseColor, -0.24),
        ],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(rightCapRect);
    canvas.drawOval(rightCapRect, rightCapFill);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = borderColor;
    canvas.drawPath(outerPath, borderPaint);

    final seamStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, stroke * 0.85)
      ..color = borderColor.withValues(alpha: 0.55);
    canvas.drawOval(leftCapRect, seamStroke);
    canvas.drawOval(rightCapRect, seamStroke);

    final topHighlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, stroke * 0.65)
      ..color = Colors.white.withValues(alpha: 0.24);
    final highlightY = stroke + (h - stroke * 2) * 0.20;
    canvas.drawLine(
      Offset(leftCenterX + capRadius * 0.15, highlightY),
      Offset(rightCenterX - capRadius * 0.15, highlightY),
      topHighlight,
    );
  }

  @override
  bool shouldRepaint(covariant _NodeShapePainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}

Path _buildNodeShapePath(
  Size size,
  BlockNodeShape shape, {
  double inset = 0.0,
}) {
  final width = math.max(0.0, size.width - inset * 2);
  final height = math.max(0.0, size.height - inset * 2);
  final rect = Rect.fromLTWH(inset, inset, width, height);
  final path = Path();

  switch (shape) {
    case BlockNodeShape.rectangle:
      path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)));
      break;
    case BlockNodeShape.roundedRectangle:
      path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(28)));
      break;
    case BlockNodeShape.stadium:
      path.addRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(math.min(width, height) / 2),
        ),
      );
      break;
    case BlockNodeShape.subroutine:
      path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)));
      break;
    case BlockNodeShape.circle:
    case BlockNodeShape.doubleCircle:
      path.addOval(rect);
      break;
    case BlockNodeShape.database:
      final ry = _clampSafe(height * 0.12, 8.0, height * 0.24);
      final topY = rect.top + ry;
      final bottomY = rect.bottom - ry;
      path
        ..moveTo(rect.left, topY)
        ..arcToPoint(
          Offset(rect.right, topY),
          radius: Radius.elliptical(rect.width / 2, ry),
          clockwise: false,
        )
        ..lineTo(rect.right, bottomY)
        ..arcToPoint(
          Offset(rect.left, bottomY),
          radius: Radius.elliptical(rect.width / 2, ry),
          clockwise: false,
        )
        ..close();
      break;
    case BlockNodeShape.horizontalTube:
      final tubeRadius = math.min(height * 0.30, width * 0.5);
      path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(tubeRadius)));
      break;
    case BlockNodeShape.hexagon:
      final dx = width * 0.18;
      path
        ..moveTo(rect.left + dx, rect.top)
        ..lineTo(rect.right - dx, rect.top)
        ..lineTo(rect.right, rect.center.dy)
        ..lineTo(rect.right - dx, rect.bottom)
        ..lineTo(rect.left + dx, rect.bottom)
        ..lineTo(rect.left, rect.center.dy)
        ..close();
      break;
    case BlockNodeShape.parallelogram:
      final skew = width * 0.12;
      path
        ..moveTo(rect.left + skew, rect.top)
        ..lineTo(rect.right, rect.top)
        ..lineTo(rect.right - skew, rect.bottom)
        ..lineTo(rect.left, rect.bottom)
        ..close();
      break;
    case BlockNodeShape.parallelogramInverted:
      final skew = width * 0.12;
      path
        ..moveTo(rect.left, rect.top)
        ..lineTo(rect.right - skew, rect.top)
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.left + skew, rect.bottom)
        ..close();
      break;
    case BlockNodeShape.trapezoid:
      final topInset = width * 0.12;
      path
        ..moveTo(rect.left + topInset, rect.top)
        ..lineTo(rect.right - topInset, rect.top)
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.left, rect.bottom)
        ..close();
      break;
    case BlockNodeShape.trapezoidInverted:
      final bottomInset = width * 0.12;
      path
        ..moveTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top)
        ..lineTo(rect.right - bottomInset, rect.bottom)
        ..lineTo(rect.left + bottomInset, rect.bottom)
        ..close();
      break;
    case BlockNodeShape.person:
      final headRadius = _clampSafe(
        math.min(width, height) * 0.17,
        10.0,
        math.min(width, height) * 0.25,
      );
      final headCenter = Offset(
        rect.center.dx,
        rect.top + headRadius + height * 0.08,
      );
      final bodyTop = headCenter.dy + headRadius + height * 0.07;
      final bodyRect = Rect.fromLTWH(
        rect.left + width * 0.12,
        bodyTop,
        width * 0.76,
        math.max(6.0, rect.bottom - bodyTop),
      );
      final shoulderRadius = Radius.circular(math.max(8.0, width * 0.25));
      path
        ..addOval(Rect.fromCircle(center: headCenter, radius: headRadius))
        ..addRRect(
          RRect.fromRectAndCorners(
            bodyRect,
            topLeft: shoulderRadius,
            topRight: shoulderRadius,
            bottomLeft: Radius.circular(math.max(6.0, width * 0.12)),
            bottomRight: Radius.circular(math.max(6.0, width * 0.12)),
          ),
        );
      break;
  }

  return path;
}

Color _shiftStaticLightness(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  final shifted = (hsl.lightness + amount).clamp(0.0, 1.0);
  return hsl.withLightness(shifted).toColor();
}

double _clampSafe(double value, double minValue, double maxValue) {
  final lower = math.min(minValue, maxValue);
  final upper = math.max(minValue, maxValue);
  return value.clamp(lower, upper).toDouble();
}

class _ZoneBorderPainter extends CustomPainter {
  final ZoneBorderStyle style;
  final Color borderColor;
  final double borderWidth;

  const _ZoneBorderPainter({
    required this.style,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inset = borderWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      (size.width - borderWidth).clamp(0.0, double.infinity),
      (size.height - borderWidth).clamp(0.0, double.infinity),
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = borderColor
      ..strokeWidth = borderWidth;

    if (style == ZoneBorderStyle.plain) {
      canvas.drawRRect(rrect, paint);
      return;
    }

    double dash;
    double gap;
    switch (style) {
      case ZoneBorderStyle.dashed1_2:
        dash = 4;
        gap = 8;
        break;
      case ZoneBorderStyle.dashed2_2:
        dash = 8;
        gap = 8;
        break;
      case ZoneBorderStyle.dashed2_1:
        dash = 8;
        gap = 4;
        break;
      case ZoneBorderStyle.plain:
        dash = 0;
        gap = 0;
        break;
    }

    final path = Path()..addRRect(rrect);
    final dashed = _dashPath(path, dashLength: dash, gapLength: gap);
    canvas.drawPath(dashed, paint);
  }

  Path _dashPath(
    Path source, {
    required double dashLength,
    required double gapLength,
  }) {
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dashLength).clamp(0.0, metric.length);
        dashed.addPath(metric.extractPath(distance, next), Offset.zero);
        distance += dashLength + gapLength;
      }
    }
    return dashed;
  }

  @override
  bool shouldRepaint(covariant _ZoneBorderPainter oldDelegate) {
    return oldDelegate.style != style ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}
