import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/block_model.dart';
import 'block_widget.dart';

class MiroCanvasWorkspace extends StatelessWidget {
  final GlobalKey canvasKey;
  final MouseCursor canvasCursor;
  final Color canvasBackgroundColor;
  final List<Block> blocks;
  final Offset canvasOffset;
  final double zoomLevel;
  final Block? selectedBlock;
  final Set<String> selectedBlockIds;
  final Block? linkSourceBlock;
  final CustomPainter blockOverlayPainter;
  final CustomPainter linkOverlayPainter;
  final CustomPainter particleOverlayPainter;
  final List<Widget> overlayWidgets;
  final ValueChanged<PointerHoverEvent> onHover;
  final ValueChanged<PointerExitEvent> onExit;
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
  final void Function(Block block, DragDownDetails details) onBlockPanDown;
  final void Function(Block block, DragUpdateDetails details) onBlockPanUpdate;
  final void Function(Block block) onBlockPanEnd;
  final void Function(Block block, TapDownDetails details) onBlockTapDown;
  final void Function(Block block) onBlockInfoTap;

  const MiroCanvasWorkspace({
    super.key,
    required this.canvasKey,
    required this.canvasCursor,
    required this.canvasBackgroundColor,
    required this.blocks,
    required this.canvasOffset,
    required this.zoomLevel,
    required this.selectedBlock,
    required this.selectedBlockIds,
    required this.linkSourceBlock,
    required this.blockOverlayPainter,
    required this.linkOverlayPainter,
    required this.particleOverlayPainter,
    required this.overlayWidgets,
    required this.onHover,
    required this.onExit,
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
    required this.onBlockInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final paintOrderedBlocks = <Block>[
      ...blocks.where((b) => b.isZone && !b.isStickyNote),
      ...blocks.where((b) => !b.isZone),
      ...blocks.where((b) => b.isStickyNote),
    ];

    return MouseRegion(
      cursor: canvasCursor,
      onHover: onHover,
      onExit: onExit,
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
        child: RepaintBoundary(
          key: canvasKey,
          child: Stack(
            children: [
              CustomPaint(
                foregroundPainter: blockOverlayPainter,
                child: Container(
                  color: canvasBackgroundColor,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanStart: onCanvasPrimaryDragStart,
                          onPanUpdate: onCanvasPrimaryDragUpdate,
                          onPanEnd: onCanvasPrimaryDragEnd,
                          onTapDown: onCanvasTapDown,
                          onSecondaryTapDown: onCanvasSecondaryTapDown,
                        ),
                      ),
                      ...paintOrderedBlocks.map((block) {
                        if (block.isZone) {
                          return Positioned(
                            left:
                                block.position.dx * zoomLevel + canvasOffset.dx,
                            top:
                                block.position.dy * zoomLevel + canvasOffset.dy,
                            width: block.size.width * zoomLevel,
                            height: block.size.height * zoomLevel,
                            child: IgnorePointer(
                              ignoring: true,
                              child: BlockWidget(
                                block: block,
                                isSelected:
                                    selectedBlock == block ||
                                    selectedBlockIds.contains(block.id),
                                zoomLevel: zoomLevel,
                                onInfoTap: null,
                              ),
                            ),
                          );
                        }

                        return Positioned(
                          left: block.position.dx * zoomLevel + canvasOffset.dx,
                          top: block.position.dy * zoomLevel + canvasOffset.dy,
                          width: block.size.width * zoomLevel,
                          height: block.size.height * zoomLevel,
                          child: MouseRegion(
                            cursor:
                                selectedBlock == block ||
                                    selectedBlockIds.contains(block.id)
                                ? SystemMouseCursors.move
                                : SystemMouseCursors.click,
                            child: Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: (event) {
                                if (isSecondaryButtonPressed(event.buttons)) {
                                  onStartLinkingForBlock(block);
                                  onUpdateLinkPreviewFromGlobal(event.position);
                                }
                              },
                              onPointerMove: (event) {
                                if (!isSecondaryButtonPressed(event.buttons)) {
                                  return;
                                }
                                if (linkSourceBlock != null) {
                                  onUpdateLinkPreviewFromGlobal(event.position);
                                }
                              },
                              onPointerUp: (event) {
                                if (linkSourceBlock != null) {
                                  onFinishLinkingAtGlobal(event.position);
                                }
                              },
                              child: GestureDetector(
                                onPanDown: (details) =>
                                    onBlockPanDown(block, details),
                                onPanUpdate: (details) =>
                                    onBlockPanUpdate(block, details),
                                onPanEnd: (_) => onBlockPanEnd(block),
                                onTapDown: (details) =>
                                    onBlockTapDown(block, details),
                                child: BlockWidget(
                                  block: block,
                                  isSelected:
                                      selectedBlock == block ||
                                      selectedBlockIds.contains(block.id),
                                  zoomLevel: zoomLevel,
                                  onInfoTap: () => onBlockInfoTap(block),
                                ),
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
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: RepaintBoundary(
                    child: CustomPaint(foregroundPainter: linkOverlayPainter),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      foregroundPainter: particleOverlayPainter,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
