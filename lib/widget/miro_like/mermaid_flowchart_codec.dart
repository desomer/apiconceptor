import 'models/block_model.dart';
import 'models/link_model.dart';

class MermaidFlowchartEdge {
  final String fromId;
  final String toId;
  final String label;
  final String arrowType;

  const MermaidFlowchartEdge({
    required this.fromId,
    required this.toId,
    required this.label,
    this.arrowType = '-->',
  });
}

class MermaidFlowchartSubgraph {
  final String id;
  final String title;
  final List<String> nodeIds;

  const MermaidFlowchartSubgraph({
    required this.id,
    required this.title,
    required this.nodeIds,
  });
}

class MermaidFlowchartParseResult {
  final String layoutDirection;
  final List<String> nodeOrder;
  final Map<String, String> nodeTitles;
  final Map<String, BlockNodeShape> nodeShapes;
  final List<MermaidFlowchartEdge> edges;
  final List<MermaidFlowchartSubgraph> subgraphs;

  const MermaidFlowchartParseResult({
    required this.layoutDirection,
    required this.nodeOrder,
    required this.nodeTitles,
    required this.nodeShapes,
    required this.edges,
    required this.subgraphs,
  });
}

class MermaidFlowchartCodec {
  const MermaidFlowchartCodec._();

  static const List<String> _supportedFlowchartArrowTypes = [
    '<.->',
    '<-->',
    '==.=>',
    '=.=>',
    '-.->',
    '-->',
    '==>',
    '=>',
    '.->',
    '---',
    '-.-',
    '->',
  ];

  static const List<({String open, String close, BlockNodeShape shape})>
  _nodeShapePatterns = [
    (open: '(((', close: ')))', shape: BlockNodeShape.doubleCircle),
    (open: '(([', close: ']))', shape: BlockNodeShape.horizontalTube),
    (open: '[[', close: ']]', shape: BlockNodeShape.subroutine),
    (open: '{{', close: '}}', shape: BlockNodeShape.hexagon),
    (open: '([', close: '])', shape: BlockNodeShape.roundedRectangle),
    (open: '((', close: '))', shape: BlockNodeShape.circle),
    (open: '[(', close: ')]', shape: BlockNodeShape.database),
    (open: '[/', close: '/]', shape: BlockNodeShape.parallelogram),
    (open: '[\\', close: '\\]', shape: BlockNodeShape.parallelogramInverted),
    (open: '[/', close: '\\]', shape: BlockNodeShape.trapezoid),
    (open: '[\\', close: '/]', shape: BlockNodeShape.trapezoidInverted),
    (open: '[', close: ']', shape: BlockNodeShape.rectangle),
  ];

  static String generate({
    required List<Block> blocks,
    required List<BlockLink> links,
    required String direction,
  }) {
    final exportBlocks = blocks.where((b) => !b.isZone).toList(growable: false);
    final blockIds = <String, String>{};
    for (var i = 0; i < exportBlocks.length; i++) {
      blockIds[exportBlocks[i].id] = 'm$i';
    }

    final buffer = StringBuffer('flowchart $direction\n');
    for (final block in exportBlocks) {
      final nodeId = blockIds[block.id];
      if (nodeId == null) {
        continue;
      }
      final shapeSyntax = _nodeShapeSyntax(
        shape: block.nodeShape,
        text: _escapeMermaidText(block.title),
      );
      buffer.writeln('  $nodeId$shapeSyntax');
    }

    for (final link in links) {
      final fromId = blockIds[link.fromBlockId];
      final toId = blockIds[link.toBlockId];
      if (fromId == null || toId == null) {
        continue;
      }

      final arrowType = _normalizedFlowchartArrowTypeOrDefault(
        link.sequenceArrowType,
      );
      final label = link.name.trim();
      if (label.isEmpty) {
        buffer.writeln('  $fromId $arrowType $toId');
      } else {
        buffer.writeln(
          '  $fromId $arrowType|${_escapeMermaidText(label)}| $toId',
        );
      }
    }

    return buffer.toString().trimRight();
  }

