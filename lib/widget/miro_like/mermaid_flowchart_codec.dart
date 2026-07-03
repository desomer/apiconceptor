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
  final List<MermaidFlowchartEdge> edges;
  final List<MermaidFlowchartSubgraph> subgraphs;

  const MermaidFlowchartParseResult({
    required this.layoutDirection,
    required this.nodeOrder,
    required this.nodeTitles,
    required this.edges,
    required this.subgraphs,
  });
}

class MermaidFlowchartCodec {
  const MermaidFlowchartCodec._();

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
      buffer.writeln('  $nodeId["${_escapeMermaidText(block.title)}"]');
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
    final nodeOrder = <String>[];
    final edgeData = <MermaidFlowchartEdge>[];
    final subgraphStack = <String>[];
    final subgraphTitles = <String, String>{};
    final subgraphNodeSets = <String, Set<String>>{};
    var autoSubgraphIndex = 0;

    void registerNode(String nodeId, [String? title]) {
      if (!nodeOrder.contains(nodeId)) {
        nodeOrder.add(nodeId);
      }
      if (title != null && title.isNotEmpty) {
        nodeTitles[nodeId] = _normalizeLineBreaks(title);
      } else {
        nodeTitles.putIfAbsent(nodeId, () => nodeId);
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

      final nodeMatch = RegExp(
        r'^([A-Za-z_][A-Za-z0-9_-]*)\s*\[\s*(?:"([^"]*)"|([^\]]*))\s*\]\s*$',
      ).firstMatch(line);
      if (nodeMatch != null) {
        final nodeId = nodeMatch.group(1)!;
        final title = nodeMatch.group(2) ?? nodeMatch.group(3) ?? nodeId;
        registerNode(nodeId, title);
        continue;
      }

      final chainedEdges = _parseChainedEdges(line);
      if (chainedEdges.isNotEmpty) {
        for (final edge in chainedEdges) {
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
    if (value == '->' || value == '-->') {
      return value;
    }
    return '-->';
  }

  static List<MermaidFlowchartEdge> _parseChainedEdges(String line) {
    final result = <MermaidFlowchartEdge>[];
    var cursor = _skipSpaces(line, 0);
    final firstNode = _readNodeId(line, cursor);
    if (firstNode == null) {
      return const <MermaidFlowchartEdge>[];
    }

    var currentNode = firstNode.$1;
    cursor = firstNode.$2;

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
          return const <MermaidFlowchartEdge>[];
        }
        label = line.substring(cursor + 1, labelEnd).trim();
        cursor = _skipSpaces(line, labelEnd + 1);
      }

      final nextNode = _readNodeId(line, cursor);
      if (nextNode == null) {
        return const <MermaidFlowchartEdge>[];
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
      cursor = nextNode.$2;
    }

    cursor = _skipSpaces(line, cursor);
    if (result.isEmpty || cursor != line.length) {
      return const <MermaidFlowchartEdge>[];
    }
    return result;
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

  static (String, int)? _readArrow(String line, int start) {
    if (line.startsWith('-->', start)) {
      return ('-->', start + 3);
    }
    if (line.startsWith('->', start)) {
      return ('->', start + 2);
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
