import 'package:flutter/material.dart';
import 'package:jsonschema/widget/miro_like/layers/miro_block_layer_painter.dart';
import 'package:jsonschema/widget/miro_like/layers/miro_link_layer_painter.dart';
import 'package:jsonschema/widget/miro_like/models/block_model.dart';
import 'package:jsonschema/widget/miro_like/models/link_model.dart';

class MiroCanvasPainter extends CustomPainter {
  final List<Block> blocks;
  final List<BlockLink> links;
  final Offset canvasOffset;
  final double zoomLevel;
  final Block? selectedBlock;
  final BlockLink? selectedLink;
  final Offset? linkingFromPoint;
  final Offset? currentMousePosition;
  final Block? linkSourceBlock;
  final Animation<double>? flowAnimation;
  final List<Offset> pendingInflectionPoints;
  final bool showSequenceParticipantLifelines;
  final String? highlightedSequenceParticipantId;

  MiroCanvasPainter({
    required this.blocks,
    required this.links,
    required this.canvasOffset,
    required this.zoomLevel,
    this.selectedBlock,
    this.selectedLink,
    this.linkingFromPoint,
    this.currentMousePosition,
    this.linkSourceBlock,
    this.flowAnimation,
    this.pendingInflectionPoints = const [],
    this.showSequenceParticipantLifelines = false,
    this.highlightedSequenceParticipantId,
  }) : super(repaint: flowAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    MiroBlockLayerPainter(
      blocks: blocks,
      canvasOffset: canvasOffset,
      zoomLevel: zoomLevel,
      showSequenceParticipantLifelines: showSequenceParticipantLifelines,
      highlightedSequenceParticipantId: highlightedSequenceParticipantId,
    ).paint(canvas, size);

    MiroLinkLayerPainter(
      blocks: blocks,
      links: links,
      canvasOffset: canvasOffset,
      zoomLevel: zoomLevel,
      selectedLink: selectedLink,
      linkingFromPoint: linkingFromPoint,
      currentMousePosition: currentMousePosition,
      linkSourceBlock: linkSourceBlock,
      pendingInflectionPoints: pendingInflectionPoints,
      showSequenceParticipantLifelines: showSequenceParticipantLifelines,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant MiroCanvasPainter oldDelegate) => true;
}