  static MermaidFlowchartParseResult parse(
    String text, {
    required String fallbackDirection,
    required List<String> allowedDirections,
  }) {
    final source = extractSource(text);
    if (source.isEmpty) {
      throw const FormatException('Le code Mermaid est vide');
    }

    final layoutDirection = _extractDirection(
      source,
      fallbackDirection: fallbackDirection,
      allowedDirections: allowedDirections,
    );

    final lines = source.split(RegExp(r'\r?\n'));
    final nodeTitles = <String, String>{};
    final nodeShapes = <String, BlockNodeShape>{};
    final nodeOrder = <String>[];
    final edgeData = <MermaidFlowchartEdge>[];
    final subgraphStack = <String>[];
    final subgraphTitles = <String, String>{};
    final subgraphNodeSets = <String, Set<String>>{};
    var autoSubgraphIndex = 0;

    void registerNode(
      String nodeId, [
      String? title,
      BlockNodeShape? nodeShape,
    ]) {
      if (!nodeOrder.contains(nodeId)) {
        nodeOrder.add(nodeId);
      }
      if (title != null && title.isNotEmpty) {
        nodeTitles[nodeId] = _normalizeLineBreaks(title);
      } else {
        nodeTitles.putIfAbsent(nodeId, () => nodeId);
      }
      if (nodeShape != null) {
        nodeShapes[nodeId] = nodeShape;
      } else {
        nodeShapes.putIfAbsent(nodeId, () => BlockNodeShape.rectangle);
      }
      for (final subgraphId in subgraphStack) {
        subgraphNodeSets.putIfAbsent(subgraphId, () => <String>{}).add(nodeId);
      }
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('%%')) {
        continue;
      }

      if (line.startsWith('flowchart ') || line.startsWith('graph ')) {
        continue;
      }

      final subgraphMatch = RegExp(
        r'^subgraph\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (subgraphMatch != null) {
        final body = (subgraphMatch.group(1) ?? '').trim();
        if (body.isEmpty) {
          continue;
        }

        final quotedMatch = RegExp(r'^"([^"]+)"$').firstMatch(body);
        final bracketMatch = RegExp(
          r'^([A-Za-z_][A-Za-z0-9_-]*)\s*\[\s*(?:"([^"]*)"|([^\]]*))\s*\]$',
        ).firstMatch(body);

        String subgraphId;
        String subgraphTitle;
        if (bracketMatch != null) {
          subgraphId = bracketMatch.group(1)!;
          subgraphTitle =
              (bracketMatch.group(2) ?? bracketMatch.group(3) ?? subgraphId)
                  .trim();
        } else if (quotedMatch != null) {
          subgraphId = 'sg${autoSubgraphIndex++}';
          subgraphTitle = quotedMatch.group(1)!.trim();
        } else {
          final tokenIdMatch = RegExp(
            r'^([A-Za-z_][A-Za-z0-9_-]*)(?:\s+"([^"]+)")?$',
          ).firstMatch(body);
          if (tokenIdMatch != null) {
            subgraphId = tokenIdMatch.group(1)!;
            subgraphTitle = (tokenIdMatch.group(2) ?? tokenIdMatch.group(1)!)
                .trim();
          } else {
            subgraphId = 'sg${autoSubgraphIndex++}';
            subgraphTitle = body;
          }
        }

        subgraphTitles[subgraphId] = _normalizeLineBreaks(subgraphTitle);
        subgraphNodeSets.putIfAbsent(subgraphId, () => <String>{});
        subgraphStack.add(subgraphId);
        continue;
      }

      if (line.toLowerCase() == 'end') {
        if (subgraphStack.isNotEmpty) {
          subgraphStack.removeLast();
        }
        continue;
      }

      final nodeDeclaration = _parseNodeDeclaration(line);
      if (nodeDeclaration != null) {
        registerNode(
          nodeDeclaration.id,
          nodeDeclaration.title,
          nodeDeclaration.shape,
        );
        continue;
      }

      final chainedEdges = _parseChainedEdges(line);
      if (chainedEdges.edges.isNotEmpty) {
        for (final node in chainedEdges.nodeDeclarations.entries) {
          registerNode(node.key, node.value.title, node.value.shape);
        }
        for (final edge in chainedEdges.edges) {
          registerNode(edge.fromId);
          registerNode(edge.toId);
          edgeData.add(edge);
        }
      }
    }

    if (nodeOrder.isEmpty) {
      throw const FormatException('Aucun bloc Mermaid reconnu');
    }

