import 'dart:convert';
import 'package:flutter/material.dart';
import 'block_model.dart';
import 'link_model.dart';

/// Manages all link-related operations for the Miro-like widget
class LinkManager {
  final List<Block> blocks;
  final Function(Block) onBlockSpaceEnsure;

  LinkManager({required this.blocks, required this.onBlockSpaceEnsure});

  /// Delete a link from the list
  void deleteLink(List<BlockLink> links, BlockLink link) {
    links.remove(link);
  }

  /// Reverse a link (swap source and target with all their properties)
  void reverseLink(List<BlockLink> links, BlockLink link) {
    // Swap source and target block IDs
    final temp = link.fromBlockId;
    link.fromBlockId = link.toBlockId;
    link.toBlockId = temp;

    // Swap anchor units
    final tempAnchor = link.sourceAnchorUnit;
    link.sourceAnchorUnit = link.targetAnchorUnit;
    link.targetAnchorUnit = tempAnchor;

    // Swap anchor order keys
    final tempOrderKey = link.sourceAnchorOrderKey;
    link.sourceAnchorOrderKey = link.targetAnchorOrderKey;
    link.targetAnchorOrderKey = tempOrderKey;

    // Swap lock flags
    final tempLocked = link.isSourceAnchorLocked;
    link.isSourceAnchorLocked = link.isTargetAnchorLocked;
    link.isTargetAnchorLocked = tempLocked;

    // Update anchors for the affected blocks
    final fromIndex = blocks.indexWhere((b) => b.id == link.fromBlockId);
    final toIndex = blocks.indexWhere((b) => b.id == link.toBlockId);

    if (fromIndex != -1) {
      onBlockSpaceEnsure(blocks[fromIndex]);
    }
    if (toIndex != -1) {
      onBlockSpaceEnsure(blocks[toIndex]);
    }
  }

  /// Create a new link from one block to another
  BlockLink createLink(
    String fromBlockId,
    String toBlockId,
    String name,
    ConnectorType connectorType,
    Offset? sourceAnchorUnit,
    Offset? targetAnchorUnit,
    List<Offset>? inflectionPoints,
  ) {
    return BlockLink(
      fromBlockId: fromBlockId,
      toBlockId: toBlockId,
      name: name,
      connectorType: connectorType,
      inflectionPoints: inflectionPoints,
      sourceAnchorUnit: sourceAnchorUnit,
      targetAnchorUnit: targetAnchorUnit,
    );
  }

  /// Find a link by its block connections
  BlockLink? findLinkByBlocks(
    List<BlockLink> links,
    String fromBlockId,
    String toBlockId,
  ) {
    try {
      return links.firstWhere(
        (link) =>
            link.fromBlockId == fromBlockId && link.toBlockId == toBlockId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Serialize a link to JSON
  Map<String, dynamic> linkToJson(BlockLink link) {
    return {
      'from': link.fromBlockId,
      'to': link.toBlockId,
      'name': link.name,
      'type': link.connectorType == ConnectorType.bezier
          ? 'bezier'
          : 'orthogonal',
      'sourceAnchor': link.sourceAnchorUnit == null
          ? null
          : {'dx': link.sourceAnchorUnit!.dx, 'dy': link.sourceAnchorUnit!.dy},
      'targetAnchor': link.targetAnchorUnit == null
          ? null
          : {'dx': link.targetAnchorUnit!.dx, 'dy': link.targetAnchorUnit!.dy},
      'sourceAnchorOrderKey': link.sourceAnchorOrderKey,
      'targetAnchorOrderKey': link.targetAnchorOrderKey,
      'sourceAnchorLocked': link.isSourceAnchorLocked,
      'targetAnchorLocked': link.isTargetAnchorLocked,
      'inflectionPoints': link.inflectionPoints
          .map((p) => {'dx': p.dx, 'dy': p.dy})
          .toList(),
    };
  }

  /// Deserialize links from JSON
  List<BlockLink> linksFromJson(
    List<dynamic> jsonList, {
    ConnectorType fallbackType = ConnectorType.bezier,
  }) {
    final parsed = <BlockLink>[];

    for (final item in jsonList) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final from = item['from'];
      final to = item['to'];

      if (from == null || to == null) {
        continue;
      }

      final inflectionPoints = <Offset>[];
      if (item['inflectionPoints'] is List) {
        for (final point in item['inflectionPoints']) {
          if (point is Map<String, dynamic> &&
              point['dx'] is num &&
              point['dy'] is num) {
            inflectionPoints.add(
              Offset(
                (point['dx'] as num).toDouble(),
                (point['dy'] as num).toDouble(),
              ),
            );
          }
        }
      }

      parsed.add(
        BlockLink(
          fromBlockId: from,
          toBlockId: to,
          name: item['name']?.toString() ?? '',
          connectorType: item['type'] == 'orthogonal'
              ? ConnectorType.orthogonal
              : ConnectorType.bezier,
          inflectionPoints: inflectionPoints,
          sourceAnchorUnit: item['sourceAnchor'] == null
              ? null
              : _offsetFromJson(item['sourceAnchor']),
          targetAnchorUnit: item['targetAnchor'] == null
              ? null
              : _offsetFromJson(item['targetAnchor']),
        ),
      );

      final sourceOrderKey = item['sourceAnchorOrderKey'];
      if (sourceOrderKey is num) {
        parsed.last.sourceAnchorOrderKey = sourceOrderKey.toDouble();
      }

      final targetOrderKey = item['targetAnchorOrderKey'];
      if (targetOrderKey is num) {
        parsed.last.targetAnchorOrderKey = targetOrderKey.toDouble();
      }

      final sourceAnchorLocked = item['sourceAnchorLocked'];
      if (sourceAnchorLocked is bool) {
        parsed.last.isSourceAnchorLocked = sourceAnchorLocked;
      }

      final targetAnchorLocked = item['targetAnchorLocked'];
      if (targetAnchorLocked is bool) {
        parsed.last.isTargetAnchorLocked = targetAnchorLocked;
      }

      if (item['connectorType'] == null) {
        parsed.last.connectorType = fallbackType;
      }
    }

    return parsed;
  }

  static Offset _offsetFromJson(
    dynamic value, {
    Offset fallback = Offset.zero,
  }) {
    if (value is Map<String, dynamic>) {
      final dx = value['dx'];
      final dy = value['dy'];
      if (dx is num && dy is num) {
        return Offset(dx.toDouble(), dy.toDouble());
      }
    }
    return fallback;
  }

  /// Export links to JSON string
  String exportLinksJson(List<BlockLink> links) {
    final jsonList = links.map((link) => linkToJson(link)).toList();
    return const JsonEncoder.withIndent('  ').convert(jsonList);
  }

  /// Import links from JSON string
  List<BlockLink> importLinksJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is List) {
        return linksFromJson(decoded);
      }
    } catch (e) {
      // Silently fail, return empty list
    }
    return [];
  }
}
