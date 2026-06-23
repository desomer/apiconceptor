import 'package:flutter/material.dart';
import 'package:jsonschema/widget/miro_like/block_model.dart';
import 'package:jsonschema/widget/miro_like/widget_miro_like.dart';

class BlockWidget extends StatelessWidget {
  final Block block;
  final bool isSelected;

  const BlockWidget({super.key, required this.block, required this.isSelected});

  Color _shiftLightness(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final shifted = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(shifted).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final paletteColor = kBlockColorMap[block.colorKey] ?? colorBlockBackground;
    final baseColor = isSelected
        ? Color.alphaBlend(colorBlockBackgroundSelected, paletteColor)
        : paletteColor;
    final borderColor = isSelected
        ? colorBlockBorderSelected
        : colorBlockBorder;
    final radius = BorderRadius.circular(18);

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
                        Colors.white.withValues(alpha: 0.20),
                        Colors.white.withValues(alpha: 0.06),
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
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  block.title,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
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
          ],
        ),
      ),
    );
  }
}
