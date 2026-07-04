part of '../../widget_miro_like.dart';

extension _MiroLikeWidgetStateCanvasCoreMethods on _MiroLikeWidgetState {
  Offset _toCanvasLocal(Offset globalPosition) {
    final renderBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return globalPosition;
    }
    return renderBox.globalToLocal(globalPosition);
  }

  Offset _toModelPosition(Offset globalPosition) {
    final localPosition = _toCanvasLocal(globalPosition);
    return (localPosition - canvasOffset) / zoomLevel;
  }

  Offset _modelToCanvas(Offset modelPoint) {
    return Offset(
      modelPoint.dx * zoomLevel + canvasOffset.dx,
      modelPoint.dy * zoomLevel + canvasOffset.dy,
    );
  }

  void _resetBlockDragSnap() {
    _snapLeftModel = null;
    _snapTopModel = null;
    _dragFreePositionModel = null;
  }

  Offset _applyBlockAlignmentSnap(Block movingBlock, Offset proposedPosition) {
    final captureDistanceModel = _alignmentSnapCaptureDistance / zoomLevel;
    final releaseDistanceModel = _alignmentSnapReleaseDistance / zoomLevel;

    double? closestLeft;
    double closestLeftDeltaAbs = double.infinity;
    double? closestTop;
    double closestTopDeltaAbs = double.infinity;

    final movingWidth = movingBlock.size.width;
    final movingHeight = movingBlock.size.height;

    for (final other in blocks) {
      if (other.id == movingBlock.id) {
        continue;
      }
      // Large subgraph zones should not attract node snap targets.
      if (other.isZone && other.zoneType == BlockZoneType.subgraph) {
        continue;
      }

      final otherLeft = other.position.dx;
      final otherTop = other.position.dy;
      final otherRight = otherLeft + other.size.width;
      final otherBottom = otherTop + other.size.height;
      final otherCenterX = otherLeft + other.size.width / 2;
      final otherCenterY = otherTop + other.size.height / 2;

      final xCandidates = <double>[
        // left-left
        otherLeft,
        // right-right
        otherRight - movingWidth,
        // center-center
        otherCenterX - movingWidth / 2,
      ];

      for (final candidateX in xCandidates) {
        final leftDelta = candidateX - proposedPosition.dx;
        final leftDeltaAbs = leftDelta.abs();
        if (leftDeltaAbs < closestLeftDeltaAbs) {
          closestLeftDeltaAbs = leftDeltaAbs;
          closestLeft = candidateX;
        }
      }

      final yCandidates = <double>[
        // top-top
        otherTop,
        // bottom-bottom
        otherBottom - movingHeight,
        // center-center
        otherCenterY - movingHeight / 2,
      ];

      for (final candidateY in yCandidates) {
        final topDelta = candidateY - proposedPosition.dy;
        final topDeltaAbs = topDelta.abs();
        if (topDeltaAbs < closestTopDeltaAbs) {
          closestTopDeltaAbs = topDeltaAbs;
          closestTop = candidateY;
        }
      }
    }

    if (_snapLeftModel != null &&
        (proposedPosition.dx - _snapLeftModel!).abs() > releaseDistanceModel) {
      _snapLeftModel = null;
    }
    if (_snapTopModel != null &&
        (proposedPosition.dy - _snapTopModel!).abs() > releaseDistanceModel) {
      _snapTopModel = null;
    }

    if (_snapLeftModel == null &&
        closestLeft != null &&
        closestLeftDeltaAbs <= captureDistanceModel) {
      _snapLeftModel = closestLeft;
    } else if (_snapLeftModel != null &&
        closestLeft != null &&
        closestLeftDeltaAbs <= captureDistanceModel) {
      final currentDeltaAbs = (proposedPosition.dx - _snapLeftModel!).abs();
      final isDifferentTarget = (closestLeft - _snapLeftModel!).abs() > 1e-6;
      if (isDifferentTarget && closestLeftDeltaAbs + 0.5 < currentDeltaAbs) {
        _snapLeftModel = closestLeft;
      }
    }
    if (_snapTopModel == null &&
        closestTop != null &&
        closestTopDeltaAbs <= captureDistanceModel) {
      _snapTopModel = closestTop;
    } else if (_snapTopModel != null &&
        closestTop != null &&
        closestTopDeltaAbs <= captureDistanceModel) {
      final currentDeltaAbs = (proposedPosition.dy - _snapTopModel!).abs();
      final isDifferentTarget = (closestTop - _snapTopModel!).abs() > 1e-6;
      if (isDifferentTarget && closestTopDeltaAbs + 0.5 < currentDeltaAbs) {
        _snapTopModel = closestTop;
      }
    }

    return Offset(
      _snapLeftModel ?? proposedPosition.dx,
      _snapTopModel ?? proposedPosition.dy,
    );
  }

  Rect _blockRectCanvas(Block block) {
    return Rect.fromLTWH(
      block.position.dx * zoomLevel + canvasOffset.dx,
      block.position.dy * zoomLevel + canvasOffset.dy,
      block.size.width * zoomLevel,
      block.size.height * zoomLevel,
    );
  }

  double _sequenceLifelineStartCanvasY(Block block) {
    final logicalParticipantHeight = math.min(
      block.size.height,
      _minBlockHeight,
    );
    final logicalBottom =
        (block.position.dy + logicalParticipantHeight) * zoomLevel +
        canvasOffset.dy;
    return logicalBottom + (8.0 * zoomLevel);
  }

  List<Widget> _buildAlignmentSnapGuides() {
    if (_isSequenceDiagramView || _selectedBlockIds.length != 1) {
      return const <Widget>[];
    }
    if (_dragFreePositionModel == null) {
      return const <Widget>[];
    }
    if (_snapLeftModel == null && _snapTopModel == null) {
      return const <Widget>[];
    }

    final selectedId = _selectedBlockIds.first;
    final movingBlock = blocks
        .where((block) => block.id == selectedId)
        .cast<Block?>()
        .firstWhere((block) => block != null, orElse: () => null);
    if (movingBlock == null) {
      return const <Widget>[];
    }

    final snapXCanvas = _snapLeftModel == null
        ? null
        : _snapLeftModel! * zoomLevel + canvasOffset.dx;
    final snapYCanvas = _snapTopModel == null
        ? null
        : _snapTopModel! * zoomLevel + canvasOffset.dy;

    final movingRectCanvas = _blockRectCanvas(movingBlock);
    return <Widget>[
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _AlignmentSnapGuidesPainter(
              snapXCanvas: snapXCanvas,
              snapYCanvas: snapYCanvas,
              movingRectCanvas: movingRectCanvas,
            ),
          ),
        ),
      ),
    ];
  }
}

