import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/link_model.dart';

class SequenceGroupSpan {
  final double leftCanvas;
  final double rightCanvas;

  const SequenceGroupSpan({
    required this.leftCanvas,
    required this.rightCanvas,
  });
}

class SequenceControlGroupInfo {
  final String kind;
  final String label;
  final double startYCanvas;
  final double endYCanvas;
  final int branchCount;
  final BlockLink sourceLink;
  final int sourceOpenLineIndex;

  const SequenceControlGroupInfo({
    required this.kind,
    required this.label,
    required this.startYCanvas,
    required this.endYCanvas,
    required this.branchCount,
    required this.sourceLink,
    required this.sourceOpenLineIndex,
  });

  SequenceControlGroupInfo copyWith({String? kind, String? label}) {
    return SequenceControlGroupInfo(
      kind: kind ?? this.kind,
      label: label ?? this.label,
      startYCanvas: startYCanvas,
      endYCanvas: endYCanvas,
      branchCount: branchCount,
      sourceLink: sourceLink,
      sourceOpenLineIndex: sourceOpenLineIndex,
    );
  }

  String get selectionKey {
    final startRounded = startYCanvas.toStringAsFixed(2);
    final endRounded = endYCanvas.toStringAsFixed(2);
    return '$kind|$label|$startRounded|$endRounded|$branchCount';
  }
}

class SequenceMessageEntry {
  final BlockLink link;
  final double laneYCanvas;
  final double leftXCanvas;
  final double rightXCanvas;
  final double startXCanvas;
  final double endXCanvas;
  final double topYCanvas;
  final double bottomYCanvas;

  const SequenceMessageEntry({
    required this.link,
    required this.laneYCanvas,
    required this.leftXCanvas,
    required this.rightXCanvas,
    required this.startXCanvas,
    required this.endXCanvas,
    required this.topYCanvas,
    required this.bottomYCanvas,
  });
}

class SequenceMessageLayer extends StatelessWidget {
  final List<SequenceMessageEntry> entries;
  final SequenceGroupSpan? groupSpan;
  final SequenceControlGroupInfo? selectedGroup;
  final Set<BlockLink> selectedLinks;
  final void Function(SequenceControlGroupInfo group) onSelectGroup;
  final void Function(BlockLink link, bool additive) onSelect;
  final void Function(BlockLink link) onDragStart;
  final void Function(BlockLink link, Offset globalPosition) onDragUpdate;
  final void Function(BlockLink link) onDragEnd;

