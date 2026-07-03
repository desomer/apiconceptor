import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
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
    final normalTitleFontSize = 14.0 * textScale;
    if (block.isZone) {
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
      final labelFontSize = 13.0 * textScale;
      final borderWidth = isSelected ? 2.0 : 1.2;

      return Container(
        width: block.size.width,
        height: block.size.height,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: zoneFill,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
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
    final radius = BorderRadius.circular(18);
    final iconBytes = _iconBytes();
    final iconSize = (42.0 * textScale).clamp(30.0, 92.0);
    final infoIconSize = (15.0 * textScale).clamp(1.0, 22.0);

    return Container(
      width: block.size.width,
      height: block.size.height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: colorShadow1.withValues(alpha: 0.42),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: _shiftLightness(baseColor, -0.25).withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: borderColor.withValues(alpha: isSelected ? 0.95 : 0.65),
            width: isSelected ? 2 : 1.2,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _shiftLightness(baseColor, 0.16),
              baseColor,
              _shiftLightness(baseColor, -0.18),
            ],
            stops: const [0.0, 0.48, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
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
                ),
                child: Text(
                  block.title,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: normalTitleFontSize,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? colorBlockTextSelected : colorBlockText,
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
            Positioned(
              right: 8,
              top: 8,
              child: GestureDetector(
                onTap: onInfoTap,
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  Icons.info_outline,
                  color: Colors.white.withValues(alpha: 0.95),
                  size: infoIconSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
