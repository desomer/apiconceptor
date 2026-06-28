import 'models/block_model.dart';
import 'models/link_model.dart';

class MermaidFlowchartEdge {
  final String fromId;
  final String toId;
  final String label;

  const MermaidFlowchartEdge({
    required this.fromId,
    required this.toId,
    required this.label,
  });
}

class MermaidFlowchartParseResult {
  final String layoutDirection;
  final List<String> nodeOrder;
  final Map<String, String> nodeTitles;
  final List<MermaidFlowchartEdge> edges;

  const MermaidFlowchartParseResult({
    required this.layoutDirection,
    required this.nodeOrder,
    required this.nodeTitles,
    required this.edges,
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

      final label = link.name.trim();
      if (label.isEmpty) {
        buffer.writeln('  $fromId --> $toId');
      } else {
        buffer.writeln('  $fromId -->|${_escapeMermaidText(label)}| $toId');
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

    void registerNode(String nodeId, [String? title]) {
      if (!nodeOrder.contains(nodeId)) {
        nodeOrder.add(nodeId);
      }
      if (title != null && title.isNotEmpty) {
        nodeTitles[nodeId] = _normalizeLineBreaks(title);
      } else {
        nodeTitles.putIfAbsent(nodeId, () => nodeId);
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

      final nodeMatch = RegExp(
        r'^([A-Za-z_][A-Za-z0-9_-]*)\s*\[\s*(?:"([^"]*)"|([^\]]*))\s*\]\s*$',
      ).firstMatch(line);
      if (nodeMatch != null) {
        final nodeId = nodeMatch.group(1)!;
        final title = nodeMatch.group(2) ?? nodeMatch.group(3) ?? nodeId;
        registerNode(nodeId, title);
        continue;
      }

      final edgeMatch = RegExp(
        r'^([A-Za-z_][A-Za-z0-9_-]*)\s*--?>\s*(?:\|([^|]*)\|\s*)?([A-Za-z_][A-Za-z0-9_-]*)\s*$',
      ).firstMatch(line);
      if (edgeMatch != null) {
        final fromId = edgeMatch.group(1)!;
        final label = (edgeMatch.group(2) ?? '').trim();
        final toId = edgeMatch.group(3)!;
        registerNode(fromId);
        registerNode(toId);
        edgeData.add(
          MermaidFlowchartEdge(fromId: fromId, toId: toId, label: label),
        );
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
}