class _AlignmentSnapGuidesPainter extends CustomPainter {
  final double? snapXCanvas;
  final double? snapYCanvas;
  final Rect movingRectCanvas;

  const _AlignmentSnapGuidesPainter({
    required this.snapXCanvas,
    required this.snapYCanvas,
    required this.movingRectCanvas,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = colorLinkSelected.withValues(alpha: 0.92);
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = colorLinkSelected.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);

    if (snapXCanvas != null) {
      final x = snapXCanvas!.clamp(-size.width, size.width * 2);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), glowPaint);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), guidePaint);
    }

    if (snapYCanvas != null) {
      final y = snapYCanvas!.clamp(-size.height, size.height * 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), glowPaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guidePaint);
    }

    final markerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = colorLinkSelected.withValues(alpha: 0.95);
    if (snapXCanvas != null) {
      final y = movingRectCanvas.center.dy.clamp(0.0, size.height);
      canvas.drawCircle(Offset(snapXCanvas!, y), 3.4, markerPaint);
    }
    if (snapYCanvas != null) {
      final x = movingRectCanvas.center.dx.clamp(0.0, size.width);
      canvas.drawCircle(Offset(x, snapYCanvas!), 3.4, markerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AlignmentSnapGuidesPainter oldDelegate) {
    return oldDelegate.snapXCanvas != snapXCanvas ||
        oldDelegate.snapYCanvas != snapYCanvas ||
        oldDelegate.movingRectCanvas != movingRectCanvas;
  }
}
