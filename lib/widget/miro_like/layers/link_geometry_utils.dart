import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:jsonschema/widget/miro_like/models/block_model.dart';
import 'package:jsonschema/widget/miro_like/models/link_model.dart';
import 'package:jsonschema/widget/miro_like/widget_miro_like.dart';

const double _painterAnchorHandleRadius = 6.0;

Offset modelToCanvas(
  Offset modelPoint, {
  required double zoomLevel,
  required Offset canvasOffset,
}) {
  return Offset(
    modelPoint.dx * zoomLevel + canvasOffset.dx,
    modelPoint.dy * zoomLevel + canvasOffset.dy,
  );
}

Rect blockRectCanvas(
  Block block, {
  required double zoomLevel,
  required Offset canvasOffset,
}) {
  return Rect.fromLTWH(
    block.position.dx * zoomLevel + canvasOffset.dx,
    block.position.dy * zoomLevel + canvasOffset.dy,
    block.size.width * zoomLevel,
    block.size.height * zoomLevel,
  );
}

Offset pointOnRectBorderTowards(Rect rect, Offset target) {
  final center = rect.center;
  final vector = target - center;
  if (vector.distanceSquared == 0) {
    return center;
  }

  final halfW = rect.width / 2;
  final halfH = rect.height / 2;
  final scale = 1 / math.max(vector.dx.abs() / halfW, vector.dy.abs() / halfH);
  return center + vector * scale;
}

Offset normalizeAnchorUnit(Offset unit) {
  if (unit.distanceSquared == 0) {
    return const Offset(1, 0);
  }

  final maxAbs = math.max(unit.dx.abs(), unit.dy.abs());
  if (maxAbs == 0) {
    return const Offset(1, 0);
  }
  return unit / maxAbs;
}

Offset anchorSideUnit(Offset unit) {
  final normalized = normalizeAnchorUnit(unit);
  if (normalized.dx.abs() >= normalized.dy.abs()) {
    return Offset(normalized.dx >= 0 ? 1 : -1, 0);
  }
  return Offset(0, normalized.dy >= 0 ? 1 : -1);
}

Offset borderPointFromUnit(
  Rect rect,
  Offset unit, {
  Offset spacingOffset = Offset.zero,
}) {
  final normalized = normalizeAnchorUnit(unit);
  final halfW = rect.width / 2;
  final halfH = rect.height / 2;
  final center = rect.center;
  return Offset(
    center.dx + normalized.dx * halfW + spacingOffset.dx,
    center.dy + normalized.dy * halfH + spacingOffset.dy,
  );
}

Offset axisNormalForBorderPoint(Rect rect, Offset edgePoint) {
  final vector = edgePoint - rect.center;
  if (vector.distanceSquared == 0) {
    return const Offset(1, 0);
  }
  if (vector.dx.abs() >= vector.dy.abs()) {
    return Offset(vector.dx >= 0 ? 1 : -1, 0);
  }
  return Offset(0, vector.dy >= 0 ? 1 : -1);
}

double anchorOrderKeyForLinkSide(
  BlockLink link,
  String blockId,
  Offset anchorUnit,
  int linkIndex,
) {
  final side = anchorSideUnit(anchorUnit);
  if (link.fromBlockId == blockId && link.sourceAnchorUnit != null) {
    if (anchorSideUnit(link.sourceAnchorUnit!) == side) {
      return link.sourceAnchorOrderKey ?? linkIndex.toDouble();
    }
  }
  if (link.toBlockId == blockId && link.targetAnchorUnit != null) {
    if (anchorSideUnit(link.targetAnchorUnit!) == side) {
      return link.targetAnchorOrderKey ?? linkIndex.toDouble();
    }
  }
  return linkIndex.toDouble();
}

