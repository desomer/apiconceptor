import 'package:flutter/material.dart';
import '../models/link_model.dart';

class SequenceMessageEntry {
  final BlockLink link;
  final double laneYCanvas;
  final double startXCanvas;
  final double endXCanvas;

  const SequenceMessageEntry({
    required this.link,
    required this.laneYCanvas,
    required this.startXCanvas,
    required this.endXCanvas,
  });
}

class SequenceMessageLayer extends StatelessWidget {
  final List<SequenceMessageEntry> entries;
  final BlockLink? selectedLink;
  final void Function(BlockLink link) onSelect;
  final void Function(BlockLink link) onDragStart;
  final void Function(BlockLink link, Offset globalPosition) onDragUpdate;
  final void Function(BlockLink link) onDragEnd;

  const SequenceMessageLayer({
    super.key,
    required this.entries,
    required this.selectedLink,
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

    return Stack(
      children: [
        for (final entry in entries)
          _buildMessageHandle(context, entry, selectedLink == entry.link),
      ],
    );
  }

  Widget _buildMessageHandle(
    BuildContext context,
    SequenceMessageEntry entry,
    bool isSelected,
  ) {
    final left = entry.startXCanvas < entry.endXCanvas
        ? entry.startXCanvas
        : entry.endXCanvas;
    final width = (entry.endXCanvas - entry.startXCanvas).abs().clamp(
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
          onTapDown: (_) => onSelect(entry.link),
          onPanStart: (_) {
            onSelect(entry.link);
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
}

class _SequenceMessageHandlePainter extends CustomPainter {
  final bool isSelected;

  const _SequenceMessageHandlePainter({required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final lineColor = isSelected
        ? const Color.fromARGB(255, 255, 165, 0)
        : const Color.fromARGB(200, 124, 216, 255);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = isSelected ? 3.2 : 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final y = size.height / 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

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
