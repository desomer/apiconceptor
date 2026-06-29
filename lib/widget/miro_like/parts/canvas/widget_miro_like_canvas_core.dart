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

    for (final other in blocks) {
      if (other.id == movingBlock.id) {
        continue;
      }

      final leftDelta = other.position.dx - proposedPosition.dx;
      final leftDeltaAbs = leftDelta.abs();
      if (leftDeltaAbs < closestLeftDeltaAbs) {
        closestLeftDeltaAbs = leftDeltaAbs;
        closestLeft = other.position.dx;
      }

      final topDelta = other.position.dy - proposedPosition.dy;
      final topDeltaAbs = topDelta.abs();
      if (topDeltaAbs < closestTopDeltaAbs) {
        closestTopDeltaAbs = topDeltaAbs;
        closestTop = other.position.dy;
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
    }
    if (_snapTopModel == null &&
        closestTop != null &&
        closestTopDeltaAbs <= captureDistanceModel) {
      _snapTopModel = closestTop;
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
}

