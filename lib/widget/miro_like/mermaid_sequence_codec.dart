import 'models/block_model.dart';
import 'models/link_model.dart';

class MermaidSequenceParticipant {
  final String id;
  final String label;

  const MermaidSequenceParticipant({required this.id, required this.label});
}

class MermaidSequenceMessage {
  final String fromId;
  final String toId;
  final String label;

  const MermaidSequenceMessage({
    required this.fromId,
    required this.toId,
    required this.label,
  });
}

class MermaidSequenceParseResult {
  final List<MermaidSequenceParticipant> participants;
  final List<MermaidSequenceMessage> messages;

  const MermaidSequenceParseResult({
    required this.participants,
    required this.messages,
  });
}

class MermaidSequenceCodec {
  const MermaidSequenceCodec._();

  // Mermaid actor IDs can contain internal dashes, but should not end with one.
  static const String _participantIdPattern =
      r'[A-Za-z_][A-Za-z0-9_]*(?:-[A-Za-z0-9_]+)*';

  static bool isSequenceDiagram(String text) {
    final source = extractSource(text);
    if (source.isEmpty) {
      return false;
    }

    for (final rawLine in source.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('%%')) {
        continue;
      }
      return line.toLowerCase().startsWith('sequencediagram');
    }
    return false;
  }

  static MermaidSequenceParseResult parse(String text) {
    final source = extractSource(text);
    if (source.isEmpty) {
      throw const FormatException('Le code Mermaid est vide');
    }

    final lines = source.split(RegExp(r'\r?\n'));
    final participantsById = <String, MermaidSequenceParticipant>{};
    final participantOrder = <String>[];
    final messages = <MermaidSequenceMessage>[];

    void registerParticipant(String id, [String? label]) {
      final cleanId = id.trim();
      if (cleanId.isEmpty) {
        return;
      }

      final cleanLabel = (label ?? cleanId).trim();
      if (!participantsById.containsKey(cleanId)) {
        participantOrder.add(cleanId);
      }
      participantsById[cleanId] = MermaidSequenceParticipant(
        id: cleanId,
        label: cleanLabel.isEmpty ? cleanId : cleanLabel,
      );
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('%%')) {
        continue;
      }
      if (line.toLowerCase().startsWith('sequencediagram')) {
        continue;
      }
      if (line.toLowerCase().startsWith('autonumber')) {
        continue;
      }

      final participantMatch = RegExp(
        '^participant\\s+($_participantIdPattern)(?:\\s+as\\s+(.+))?' + r'$',
        caseSensitive: false,
      ).firstMatch(line);
      if (participantMatch != null) {
        final id = participantMatch.group(1)!;
        var label = participantMatch.group(2)?.trim();
        if (label != null &&
            label.length >= 2 &&
            ((label.startsWith('"') && label.endsWith('"')) ||
                (label.startsWith("'") && label.endsWith("'")))) {
          label = label.substring(1, label.length - 1);
        }
        registerParticipant(id, _normalizeInline(label ?? id));
        continue;
      }

      final messageMatch = RegExp(
        '^($_participantIdPattern)\\s*(?:-->>|->>|-->|->|--x|->x|--\\)|-\\))\\s*($_participantIdPattern)\\s*:\\s*(.*)' +
            r'$',
      ).firstMatch(line);
      if (messageMatch != null) {
        final fromId = messageMatch.group(1)!;
        final toId = messageMatch.group(2)!;
        final label = _normalizeInline((messageMatch.group(3) ?? '').trim());
        registerParticipant(fromId);
        registerParticipant(toId);
        messages.add(
          MermaidSequenceMessage(
            fromId: fromId,
            toId: toId,
            label: label.isEmpty ? 'message' : label,
          ),
        );
      }
    }

    if (participantOrder.isEmpty) {
      throw const FormatException('Aucun participant Mermaid reconnu');
    }

    return MermaidSequenceParseResult(
      participants: participantOrder
          .map((id) => participantsById[id]!)
          .toList(growable: false),
      messages: messages,
    );
  }

  static String generate({
    required List<Block> blocks,
    required List<BlockLink> links,
  }) {
    final participants = blocks.where((b) => !b.isZone).toList(growable: false);
    final participantIds = <String, String>{};
    for (var i = 0; i < participants.length; i++) {
      participantIds[participants[i].id] = 'p$i';
    }

    final buffer = StringBuffer('sequenceDiagram\n');
    for (final participant in participants) {
      final participantId = participantIds[participant.id];
      if (participantId == null) {
        continue;
      }
      final name = _normalizeInline(participant.title);
      buffer.writeln('  participant $participantId as $name');
    }

    for (final link in links) {
      final fromId = participantIds[link.fromBlockId];
      final toId = participantIds[link.toBlockId];
      if (fromId == null || toId == null) {
        continue;
      }

      final label = link.name.trim().isEmpty
          ? 'message'
          : _normalizeInline(link.name);
      buffer.writeln('  $fromId->>$toId: $label');
    }

    return buffer.toString().trimRight();
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

  static String _normalizeInline(String text) {
    return text
        .replaceAll('\r\n', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll(':', ' -')
        .trim();
  }
}