  const SequenceMessageLayer({
    super.key,
    required this.entries,
    this.groupSpan,
    this.selectedGroup,
    required this.selectedLinks,
    required this.onSelectGroup,
    required this.onSelect,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final controlFrames = _buildControlFrames(entries);
    final span = groupSpan;

    return Stack(
      children: [
        if (span != null && controlFrames.isNotEmpty)
          Positioned.fill(
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _SequenceControlFramePainter(
                        frames: controlFrames,
                        leftCanvas: span.leftCanvas,
                        rightCanvas: span.rightCanvas,
                        selectedGroupKey: selectedGroup?.selectionKey,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        for (final entry in entries)
          _buildMessageHandle(
            context,
            entry,
            selectedLinks.contains(entry.link),
          ),
      ],
    );
  }

  List<_SequenceControlFrame> _buildControlFrames(
    List<SequenceMessageEntry> rawEntries,
  ) {
    final sortedEntries = List<SequenceMessageEntry>.from(rawEntries)
      ..sort((a, b) => a.laneYCanvas.compareTo(b.laneYCanvas));

    final openFrames = <_OpenFrame>[];
    final frames = <_SequenceControlFrame>[];
    if (sortedEntries.isEmpty) {
      return frames;
    }

    final firstY = sortedEntries.first.topYCanvas;
    final lastY = sortedEntries.last.bottomYCanvas;

    for (var index = 0; index < sortedEntries.length; index++) {
      final entry = sortedEntries[index];
      final separatorY = _separatorYForEntry(sortedEntries, index);

      for (
        var lineIndex = 0;
        lineIndex < entry.link.sequenceBeforeLines.length;
        lineIndex++
      ) {
        final line = entry.link.sequenceBeforeLines[lineIndex];
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          continue;
        }

        final openMatch = RegExp(
          r'^(alt|opt|loop)\b\s*(.*)$',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (openMatch != null) {
          final kind = (openMatch.group(1) ?? '').toLowerCase();
          final label = (openMatch.group(2) ?? '').trim();
          final depth = openFrames.length;
          openFrames.add(
            _OpenFrame(
              kind: kind,
              label: label,
              startY: entry.topYCanvas,
              depth: depth,
              sourceLink: entry.link,
              sourceOpenLineIndex: lineIndex,
            ),
          );
          continue;
        }

        final elseMatch = RegExp(
          r'^else\b\s*(.*)$',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (elseMatch != null && openFrames.isNotEmpty) {
          final current = openFrames.last;
          if (current.kind == 'alt') {
            current.branches.add(
              _SequenceControlBranch(
                y: separatorY,
                label: (elseMatch.group(1) ?? '').trim(),
              ),
            );
          }
        }
      }

      for (final line in entry.link.sequenceAfterLines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          continue;
        }

        final elseMatch = RegExp(
          r'^else\b\s*(.*)$',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (elseMatch != null && openFrames.isNotEmpty) {
          final current = openFrames.last;
          if (current.kind == 'alt') {
            current.branches.add(
              _SequenceControlBranch(
                y: separatorY,
                label: (elseMatch.group(1) ?? '').trim(),
              ),
            );
          }
          continue;
        }

        if (RegExp(r'^end\b', caseSensitive: false).hasMatch(trimmed) &&
            openFrames.isNotEmpty) {
          final current = openFrames.removeLast();
          frames.add(
            _SequenceControlFrame(
              kind: current.kind,
              label: current.label,
              startY: current.startY,
              endY: entry.bottomYCanvas,
              depth: current.depth,
              branches: List<_SequenceControlBranch>.from(current.branches),
              sourceLink: current.sourceLink,
              sourceOpenLineIndex: current.sourceOpenLineIndex,
            ),
          );
        }
      }
    }

    while (openFrames.isNotEmpty) {
      final current = openFrames.removeLast();
      frames.add(
        _SequenceControlFrame(
          kind: current.kind,
          label: current.label,
          startY: current.startY,
          endY: lastY,
          depth: current.depth,
          branches: List<_SequenceControlBranch>.from(current.branches),
          sourceLink: current.sourceLink,
          sourceOpenLineIndex: current.sourceOpenLineIndex,
        ),
      );
    }

    frames.sort((a, b) {
      final byStart = a.startY.compareTo(b.startY);
      if (byStart != 0) {
        return byStart;
      }
      return a.endY.compareTo(b.endY);
    });

    return frames
        .where((f) => f.endY >= firstY && f.endY >= f.startY)
        .toList(growable: false);
  }

  double _separatorYForEntry(
    List<SequenceMessageEntry> sortedEntries,
    int index,
  ) {
    final current = sortedEntries[index];
    if (index == 0) {
      return current.topYCanvas;
    }
    final previous = sortedEntries[index - 1];
    return (previous.bottomYCanvas + current.topYCanvas) / 2;
  }

  Widget _buildMessageHandle(
    BuildContext context,
    SequenceMessageEntry entry,
    bool isSelected,
  ) {
    final left = entry.leftXCanvas;
    final width = (entry.rightXCanvas - entry.leftXCanvas).abs().clamp(
      44.0,
      double.infinity,
    );
    const handleHeight = 28.0;

    return Positioned(
      left: left,
      top: entry.laneYCanvas - (handleHeight / 2),
      width: width,
      height: handleHeight,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (_) => onSelect(entry.link, _isCtrlPressedNow()),
          onPanStart: (_) {
            onSelect(entry.link, false);
            onDragStart(entry.link);
          },
          onPanUpdate: (details) =>
              onDragUpdate(entry.link, details.globalPosition),
          onPanEnd: (_) => onDragEnd(entry.link),
          child: CustomPaint(
            painter: _SequenceMessageHandlePainter(isSelected: isSelected),
          ),
        ),
      ),
    );
  }

  bool _isCtrlPressedNow() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight);
  }
}

