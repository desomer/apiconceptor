import 'package:flutter/material.dart';

typedef AreaWidgetBuilder = Widget Function(BuildContext context, Area area);

class Area {
  Area({
    this.id,
    this.data,
    this.size,
    this.min = 0,
    this.max = double.infinity,
    this.flex,
    this.builder,
  });

  final Object? id;
  final Object? data;
  double? size;
  final double min;
  final double max;
  final double? flex;
  final AreaWidgetBuilder? builder;
}

class MultiSplitViewController extends ChangeNotifier {
  MultiSplitViewController({List<Area>? areas}) : _areas = areas ?? <Area>[];

  List<Area> _areas;

  List<Area> get areas => _areas;

  set areas(List<Area> value) {
    _areas = value;
    notifyListeners();
  }

  int get areasCount => _areas.length;

  Area getArea(int index) => _areas[index];

  void refresh() {
    notifyListeners();
  }
}

class MultiSplitView extends StatefulWidget {
  const MultiSplitView({
    super.key,
    this.axis = Axis.horizontal,
    this.controller,
    this.initialAreas,
    this.builder,
    this.resizable = true,
    this.areaClipBehavior = Clip.hardEdge,
    this.dragSensitivity = 1,
  });

  final Axis axis;
  final MultiSplitViewController? controller;
  final List<Area>? initialAreas;
  final AreaWidgetBuilder? builder;
  final bool resizable;
  final Clip areaClipBehavior;
  final double dragSensitivity;

  @override
  State<MultiSplitView> createState() => _MultiSplitViewState();
}

