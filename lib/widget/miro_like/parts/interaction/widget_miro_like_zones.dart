part of '../../widget_miro_like.dart';

extension _MiroLikeWidgetStateZoneMethods on _MiroLikeWidgetState {
  void _resizeZoneFromHandle(
    Block zone,
    _ZoneResizeHandle handle,
    DragUpdateDetails details,
  ) {
    final delta = Offset(
      details.delta.dx / zoomLevel,
      details.delta.dy / zoomLevel,
    );

    double left = zone.position.dx;
    double top = zone.position.dy;
    double right = zone.position.dx + zone.size.width;
    double bottom = zone.position.dy + zone.size.height;

    switch (handle) {
      case _ZoneResizeHandle.topLeft:
        left += delta.dx;
        top += delta.dy;
        break;
      case _ZoneResizeHandle.topRight:
        right += delta.dx;
        top += delta.dy;
        break;
      case _ZoneResizeHandle.bottomLeft:
        left += delta.dx;
        bottom += delta.dy;
        break;
      case _ZoneResizeHandle.bottomRight:
        right += delta.dx;
        bottom += delta.dy;
        break;
    }

    if (right - left < _minZoneWidth) {
      if (handle == _ZoneResizeHandle.topLeft ||
          handle == _ZoneResizeHandle.bottomLeft) {
        left = right - _minZoneWidth;
      } else {
        right = left + _minZoneWidth;
      }
    }
    if (bottom - top < _minZoneHeight) {
      if (handle == _ZoneResizeHandle.topLeft ||
          handle == _ZoneResizeHandle.topRight) {
        top = bottom - _minZoneHeight;
      } else {
        bottom = top + _minZoneHeight;
      }
    }

    zone.position = Offset(left, top);
    zone.size = Size(right - left, bottom - top);
  }

  List<Widget> _buildZoneResizeHandles() {
    final zone = selectedBlock;
    if (zone == null || !zone.isZone || _selectedBlockIds.length != 1) {
      return const [];
    }

    final rect = _blockRectCanvas(zone);
    final size = (_zoneHandleSize * zoomLevel).clamp(8.0, 20.0);
    final half = size / 2;

    Widget handle(Offset center, _ZoneResizeHandle type) {
      return Positioned(
        left: center.dx - half,
        top: center.dy - half,
        width: size,
        height: size,
        child: GestureDetector(
          onPanStart: (_) {
            _pushUndoSnapshot();
          },
          onPanUpdate: (details) {
            // ignore: invalid_use_of_protected_member
            setState(() {
              _resizeZoneFromHandle(zone, type, details);
              _markBoardChanged();
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.95),
              border: Border.all(color: Colors.white, width: 1),
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return [
      handle(rect.topLeft, _ZoneResizeHandle.topLeft),
      handle(rect.topRight, _ZoneResizeHandle.topRight),
      handle(rect.bottomLeft, _ZoneResizeHandle.bottomLeft),
      handle(rect.bottomRight, _ZoneResizeHandle.bottomRight),
    ];
  }
}