Offset getAnchorSpacingOffset({
  required BlockLink currentLink,
  required String blockId,
  required Offset anchorUnit,
  required List<Block> blocks,
  required List<BlockLink> links,
  required double zoomLevel,
  required Offset canvasOffset,
}) {
  final side = anchorSideUnit(anchorUnit);
  final spacingDistance = anchorSpacingDistance * zoomLevel;
  final blockIndex = blocks.indexWhere((b) => b.id == blockId);
  if (blockIndex == -1) {
    return Offset.zero;
  }
  final rect = blockRectCanvas(
    blocks[blockIndex],
    zoomLevel: zoomLevel,
    canvasOffset: canvasOffset,
  );

  final currentLinkIndex = links.indexOf(currentLink);
  if (currentLinkIndex == -1) {
    return Offset.zero;
  }

  final sameSideEntries = <(int linkIndex, double key)>[];
  for (int i = 0; i < links.length; i++) {
    final link = links[i];
    final isSameSide =
        (link.fromBlockId == blockId &&
            link.sourceAnchorUnit != null &&
            anchorSideUnit(link.sourceAnchorUnit!) == side) ||
        (link.toBlockId == blockId &&
            link.targetAnchorUnit != null &&
            anchorSideUnit(link.targetAnchorUnit!) == side);
    if (!isSameSide) {
      continue;
    }
    sameSideEntries.add((i, anchorOrderKeyForLinkSide(link, blockId, side, i)));
  }
  if (sameSideEntries.isEmpty) {
    return Offset.zero;
  }

  sameSideEntries.sort((a, b) {
    final byKey = a.$2.compareTo(b.$2);
    if (byKey != 0) {
      return byKey;
    }
    return a.$1.compareTo(b.$1);
  });

  final rawKeys = sameSideEntries.map((e) => e.$2).toList(growable: false);
  final separatedKeys = List<double>.from(rawKeys);
  for (int i = 1; i < separatedKeys.length; i++) {
    final minNext = separatedKeys[i - 1] + spacingDistance;
    if (separatedKeys[i] < minNext) {
      separatedKeys[i] = minNext;
    }
  }

  final rawCenter = rawKeys.fold(0.0, (acc, v) => acc + v) / rawKeys.length;
  final separatedCenter =
      separatedKeys.fold(0.0, (acc, v) => acc + v) / separatedKeys.length;
  var centerOffset =
      separatedKeys[sameSideEntries.indexWhere(
        (e) => e.$1 == currentLinkIndex,
      )] +
      (rawCenter - separatedCenter);

  final edgeMargin = (_painterAnchorHandleRadius * zoomLevel).clamp(
    3.0,
    _painterAnchorHandleRadius,
  );
  final halfExtent = side.dx != 0 ? rect.height / 2 : rect.width / 2;
  final clampedCenterOffset = centerOffset
      .clamp(
        -math.max(0.0, halfExtent - edgeMargin),
        math.max(0.0, halfExtent - edgeMargin),
      )
      .toDouble();

  if (side.dx != 0) {
    return Offset(0, clampedCenterOffset);
  } else if (side.dy != 0) {
    return Offset(clampedCenterOffset, 0);
  }
  return Offset.zero;
}

Offset outwardTangentForLinkEndpoint({
  required BlockLink link,
  required bool isSource,
  required Rect rect,
  required Offset edgePoint,
  required bool showSequenceParticipantLifelines,
  required List<Block> blocks,
  required double zoomLevel,
  required Offset canvasOffset,
}) {
  if (showSequenceParticipantLifelines) {
    if (link.fromBlockId == link.toBlockId) {
      return const Offset(1, 0);
    }

    final ownId = isSource ? link.fromBlockId : link.toBlockId;
    final otherId = isSource ? link.toBlockId : link.fromBlockId;
    final ownIndex = blocks.indexWhere((b) => b.id == ownId);
    final otherIndex = blocks.indexWhere((b) => b.id == otherId);
    if (ownIndex != -1 && otherIndex != -1) {
      final ownCenterX = blockRectCanvas(
        blocks[ownIndex],
        zoomLevel: zoomLevel,
        canvasOffset: canvasOffset,
      ).center.dx;
      final otherCenterX = blockRectCanvas(
        blocks[otherIndex],
        zoomLevel: zoomLevel,
        canvasOffset: canvasOffset,
      ).center.dx;
      if ((ownCenterX - otherCenterX).abs() < 0.1) {
        return isSource ? const Offset(1, 0) : const Offset(-1, 0);
      }
      return ownCenterX <= otherCenterX
          ? const Offset(1, 0)
          : const Offset(-1, 0);
    }
    return isSource ? const Offset(1, 0) : const Offset(-1, 0);
  }

  final anchorUnit = isSource ? link.sourceAnchorUnit : link.targetAnchorUnit;
  if (anchorUnit != null) {
    return anchorSideUnit(anchorUnit);
  }
  return axisNormalForBorderPoint(rect, edgePoint);
}