class _MultiSplitViewState extends State<MultiSplitView> {
  late MultiSplitViewController _controller;
  int? _draggingDividerIndex;
  int? _hoverDividerIndex;
  final Map<int, _CollapsedSnapshot> _collapsedByDivider = {};
  double _dragStartPrimaryPos = 0;
  double _dragStartLeftSize = 0;
  double _dragStartRightSize = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        MultiSplitViewController(areas: widget.initialAreas);
    _controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant MultiSplitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller &&
        widget.controller != null) {
      _controller.removeListener(_rebuild);
      _controller = widget.controller!;
      _controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final areas = _controller.areas;
    if (areas.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = widget.axis == Axis.horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;

        final pixelSizes = _resolveSizes(areas, containerSize);
        final children = <Widget>[];

        for (int i = 0; i < areas.length; i++) {
          final area = areas[i];
          final child = (area.builder != null)
              ? area.builder!(context, area)
              : (widget.builder != null)
              ? widget.builder!(context, area)
              : const SizedBox.shrink();

          final sized = widget.axis == Axis.horizontal
              ? SizedBox(width: pixelSizes[i], child: child)
              : SizedBox(height: pixelSizes[i], child: child);

          children.add(
            ClipRect(clipBehavior: widget.areaClipBehavior, child: sized),
          );

          if (i < areas.length - 1) {
            children.add(_buildDivider(i, pixelSizes));
          }
        }

        return widget.axis == Axis.horizontal
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              );
      },
    );
  }

  Widget _buildDivider(int index, List<double> currentSizes) {
    const baseThickness = 8.0;
    const hoverThickness = 8.0;
    const closeButtonSize = 18.0;
    final isHovered = _hoverDividerIndex == index;
    final thickness = isHovered ? hoverThickness : baseThickness;
    final cursor = widget.axis == Axis.horizontal
        ? SystemMouseCursors.resizeColumn
        : SystemMouseCursors.resizeRow;

    if (currentSizes[index] == 0 || currentSizes[index + 1] == 0) {
      return const SizedBox.shrink();
    }

    final divider = MouseRegion(
      cursor: cursor,
      onEnter: (_) {
        setState(() {
          _hoverDividerIndex = index;
        });
      },
      onExit: (_) {
        if (_hoverDividerIndex == index) {
          setState(() {
            _hoverDividerIndex = null;
          });
        }
      },
      child: SizedBox(
        width: widget.axis == Axis.horizontal ? thickness : closeButtonSize,
        height: widget.axis == Axis.vertical ? thickness : closeButtonSize,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              color: Colors.transparent,
              alignment: Alignment.center,
              width: widget.axis == Axis.horizontal ? thickness : null,
              height: widget.axis == Axis.vertical ? thickness : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                width: widget.axis == Axis.horizontal
                    ? (isHovered ? 3 : 1.5)
                    : (isHovered ? 48.0 : 28.0),
                height: widget.axis == Axis.vertical
                    ? (isHovered ? 3 : 1.5)
                    : (isHovered ? 48.0 : 28.0),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: isHovered ? 0.70 : 0.22,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            if (isHovered) Positioned(child: _buildCloseButton(index)),
          ],
        ),
      ),
    );

    if (!widget.resizable) {
      return divider;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: widget.axis == Axis.horizontal
          ? (details) => _beginDrag(index, details.globalPosition, currentSizes)
          : null,
      onHorizontalDragUpdate: widget.axis == Axis.horizontal
          ? (details) => _dragDivider(index, details.globalPosition)
          : null,
      onHorizontalDragEnd: widget.axis == Axis.horizontal
          ? (_) => _endDrag()
          : null,
      onHorizontalDragCancel: widget.axis == Axis.horizontal
          ? () => _endDrag()
          : null,
      onVerticalDragStart: widget.axis == Axis.vertical
          ? (details) => _beginDrag(index, details.globalPosition, currentSizes)
          : null,
      onVerticalDragUpdate: widget.axis == Axis.vertical
          ? (details) => _dragDivider(index, details.globalPosition)
          : null,
      onVerticalDragEnd: widget.axis == Axis.vertical
          ? (_) => _endDrag()
          : null,
      onVerticalDragCancel: widget.axis == Axis.vertical
          ? () => _endDrag()
          : null,
      child: divider,
    );
  }

  Widget _buildCloseButton(int dividerIndex) {
    const visualSize = 18.0;
    const tapTargetSize = 50.0;

    final collapsed = _collapsedByDivider[dividerIndex];
    final closeLeftOrTop =
        collapsed?.closeLeading ?? _preferClosingLeadingArea(dividerIndex);

    final isRestore = collapsed != null;
    final icon = widget.axis == Axis.horizontal
        ? (isRestore
              ? (closeLeftOrTop ? Icons.chevron_right : Icons.chevron_left)
              : (closeLeftOrTop ? Icons.chevron_left : Icons.chevron_right))
        : (isRestore
              ? (closeLeftOrTop ? Icons.expand_more : Icons.expand_less)
              : (closeLeftOrTop ? Icons.expand_less : Icons.expand_more));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggleAdjacentArea(dividerIndex),
      child: SizedBox(
        width: tapTargetSize,
        height: tapTargetSize,
        child: Center(
          child: Material(
            color: const Color(0xCC111827),
            shape: const CircleBorder(),
            elevation: 2,
            child: SizedBox(
              width: visualSize,
              height: visualSize,
              child: Icon(icon, size: 12, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  bool _preferClosingLeadingArea(int dividerIndex) {
    final leadingArea = _controller.getArea(dividerIndex);
    final trailingArea = _controller.getArea(dividerIndex + 1);

    final leadingFixed = leadingArea.flex == null;
    final trailingFixed = trailingArea.flex == null;

    if (leadingFixed && !trailingFixed) {
      return true;
    }
    if (!leadingFixed && trailingFixed) {
      return false;
    }
    return false;
  }

  void _toggleAdjacentArea(int dividerIndex) {
    if (_collapsedByDivider.containsKey(dividerIndex)) {
      _restoreAdjacentArea(dividerIndex);
    } else {
      _collapseAdjacentArea(dividerIndex);
    }
  }

  void _collapseAdjacentArea(int dividerIndex) {
    final closeLeading = _preferClosingLeadingArea(dividerIndex);
    final areaToClose = _controller.getArea(
      closeLeading ? dividerIndex : dividerIndex + 1,
    );
    final sibling = _controller.getArea(
      closeLeading ? dividerIndex + 1 : dividerIndex,
    );

    final beforeClosed = areaToClose.size ?? areaToClose.min;
    final beforeSibling = sibling.size;

    _collapsedByDivider[dividerIndex] = _CollapsedSnapshot(
      closeLeading: closeLeading,
      closedSizeBefore: beforeClosed,
      siblingSizeBefore: beforeSibling,
    );

    final currentSize = beforeClosed;
    areaToClose.size = 2;

    if (sibling.size != null) {
      sibling.size = (sibling.size ?? 0) + currentSize;
    }

    _hoverDividerIndex = null;
    _controller.refresh();
  }

  void _restoreAdjacentArea(int dividerIndex) {
    final snapshot = _collapsedByDivider[dividerIndex];
    if (snapshot == null) {
      return;
    }

    final areaToRestore = _controller.getArea(
      snapshot.closeLeading ? dividerIndex : dividerIndex + 1,
    );
    final sibling = _controller.getArea(
      snapshot.closeLeading ? dividerIndex + 1 : dividerIndex,
    );

    areaToRestore.size = snapshot.closedSizeBefore;

    if (snapshot.siblingSizeBefore != null) {
      sibling.size = snapshot.siblingSizeBefore;
    }

    _collapsedByDivider.remove(dividerIndex);
    _hoverDividerIndex = null;
    _controller.refresh();
  }

  void _beginDrag(
    int dividerIndex,
    Offset globalPosition,
    List<double> currentSizes,
  ) {
    _collapsedByDivider.remove(dividerIndex);
    _draggingDividerIndex = dividerIndex;
    _dragStartPrimaryPos = widget.axis == Axis.horizontal
        ? globalPosition.dx
        : globalPosition.dy;
    _dragStartLeftSize = currentSizes[dividerIndex];
    _dragStartRightSize = currentSizes[dividerIndex + 1];
  }

  void _endDrag() {
    _draggingDividerIndex = null;
  }

  void _dragDivider(int dividerIndex, Offset globalPosition) {
    if (_draggingDividerIndex != dividerIndex) {
      return;
    }

    final primaryPos = widget.axis == Axis.horizontal
        ? globalPosition.dx
        : globalPosition.dy;
    final delta = (primaryPos - _dragStartPrimaryPos) * widget.dragSensitivity;

    final leftArea = _controller.getArea(dividerIndex);
    final rightArea = _controller.getArea(dividerIndex + 1);

    final leftStart = _dragStartLeftSize;
    final rightStart = _dragStartRightSize;

    final leftMin = leftArea.min;
    final leftMax = leftArea.max;
    final rightMin = rightArea.min;
    final rightMax = rightArea.max;

    double newLeft = (leftStart + delta).clamp(leftMin, leftMax);
    double newRight = leftStart + rightStart - newLeft;

    if (newLeft < 2) {
      newLeft = 1;
    }

    if (newRight < 2) {
      newRight = 1;
    }

    if (newRight < rightMin) {
      newRight = rightMin;
      newLeft = leftStart + rightStart - newRight;
    }
    if (newRight > rightMax) {
      newRight = rightMax;
      newLeft = leftStart + rightStart - newRight;
    }

    leftArea.size = newLeft;
    rightArea.size = newRight;
    _controller.refresh();
  }

  List<double> _resolveSizes(List<Area> areas, double containerSize) {
    if (!containerSize.isFinite || containerSize <= 0) {
      return List<double>.filled(areas.length, 0);
    }

    const dividerThickness = 8.0;
    final available = (containerSize - ((areas.length - 1) * dividerThickness))
        .clamp(0.0, double.infinity);

    double fixedTotal = 0;
    double flexTotal = 0;

    for (final a in areas) {
      if (a.size != null) {
        fixedTotal += a.size!;
      } else {
        flexTotal += (a.flex ?? 1);
      }
    }

    final remaining = (available - fixedTotal).clamp(0.0, double.infinity);
    final result = <double>[];

    for (final a in areas) {
      double size;
      if (a.size != null) {
        size = a.size!;
      } else {
        final flex = a.flex ?? 1;
        size = flexTotal > 0
            ? (remaining * (flex / flexTotal))
            : (remaining / areas.length);
      }

      size = size.clamp(a.min, a.max);
      result.add(size);
    }

    final total = result.fold<double>(0, (p, e) => p + e);
    if (total > 0 && total != available) {
      final scale = available / total;
      for (int i = 0; i < result.length; i++) {
        final a = areas[i];
        result[i] = (result[i] * scale).clamp(a.min, a.max);
      }
    }

    return result;
  }
}

class _CollapsedSnapshot {
  _CollapsedSnapshot({
    required this.closeLeading,
    required this.closedSizeBefore,
    required this.siblingSizeBefore,
  });

  final bool closeLeading;
  final double closedSizeBefore;
  final double? siblingSizeBefore;
}