class _OpenFrame {
  final String kind;
  final String label;
  final double startY;
  final int depth;
  final BlockLink sourceLink;
  final int sourceOpenLineIndex;
  final List<_SequenceControlBranch> branches = [];

  _OpenFrame({
    required this.kind,
    required this.label,
    required this.startY,
    required this.depth,
    required this.sourceLink,
    required this.sourceOpenLineIndex,
  });
}

class _SequenceControlBranch {
  final double y;
  final String label;

  const _SequenceControlBranch({required this.y, required this.label});
}

class _SequenceControlFrame {
  final String kind;
  final String label;
  final double startY;
  final double endY;
  final int depth;
  final BlockLink sourceLink;
  final int sourceOpenLineIndex;
  final List<_SequenceControlBranch> branches;

  const _SequenceControlFrame({
    required this.kind,
    required this.label,
    required this.startY,
    required this.endY,
    required this.depth,
    required this.sourceLink,
    required this.sourceOpenLineIndex,
    required this.branches,
  });
}

class _SequenceControlFramePainter extends CustomPainter {
  final List<_SequenceControlFrame> frames;
  final double leftCanvas;
  final double rightCanvas;
  final String? selectedGroupKey;

  const _SequenceControlFramePainter({
    required this.frames,
    required this.leftCanvas,
    required this.rightCanvas,
    required this.selectedGroupKey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (frames.isEmpty) {
      return;
    }

    final maxDepth = frames
        .map((f) => f.depth)
        .fold<int>(0, (current, value) => value > current ? value : current);

    final left = leftCanvas.clamp(0.0, size.width);
    final right = rightCanvas.clamp(0.0, size.width);
    if (right <= left + 8.0) {
      return;
    }

    final layeredFrames = List<_SequenceControlFrame>.from(frames)
      ..sort((a, b) {
        final byDepth = a.depth.compareTo(b.depth);
        if (byDepth != 0) {
          return byDepth;
        }
        final byStart = a.startY.compareTo(b.startY);
        if (byStart != 0) {
          return byStart;
        }
        return a.endY.compareTo(b.endY);
      });

    bool hasChildFrame(_SequenceControlFrame parent) {
      return layeredFrames.any((candidate) {
        if (candidate.depth <= parent.depth) {
          return false;
        }
        return candidate.startY >= parent.startY &&
            candidate.endY <= parent.endY;
      });
    }

    for (final frame in layeredFrames) {
      final depthInset = frame.depth * 8.0;
      final depthRatio = maxDepth == 0 ? 0.0 : frame.depth / maxDepth;
      final top = (frame.startY - 10.0 + (depthInset * 0.8)).clamp(
        0.0,
        size.height,
      );
      final bottom = (frame.endY + 10.0 - (depthInset * 0.8)).clamp(
        0.0,
        size.height,
      );
      if (bottom <= top + 8.0) {
        continue;
      }

      final insetX = depthInset;
      final rect = Rect.fromLTRB(
        (left + insetX).clamp(0.0, size.width),
        top,
        (right - insetX).clamp(0.0, size.width),
        bottom,
      );
      if (rect.width <= 8.0 || rect.height <= 8.0) {
        continue;
      }
      final radius = Radius.circular(8.0);
      final rrect = RRect.fromRectAndRadius(rect, radius);

      final accent = _accentFor(frame.kind);
      final isSelected =
          selectedGroupKey ==
          SequenceControlGroupInfo(
            kind: frame.kind,
            label: frame.label,
            startYCanvas: frame.startY,
            endYCanvas: frame.endY,
            branchCount: frame.branches.length,
            sourceLink: frame.sourceLink,
            sourceOpenLineIndex: frame.sourceOpenLineIndex,
          ).selectionKey;
      final containsChild = hasChildFrame(frame);
      final parentEmphasis = ((maxDepth - frame.depth) * 0.55).clamp(0.0, 2.0);
      final fillAlpha = containsChild
          ? 0.0
          : ((isSelected ? 0.24 : 0.12) - (depthRatio * 0.04)).clamp(
              0.06,
              0.28,
            );
      final borderAlpha = ((isSelected ? 0.98 : 0.72) - (depthRatio * 0.10))
          .clamp(0.45, 1.0);
      final fillPaint = Paint()
        ..color = accent.withValues(alpha: fillAlpha)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = accent.withValues(alpha: borderAlpha)
        ..strokeWidth = (isSelected ? 2.2 : 1.1) + parentEmphasis
        ..style = PaintingStyle.stroke;

      final ribbonWidth = (8.0 - (depthRatio * 2.0)).clamp(5.0, 8.0);
      final ribbonRect = Rect.fromLTWH(
        rect.left + 2.0,
        rect.top + 2.0,
        ribbonWidth,
        (rect.height - 4.0).clamp(8.0, rect.height),
      );
      final ribbonPaint = Paint()
        ..color = accent.withValues(
          alpha: (0.30 - (depthRatio * 0.08)).clamp(0.16, 0.32),
        )
        ..style = PaintingStyle.fill;

      canvas.drawRRect(rrect, fillPaint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(ribbonRect, const Radius.circular(6.0)),
        ribbonPaint,
      );
      canvas.drawRRect(rrect, borderPaint);

      final title = frame.label.isEmpty
          ? frame.kind
          : '${frame.kind} ${frame.label}';
      final titlePainter = TextPainter(
        text: TextSpan(
          text: title,
          style: TextStyle(
            color: accent.withValues(alpha: 0.95),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: rect.width - 16.0);
      titlePainter.paint(canvas, Offset(rect.left + 8.0, rect.top + 4.0));

      if (frame.kind == 'alt' && frame.branches.isNotEmpty) {
        final branchPaint = Paint()
          ..color = accent.withValues(alpha: 0.45)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;

        for (final branch in frame.branches) {
          final y = branch.y.clamp(rect.top + 16.0, rect.bottom - 12.0);
          canvas.drawLine(
            Offset(rect.left + 2.0, y),
            Offset(rect.right - 2.0, y),
            branchPaint,
          );

          if (branch.label.isNotEmpty) {
            final branchLabelPainter = TextPainter(
              text: TextSpan(
                text: 'else ${branch.label}',
                style: TextStyle(
                  color: accent.withValues(alpha: 0.88),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              textDirection: TextDirection.ltr,
              maxLines: 1,
              ellipsis: '...',
            )..layout(maxWidth: rect.width - 18.0);
            branchLabelPainter.paint(canvas, Offset(rect.left + 8.0, y + 2.0));
          }
        }
      }
    }
  }

  Color _accentFor(String kind) {
    switch (kind) {
      case 'opt':
        return const Color(0xFFFFC107);
      case 'loop':
        return const Color(0xFF66BB6A);
      case 'alt':
      default:
        return const Color(0xFF64C8FF);
    }
  }

  @override
  bool shouldRepaint(covariant _SequenceControlFramePainter oldDelegate) {
    return oldDelegate.frames != frames ||
        oldDelegate.leftCanvas != leftCanvas ||
        oldDelegate.rightCanvas != rightCanvas ||
        oldDelegate.selectedGroupKey != selectedGroupKey;
  }
}

class _SequenceMessageHandlePainter extends CustomPainter {
  final bool isSelected;

  const _SequenceMessageHandlePainter({required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final lineColor = isSelected
        ? const Color.fromARGB(255, 255, 165, 0)
        : const Color.fromARGB(200, 124, 216, 255);

    final y = size.height / 2;
    final lineStart = Offset(6.0, y);
    final lineEnd = Offset(size.width - 6.0, y);

    if (isSelected) {
      final glowPaint = Paint()
        ..color = const Color.fromARGB(120, 255, 165, 0)
        ..strokeWidth = 8.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(lineStart, lineEnd, glowPaint);
    }

    // final linePaint = Paint()
    //   ..color = lineColor.withValues(alpha: 0.95)
    //   ..strokeWidth = isSelected ? 3.0 : 2.0
    //   ..strokeCap = StrokeCap.round
    //   ..style = PaintingStyle.stroke;
    // canvas.drawLine(lineStart, lineEnd, linePaint);

    final knobPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    final knobOutline = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, y);
    canvas.drawCircle(center, 5.0, knobPaint);
    canvas.drawCircle(center, 5.0, knobOutline);
  }

  @override
  bool shouldRepaint(covariant _SequenceMessageHandlePainter oldDelegate) {
    return oldDelegate.isSelected != isSelected;
  }
}
