part of '../../widget_miro_like.dart';

extension _MiroLikeWidgetStateCanvasSelectionMethods on _MiroLikeWidgetState {
  Rect _selectionRectFromCanvasPoints(Offset a, Offset b) {
    return Rect.fromLTRB(
      math.min(a.dx, b.dx),
      math.min(a.dy, b.dy),
      math.max(a.dx, b.dx),
      math.max(a.dy, b.dy),
    );
  }

  Rect _canvasRectToModelRect(Rect canvasRect) {
    return Rect.fromLTRB(
      (canvasRect.left - canvasOffset.dx) / zoomLevel,
      (canvasRect.top - canvasOffset.dy) / zoomLevel,
      (canvasRect.right - canvasOffset.dx) / zoomLevel,
      (canvasRect.bottom - canvasOffset.dy) / zoomLevel,
    );
  }

  void _startBoxSelection(Offset canvasPosition) {
    _isBoxSelecting = true;
    _selectionStartCanvas = canvasPosition;
    _selectionCurrentCanvas = canvasPosition;
    selectedLink = null;
    _selectedSequenceLinks.clear();
    _selectedSequenceGroup = null;
  }

  void _updateBoxSelection(Offset canvasPosition) {
    if (!_isBoxSelecting) {
      return;
    }
    _selectionCurrentCanvas = canvasPosition;
  }

  void _finishBoxSelection() {
    final start = _selectionStartCanvas;
    final end = _selectionCurrentCanvas;
    if (!_isBoxSelecting || start == null || end == null) {
      _isBoxSelecting = false;
      _selectionStartCanvas = null;
      _selectionCurrentCanvas = null;
      return;
    }

    final selectionCanvasRect = _selectionRectFromCanvasPoints(start, end);
    final isClickLike =
        selectionCanvasRect.width < 4.0 && selectionCanvasRect.height < 4.0;

    if (!isClickLike) {
      final selectionModelRect = _canvasRectToModelRect(selectionCanvasRect);
      final selectedIds = <String>{};
      for (final block in blocks) {
        final blockRect = Rect.fromLTWH(
          block.position.dx,
          block.position.dy,
          block.size.width,
          block.size.height,
        );
        final isSelectedByLasso = block.isZone
            ? selectionModelRect.contains(blockRect.topLeft) &&
                  selectionModelRect.contains(blockRect.topRight) &&
                  selectionModelRect.contains(blockRect.bottomLeft) &&
                  selectionModelRect.contains(blockRect.bottomRight)
            : selectionModelRect.overlaps(blockRect);
        if (isSelectedByLasso) {
          selectedIds.add(block.id);
        }
      }

      _selectedBlockIds
        ..clear()
        ..addAll(selectedIds);
      selectedBlock = selectedIds.length == 1
          ? blocks.firstWhere((b) => b.id == selectedIds.first)
          : null;
      selectedLink = null;
      _selectedSequenceGroup = null;
    }

    _isBoxSelecting = false;
    _selectionStartCanvas = null;
    _selectionCurrentCanvas = null;
  }

  void _finishSequenceMessageBoxSelection() {
    final start = _selectionStartCanvas;
    final end = _selectionCurrentCanvas;
    if (!_isBoxSelecting || start == null || end == null) {
      _isBoxSelecting = false;
      _selectionStartCanvas = null;
      _selectionCurrentCanvas = null;
      _isSequenceMessageBoxSelecting = false;
      return;
    }

    final selectionCanvasRect = _selectionRectFromCanvasPoints(start, end);
    final isClickLike =
        selectionCanvasRect.width < 4.0 && selectionCanvasRect.height < 4.0;

    if (!isClickLike) {
      final selectedLinks = <BlockLink>{};
      for (final entry in _buildSequenceMessageEntries()) {
        final messageRect = Rect.fromLTRB(
          entry.leftXCanvas,
          entry.topYCanvas,
          entry.rightXCanvas,
          entry.bottomYCanvas,
        ).inflate(16.0);
        if (selectionCanvasRect.overlaps(messageRect)) {
          selectedLinks.add(entry.link);
        }
      }

      _selectedSequenceLinks
        ..clear()
        ..addAll(selectedLinks);
      selectedLink = selectedLinks.length == 1 ? selectedLinks.first : null;
      selectedBlock = null;
      _selectedBlockIds.clear();
      _selectedSequenceGroup = null;
    }

    _isBoxSelecting = false;
    _selectionStartCanvas = null;
    _selectionCurrentCanvas = null;
    _isSequenceMessageBoxSelecting = false;
  }

  List<Widget> _buildSelectionOverlay() {
    final start = _selectionStartCanvas;
    final end = _selectionCurrentCanvas;
    if (!_isBoxSelecting || start == null || end == null) {
      return const [];
    }

    final rect = _selectionRectFromCanvasPoints(start, end);
    return [
      Positioned.fromRect(
        rect: rect,
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.10),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.85),
                width: 1.3,
              ),
            ),
          ),
        ),
      ),
    ];
  }

  void _handleCanvasTapAtCanvasPosition(Offset canvasPosition) {
    if (linkSourceBlock != null) {
      return;
    }

    final modelPosition = Offset(
      (canvasPosition.dx - canvasOffset.dx) / zoomLevel,
      (canvasPosition.dy - canvasOffset.dy) / zoomLevel,
    );

    final hitLink = _findLinkAtCanvasPosition(canvasPosition);
    if (hitLink != null) {
      if (_isSequenceDiagramView && _isCtrlPressed()) {
        selectedBlock = null;
        _selectedBlockIds.clear();
        _selectedSequenceGroup = null;
        if (_selectedSequenceLinks.contains(hitLink)) {
          _selectedSequenceLinks.remove(hitLink);
        } else {
          _selectedSequenceLinks.add(hitLink);
        }
        selectedLink = _selectedSequenceLinks.length == 1
            ? _selectedSequenceLinks.first
            : null;
        return;
      }

      selectedBlock = null;
      _selectedBlockIds.clear();
      selectedLink = hitLink;
      _selectedSequenceLinks
        ..clear()
        ..add(hitLink);
      _selectedSequenceGroup = null;
      return;
    }

    if (_isSequenceDiagramView) {
      final hitGroup = _findSequenceControlGroupAtCanvasPosition(
        canvasPosition,
      );
      if (hitGroup != null) {
        _selectedSequenceGroup = hitGroup;
        selectedBlock = null;
        _selectedBlockIds.clear();
        selectedLink = null;
        _selectedSequenceLinks.clear();
        return;
      }
    }

    for (final block in blocks.reversed) {
      if (block.isZone) {
        continue;
      }
      final blockRect = Rect.fromLTWH(
        block.position.dx,
        block.position.dy,
        block.size.width,
        block.size.height,
      );
      if (blockRect.contains(modelPosition)) {
        if (_isCtrlPressed()) {
          if (_selectedBlockIds.contains(block.id)) {
            _selectedBlockIds.remove(block.id);
          } else {
            _selectedBlockIds.add(block.id);
          }
          selectedBlock = _selectedBlockIds.length == 1
              ? blocks.firstWhere((b) => b.id == _selectedBlockIds.first)
              : null;
        } else {
          selectedBlock = block;
          _selectedBlockIds
            ..clear()
            ..add(block.id);
        }
        selectedLink = null;
        _selectedSequenceLinks.clear();
        _selectedSequenceGroup = null;
        return;
      }
    }

    selectedBlock = null;
    _selectedBlockIds.clear();
    selectedLink = null;
    _selectedSequenceLinks.clear();
    _selectedSequenceGroup = null;
  }
}