    return MermaidFlowchartParseResult(
      layoutDirection: layoutDirection,
      nodeOrder: nodeOrder,
      nodeTitles: nodeTitles,
      nodeShapes: nodeShapes,
      edges: edgeData,
      subgraphs: subgraphNodeSets.entries
          .where((entry) => entry.value.isNotEmpty)
          .map(
            (entry) => MermaidFlowchartSubgraph(
              id: entry.key,
              title: subgraphTitles[entry.key] ?? entry.key,
              nodeIds: entry.value.toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  static String extractSource(String text) {
    final fenced = RegExp(
      r'```(?:mermaid)?\s*([\s\S]*?)```',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(text);
    if (fenced != null) {
      return fenced.group(1)?.trim() ?? '';
    }
    return text.trim();
  }

  static String _extractDirection(
    String source, {
    required String fallbackDirection,
    required List<String> allowedDirections,
  }) {
    final match = RegExp(
      r'^(?:flowchart|graph)\s+([A-Za-z]{2})\b',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(source);
    if (match == null) {
      return fallbackDirection;
    }

    final parsed = (match.group(1) ?? '').toUpperCase();
    if (parsed == 'TD') {
      return 'TB';
    }
    if (allowedDirections.contains(parsed)) {
      return parsed;
    }
    return fallbackDirection;
  }

  static String _normalizeLineBreaks(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(r'\n', '\n')
        .replaceAll('/n', '\n');
  }

  static String _escapeMermaidText(String text) {
    final normalized = _normalizeLineBreaks(text);
    return normalized
        .replaceAll('\\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .trim();
  }

  static String _normalizedFlowchartArrowTypeOrDefault(String? raw) {
    final value = (raw ?? '').trim();
    if (value == '->') {
      // Legacy flow syntax normalized to standard solid flow arrow.
      return '-->';
    }
    if (_supportedFlowchartArrowTypes.contains(value)) {
      return value;
    }
    return '-->';
  }

  static String _nodeShapeSyntax({
    required BlockNodeShape shape,
    required String text,
  }) {
    switch (shape) {
      case BlockNodeShape.rectangle:
        return '["$text"]';
      case BlockNodeShape.roundedRectangle:
        return '(["$text"])';
      case BlockNodeShape.stadium:
        return '(["$text"])';
      case BlockNodeShape.subroutine:
        return '[["$text"]]';
      case BlockNodeShape.circle:
        return '(("$text"))';
      case BlockNodeShape.doubleCircle:
        return '((("$text")))';
      case BlockNodeShape.database:
        return '[("$text")]';
      case BlockNodeShape.horizontalTube:
        return '((["$text"]))';
      case BlockNodeShape.hexagon:
        return '{{"$text"}}';
      case BlockNodeShape.parallelogram:
        return '[/"$text"/]';
      case BlockNodeShape.parallelogramInverted:
        return '[\\"$text"\\]';
      case BlockNodeShape.trapezoid:
        return '[/"$text"\\]';
      case BlockNodeShape.trapezoidInverted:
        return '[\\"$text"/]';
    }
  }

  static ({String id, String title, BlockNodeShape shape})?
  _parseNodeDeclaration(String line) {
    final idMatch = RegExp(
      r'^([A-Za-z_][A-Za-z0-9_-]*)\s*(.+)$',
    ).firstMatch(line);
    if (idMatch == null) {
      return null;
    }

    final nodeId = idMatch.group(1)!;
    final suffix = (idMatch.group(2) ?? '').trim();
    if (suffix.isEmpty) {
      return null;
    }

    String? text;
    BlockNodeShape? shape;

    ({String open, String close, BlockNodeShape shape})? matched;

    for (final pattern in _nodeShapePatterns) {
      if (!suffix.startsWith(pattern.open) || !suffix.endsWith(pattern.close)) {
        continue;
      }
      final inner = suffix.substring(
        pattern.open.length,
        suffix.length - pattern.close.length,
      );
      text = _decodeNodeText(inner);
      shape = pattern.shape;
      matched = pattern;
      break;
    }

    if (matched == null || text == null || shape == null) {
      return null;
    }

    return (id: nodeId, title: text, shape: shape);
  }

  static String _decodeNodeText(String raw) {
    final trimmed = raw.trim();
    if (trimmed.length >= 2 &&
        trimmed.startsWith('"') &&
        trimmed.endsWith('"')) {
      final unquoted = trimmed.substring(1, trimmed.length - 1);
      return _normalizeLineBreaks(
        unquoted.replaceAll(r'\"', '"').replaceAll(r'\\', r'\'),
      );
    }
    return _normalizeLineBreaks(trimmed);
  }

  static ({
    List<MermaidFlowchartEdge> edges,
    Map<String, ({String title, BlockNodeShape shape})> nodeDeclarations,
  })
  _parseChainedEdges(String line) {
    final result = <MermaidFlowchartEdge>[];
    final nodeDeclarations = <String, ({String title, BlockNodeShape shape})>{};
    var cursor = _skipSpaces(line, 0);
    final firstNode = _readNodeRef(line, cursor);
    if (firstNode == null) {
      return (
        edges: const <MermaidFlowchartEdge>[],
        nodeDeclarations: const {},
      );
    }

    var currentNode = firstNode.$1;
    if (firstNode.$2 != null && firstNode.$3 != null) {
      nodeDeclarations[currentNode] = (
        title: firstNode.$2!,
        shape: firstNode.$3!,
      );
    }
    cursor = firstNode.$4;

    while (true) {
      cursor = _skipSpaces(line, cursor);
      final arrow = _readArrow(line, cursor);
      if (arrow == null) {
        break;
      }

      final arrowType = _normalizedFlowchartArrowTypeOrDefault(arrow.$1);
      cursor = _skipSpaces(line, arrow.$2);
      var label = '';

      if (cursor < line.length && line.codeUnitAt(cursor) == 124) {
        final labelEnd = line.indexOf('|', cursor + 1);
        if (labelEnd < 0) {
          return (
            edges: const <MermaidFlowchartEdge>[],
            nodeDeclarations: const {},
          );
        }
        label = line.substring(cursor + 1, labelEnd).trim();
        cursor = _skipSpaces(line, labelEnd + 1);
      }

      final nextNode = _readNodeRef(line, cursor);
      if (nextNode == null) {
        return (
          edges: const <MermaidFlowchartEdge>[],
          nodeDeclarations: const {},
        );
      }

      if (nextNode.$2 != null && nextNode.$3 != null) {
        nodeDeclarations[nextNode.$1] = (
          title: nextNode.$2!,
          shape: nextNode.$3!,
        );
      }

      result.add(
        MermaidFlowchartEdge(
          fromId: currentNode,
          toId: nextNode.$1,
          label: label,
          arrowType: arrowType,
        ),
      );
      currentNode = nextNode.$1;
      cursor = nextNode.$4;
    }

    cursor = _skipSpaces(line, cursor);
    if (result.isEmpty || cursor != line.length) {
      return (
        edges: const <MermaidFlowchartEdge>[],
        nodeDeclarations: const {},
      );
    }
    return (edges: result, nodeDeclarations: nodeDeclarations);
  }

  static (String, int)? _readNodeId(String line, int start) {
    final match = RegExp(
      r'^[A-Za-z_][A-Za-z0-9_-]*',
    ).firstMatch(line.substring(start));
    if (match == null) {
      return null;
    }
    final value = match.group(0)!;
    return (value, start + value.length);
  }

  static (String, String?, BlockNodeShape?, int)? _readNodeRef(
    String line,
    int start,
  ) {
    final id = _readNodeId(line, start);
    if (id == null) {
      return null;
    }

    final nodeId = id.$1;
    var cursor = id.$2;
    var text = null as String?;
    var shape = null as BlockNodeShape?;

    final shapeRead = _readNodeShapeAt(line, cursor);
    if (shapeRead != null) {
      text = shapeRead.$1;
      shape = shapeRead.$2;
      cursor = shapeRead.$3;
    }

    return (nodeId, text, shape, cursor);
  }

  static (String, BlockNodeShape, int)? _readNodeShapeAt(
    String line,
    int start,
  ) {
    final cursor = _skipSpaces(line, start);
    for (final pattern in _nodeShapePatterns) {
      if (!line.startsWith(pattern.open, cursor)) {
        continue;
      }

      final closeIndex = line.indexOf(
        pattern.close,
        cursor + pattern.open.length,
      );
      if (closeIndex < 0) {
        continue;
      }

      final inner = line.substring(cursor + pattern.open.length, closeIndex);
      final text = _decodeNodeText(inner);
      final end = closeIndex + pattern.close.length;
      return (text, pattern.shape, end);
    }
    return null;
  }

  static (String, int)? _readArrow(String line, int start) {
    for (final arrowType in _supportedFlowchartArrowTypes) {
      if (!line.startsWith(arrowType, start)) {
        continue;
      }
      return (arrowType, start + arrowType.length);
    }
    return null;
  }

  static int _skipSpaces(String value, int start) {
    var i = start;
    while (i < value.length && value.codeUnitAt(i) <= 32) {
      i++;
    }
    return i;
  }
}
