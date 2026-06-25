import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../block_model.dart';
import '../block_widget.dart';

class MiroCanvasWorkspace extends StatelessWidget {
  final GlobalKey canvasKey;
  final Color canvasBackgroundColor;
  final List<Block> blocks;
  final Offset canvasOffset;
  final double zoomLevel;
  final Block? selectedBlock;
  final Set<String> selectedBlockIds;
  final Block? linkSourceBlock;
  final CustomPainter foregroundPainter;
  final List<Widget> overlayWidgets;
  final ValueChanged<PointerHoverEvent> onHover;
  final ValueChanged<PointerSignalEvent> onPointerSignal;
  final ValueChanged<PointerDownEvent> onCanvasSecondaryDragStart;
  final ValueChanged<PointerMoveEvent> onCanvasSecondaryDragUpdate;
  final ValueChanged<PointerUpEvent> onCanvasSecondaryDragEnd;
  final GestureDragStartCallback onCanvasPrimaryDragStart;
  final GestureDragUpdateCallback onCanvasPrimaryDragUpdate;
  final GestureDragEndCallback onCanvasPrimaryDragEnd;
  final GestureTapDownCallback onCanvasTapDown;
  final GestureTapDownCallback onCanvasSecondaryTapDown;
  final bool Function(int buttons) isSecondaryButtonPressed;
  final void Function(Block block) onStartLinkingForBlock;
  final ValueChanged<Offset> onUpdateLinkPreviewFromGlobal;
  final ValueChanged<Offset> onFinishLinkingAtGlobal;
  final void Function(Block block) onBlockPanDown;
  final void Function(Block block, DragUpdateDetails details) onBlockPanUpdate;
  final void Function(Block block) onBlockPanEnd;
  final void Function(Block block) onBlockTapDown;

  const MiroCanvasWorkspace({
    super.key,
    required this.canvasKey,
    required this.canvasBackgroundColor,
    required this.blocks,
    required this.canvasOffset,
    required this.zoomLevel,
    required this.selectedBlock,
    required this.selectedBlockIds,
    required this.linkSourceBlock,
    required this.foregroundPainter,
    required this.overlayWidgets,
    required this.onHover,
    required this.onPointerSignal,
    required this.onCanvasSecondaryDragStart,
    required this.onCanvasSecondaryDragUpdate,
    required this.onCanvasSecondaryDragEnd,
    required this.onCanvasPrimaryDragStart,
    required this.onCanvasPrimaryDragUpdate,
    required this.onCanvasPrimaryDragEnd,
    required this.onCanvasTapDown,
    required this.onCanvasSecondaryTapDown,
    required this.isSecondaryButtonPressed,
    required this.onStartLinkingForBlock,
    required this.onUpdateLinkPreviewFromGlobal,
    required this.onFinishLinkingAtGlobal,
    required this.onBlockPanDown,
    required this.onBlockPanUpdate,
    required this.onBlockPanEnd,
    required this.onBlockTapDown,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      key: canvasKey,
      cursor: SystemMouseCursors.grab,
      onHover: onHover,
      child: Listener(
        onPointerSignal: onPointerSignal,
        onPointerDown: (event) {
          if (isSecondaryButtonPressed(event.buttons)) {
            onCanvasSecondaryDragStart(event);
          }
        },
        onPointerMove: (event) {
          if (isSecondaryButtonPressed(event.buttons)) {
            onCanvasSecondaryDragUpdate(event);
          }
        },
        onPointerUp: (event) {
          onCanvasSecondaryDragEnd(event);
        },
        child: CustomPaint(
          foregroundPainter: foregroundPainter,
          child: Container(
            color: canvasBackgroundColor,
            child: Stack(
              children: [
                GestureDetector(
                  onPanStart: onCanvasPrimaryDragStart,
                  onPanUpdate: onCanvasPrimaryDragUpdate,
                  onPanEnd: onCanvasPrimaryDragEnd,
                  onTapDown: onCanvasTapDown,
                  onSecondaryTapDown: onCanvasSecondaryTapDown,
                ),
                ...blocks.map((block) {
                  return Positioned(
                    left: block.position.dx * zoomLevel + canvasOffset.dx,
                    top: block.position.dy * zoomLevel + canvasOffset.dy,
                    width: block.size.width * zoomLevel,
                    height: block.size.height * zoomLevel,
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        if (isSecondaryButtonPressed(event.buttons)) {
                          onStartLinkingForBlock(block);
                          onUpdateLinkPreviewFromGlobal(event.position);
                        }
                      },
                      onPointerMove: (event) {
                        if (linkSourceBlock != null &&
                            isSecondaryButtonPressed(event.buttons)) {
                          onUpdateLinkPreviewFromGlobal(event.position);
                        }
                      },
                      onPointerUp: (event) {
                        if (linkSourceBlock != null) {
                          onFinishLinkingAtGlobal(event.position);
                        }
                      },
                      child: GestureDetector(
                        onPanDown: (_) => onBlockPanDown(block),
                        onPanUpdate: (details) =>
                            onBlockPanUpdate(block, details),
                        onPanEnd: (_) => onBlockPanEnd(block),
                        onTapDown: (_) => onBlockTapDown(block),
                        child: BlockWidget(
                          block: block,
                          isSelected:
                              selectedBlock == block ||
                              selectedBlockIds.contains(block.id),
                          zoomLevel: zoomLevel,
                        ),
                      ),
                    ),
                  );
                }),
                ...overlayWidgets,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
