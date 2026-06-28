import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:jsonschema/widget/miro_like/models/block_model.dart';

class MiroBlockLayerPainter {
  final List<Block> blocks;
  final Offset canvasOffset;
  final double zoomLevel;
  final bool showSequenceParticipantLifelines;
  final String? highlightedSequenceParticipantId;

  const MiroBlockLayerPainter({
    required this.blocks,
    required this.canvasOffset,
    required this.zoomLevel,
    required this.showSequenceParticipantLifelines,
    this.highlightedSequenceParticipantId,
  });

  void paint(Canvas canvas, Size size) {
    _drawDottedGrid(canvas, size);
    if (showSequenceParticipantLifelines) {
      _drawSequenceParticipantLifelines(canvas, size);
    }
  }

  void _drawDottedGrid(Canvas canvas, Size size) {
    const gridSpacingModel = 24.0;
    final gridSpacingCanvas = gridSpacingModel * zoomLevel;
    if (gridSpacingCanvas < 8.0) {
      return;
    }

    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final startX = canvasOffset.dx % gridSpacingCanvas;
    final startY = canvasOffset.dy % gridSpacingCanvas;

    for (double x = startX; x < size.width; x += gridSpacingCanvas) {
      for (double y = startY; y < size.height; y += gridSpacingCanvas) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }

  void _drawSequenceParticipantLifelines(Canvas canvas, Size size) {
    final lifelinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = (1.2 * zoomLevel).clamp(0.8, 2.2)
      ..style = PaintingStyle.stroke;

    final dashLength = (12.0 * zoomLevel).clamp(6.0, 18.0);
    final gapLength = (8.0 * zoomLevel).clamp(4.0, 14.0);
    final yMax = size.height + 400;

    for (final block in blocks) {
      if (block.isZone) {
        continue;
      }

      final rect = _blockRectCanvas(block);
      final x = rect.center.dx;
      var y = rect.bottom + (8.0 * zoomLevel);

      if (highlightedSequenceParticipantId == block.id) {
        final yStart = rect.bottom + (8.0 * zoomLevel);
        final haloColor = const Color.fromARGB(255, 56, 142, 60);

        canvas.drawCircle(
          Offset(x, yStart),
          (11.0 * zoomLevel).clamp(6.0, 18.0),
          Paint()
            ..color = haloColor.withValues(alpha: 0.28)
            ..style = PaintingStyle.fill,
        );

        canvas.drawLine(
          Offset(x, yStart),
          Offset(x, yMax),
          Paint()
            ..color = haloColor.withValues(alpha: 0.42)
            ..strokeWidth = (1.8 * zoomLevel).clamp(1.0, 3.0)
            ..style = PaintingStyle.stroke,
        );
      }

      while (y < yMax) {
        final segmentEnd = math.min(y + dashLength, yMax);
        canvas.drawLine(Offset(x, y), Offset(x, segmentEnd), lifelinePaint);
        y += dashLength + gapLength;
      }
    }
  }

  Rect _blockRectCanvas(Block block) {
    return Rect.fromLTWH(
      block.position.dx * zoomLevel + canvasOffset.dx,
      block.position.dy * zoomLevel + canvasOffset.dy,
      block.size.width * zoomLevel,
      block.size.height * zoomLevel,
    );
  }
}
