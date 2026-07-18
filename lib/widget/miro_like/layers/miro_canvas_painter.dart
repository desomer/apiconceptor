import 'package:flutter/material.dart';
import 'package:jsonschema/widget/miro_like/layers/miro_block_layer_painter.dart';
import 'package:jsonschema/widget/miro_like/layers/miro_link_layer_painter.dart';
import 'package:jsonschema/widget/miro_like/models/block_model.dart';
import 'package:jsonschema/widget/miro_like/models/link_model.dart';
import 'package:jsonschema/widget/miro_like/widget_miro_like.dart';

class MiroBlockOverlayPainter extends CustomPainter {
  final List<Block> blocks;
  final Offset canvasOffset;
  final double zoomLevel;
  final bool showSequenceParticipantLifelines;
  final String? highlightedSequenceParticipantId;

  MiroBlockOverlayPainter({
    required this.blocks,
    required this.canvasOffset,
    required this.zoomLevel,
    this.showSequenceParticipantLifelines = false,
    this.highlightedSequenceParticipantId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    MiroBlockLayerPainter(
      blocks: blocks,
      canvasOffset: canvasOffset,
      zoomLevel: zoomLevel,
      showSequenceParticipantLifelines: showSequenceParticipantLifelines,
      highlightedSequenceParticipantId: highlightedSequenceParticipantId,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant MiroBlockOverlayPainter oldDelegate) => true;
}

class MiroLinkOverlayPainter extends CustomPainter {
  final List<Block> blocks;
  final List<BlockLink> links;
  final Offset canvasOffset;
  final double zoomLevel;
  final BlockLink? selectedLink;
  final Offset? linkingFromPoint;
  final Offset? currentMousePosition;
  final Block? linkSourceBlock;
  final Animation<double>? flowAnimation;
  final List<Offset> pendingInflectionPoints;
  final bool showSequenceParticipantLifelines;
  final String? detachPreviewLinkId;
  final Offset? detachPreviewCanvasPosition;
  final bool detachPreviewIsSource;
  final ParticleAnimationMode particleAnimationMode;
  final String? hoveredBlockId;
  final String? hoveredLinkId;

  MiroLinkOverlayPainter({
    required this.blocks,
    required this.links,
    required this.canvasOffset,
    required this.zoomLevel,
    this.selectedLink,
    this.linkingFromPoint,
    this.currentMousePosition,
    this.linkSourceBlock,
    this.flowAnimation,
    this.pendingInflectionPoints = const [],
    this.showSequenceParticipantLifelines = false,
    this.detachPreviewLinkId,
    this.detachPreviewCanvasPosition,
    this.detachPreviewIsSource = false,
    this.particleAnimationMode = ParticleAnimationMode.always,
    this.hoveredBlockId,
    this.hoveredLinkId,
  });

  @override
  void paint(Canvas canvas, Size size) {
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
      detachPreviewLinkId: detachPreviewLinkId,
      detachPreviewCanvasPosition: detachPreviewCanvasPosition,
      detachPreviewIsSource: detachPreviewIsSource,
      particleAnimationMode: particleAnimationMode,
      hoveredBlockId: hoveredBlockId,
      hoveredLinkId: hoveredLinkId,
      renderStatic: true,
      renderParticles: false,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant MiroLinkOverlayPainter oldDelegate) => true;
}

class MiroParticleOverlayPainter extends CustomPainter {
  static const double _particleTargetFps = 24.0;
  static final Stopwatch _particleClock = Stopwatch()..start();

  final List<Block> blocks;
  final List<BlockLink> links;
  final Offset canvasOffset;
  final double zoomLevel;
  final BlockLink? selectedLink;
  final Offset? linkingFromPoint;
  final Offset? currentMousePosition;
  final Block? linkSourceBlock;
  final Animation<double>? flowAnimation;
  final List<Offset> pendingInflectionPoints;
  final bool showSequenceParticipantLifelines;
  final String? detachPreviewLinkId;
  final Offset? detachPreviewCanvasPosition;
  final bool detachPreviewIsSource;
  final ParticleAnimationMode particleAnimationMode;
  final String? hoveredBlockId;
  final String? hoveredLinkId;

  MiroParticleOverlayPainter({
    required this.blocks,
    required this.links,
    required this.canvasOffset,
    required this.zoomLevel,
    this.selectedLink,
    this.linkingFromPoint,
    this.currentMousePosition,
    this.linkSourceBlock,
    this.flowAnimation,
    this.pendingInflectionPoints = const [],
    this.showSequenceParticipantLifelines = false,
    this.detachPreviewLinkId,
    this.detachPreviewCanvasPosition,
    this.detachPreviewIsSource = false,
    this.particleAnimationMode = ParticleAnimationMode.always,
    this.hoveredBlockId,
    this.hoveredLinkId,
  }) : super(repaint: flowAnimation);

  double? _quantizedParticlePhaseSeconds() {
    final elapsedSeconds =
        _particleClock.elapsedMicroseconds / Duration.microsecondsPerSecond;
    return (elapsedSeconds * _particleTargetFps).floorToDouble() /
        _particleTargetFps;
  }

  @override
  void paint(Canvas canvas, Size size) {
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
      detachPreviewLinkId: detachPreviewLinkId,
      detachPreviewCanvasPosition: detachPreviewCanvasPosition,
      detachPreviewIsSource: detachPreviewIsSource,
      particleAnimationMode: particleAnimationMode,
      hoveredBlockId: hoveredBlockId,
      hoveredLinkId: hoveredLinkId,
      renderStatic: false,
      renderParticles: true,
      animationPhaseSeconds: _quantizedParticlePhaseSeconds(),
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant MiroParticleOverlayPainter oldDelegate) => true;
}
