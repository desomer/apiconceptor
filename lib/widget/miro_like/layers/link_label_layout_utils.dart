import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:jsonschema/widget/miro_like/layers/connector_path_utils.dart'
    show buildConnectorPath;
import 'package:jsonschema/widget/miro_like/models/link_model.dart';
import 'package:jsonschema/widget/miro_like/widget_miro_like.dart';

class LinkLabelLayout {
  final bool isSelected;
  final TextPainter textPainter;
  final TextPainter? iconPainter;
  final EdgeInsets padding;
  final double iconSpacing;
  final double contentHeight;
  final Offset preferredCenter;
  Rect rect;

  LinkLabelLayout({
    required this.isSelected,
    required this.textPainter,
    required this.iconPainter,
    required this.padding,
    required this.iconSpacing,
    required this.contentHeight,
    required this.preferredCenter,
    required this.rect,
  });
}

LinkLabelLayout? buildLinkLabelLayout({
  required BlockLink link,
  required Offset from,
  required Offset to,
  required List<Offset> viaPoints,
  required double zoomLevel,
  required bool isSelected,
  Offset? startTangent,
  Offset? endTangent,
}) {
  final label = link.name.trim();
  if (label.isEmpty) {
    return null;
  }

  final path = buildConnectorPath(
    from,
    to,
    connectorType: link.connectorType,
    viaPoints: viaPoints,
    startTangent: startTangent,
    endTangent: endTangent,
  );

  final iterator = path.computeMetrics().iterator;
  if (!iterator.moveNext()) {
    return null;
  }

  final metric = iterator.current;
  if (metric.length <= 0) {
    return null;
  }

  final offsetOnPath = (metric.length * link.labelPosition).clamp(
    0.0,
    metric.length,
  );
  final midpoint = metric.getTangentForOffset(offsetOnPath);
  if (midpoint == null) {
    return null;
  }

  final normal = Offset(-math.sin(midpoint.angle), math.cos(midpoint.angle));
  final labelCenter =
      midpoint.position + normal * 18 + link.labelOffset * zoomLevel;
  final textScale = zoomLevel;

  final iconData = kLinkLabelIconMap[link.labelIconKey];
  final textPainter = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        color: isSelected ? colorLinkSelected : Colors.white,
        fontSize: (12.0 * textScale).clamp(1.0, 36.0),
        fontWeight: FontWeight.w600,
        shadows: const [
          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 220 * textScale);

  TextPainter? iconPainter;
  if (iconData != null) {
    iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontSize: (14.0 * textScale).clamp(1.0, 42.0),
          color: isSelected ? colorLinkSelected : Colors.white,
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
          shadows: const [
            Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  final padding = EdgeInsets.symmetric(
    horizontal: (8.0 * textScale).clamp(4.0, 20.0),
    vertical: (4.0 * textScale).clamp(2.0, 12.0),
  );
  final iconSpacing = iconPainter == null
      ? 0.0
      : (6.0 * textScale).clamp(3.0, 16.0);
  final contentWidth =
      (iconPainter?.width ?? 0.0) + iconSpacing + textPainter.width;
  final contentHeight = math.max(
    textPainter.height,
    iconPainter?.height ?? 0.0,
  );

  return LinkLabelLayout(
    isSelected: isSelected,
    textPainter: textPainter,
    iconPainter: iconPainter,
    padding: padding,
    iconSpacing: iconSpacing,
    contentHeight: contentHeight,
    preferredCenter: labelCenter,
    rect: Rect.fromCenter(
      center: labelCenter,
      width: contentWidth + padding.horizontal,
      height: contentHeight + padding.vertical,
    ),
  );
}

void resolveLinkLabelOverlaps(List<LinkLabelLayout> layouts) {
  if (layouts.length < 2) {
    return;
  }

  const spacing = 6.0;
  const maxIterations = 10;
  const maxOffsetFromPreferred = 72.0;

  for (int iteration = 0; iteration < maxIterations; iteration++) {
    var changed = false;

    for (int i = 0; i < layouts.length - 1; i++) {
      for (int j = i + 1; j < layouts.length; j++) {
        final a = layouts[i];
        final b = layouts[j];

        final dx = b.rect.center.dx - a.rect.center.dx;
        final dy = b.rect.center.dy - a.rect.center.dy;
        final overlapX = (a.rect.width + b.rect.width) / 2 + spacing - dx.abs();
        final overlapY =
            (a.rect.height + b.rect.height) / 2 + spacing - dy.abs();

        if (overlapX <= 0 || overlapY <= 0) {
          continue;
        }

        changed = true;
        if (overlapX < overlapY) {
          final sign = dx >= 0 ? 1.0 : -1.0;
          final shift = (overlapX / 2) + 0.5;
          a.rect = a.rect.shift(Offset(-sign * shift, 0));
          b.rect = b.rect.shift(Offset(sign * shift, 0));
        } else {
          final sign = dy >= 0 ? 1.0 : -1.0;
          final shift = (overlapY / 2) + 0.5;
          a.rect = a.rect.shift(Offset(0, -sign * shift));
          b.rect = b.rect.shift(Offset(0, sign * shift));
        }

        a.rect = _clampRectAroundPreferred(
          a.rect,
          a.preferredCenter,
          maxOffsetFromPreferred,
        );
        b.rect = _clampRectAroundPreferred(
          b.rect,
          b.preferredCenter,
          maxOffsetFromPreferred,
        );
      }
    }

    if (!changed) {
      break;
    }
  }
}

void paintLinkLabelLayout(
  Canvas canvas,
  LinkLabelLayout layout, {
  required double zoomLevel,
}) {
  final rect = layout.rect;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      rect,
      Radius.circular((8.0 * zoomLevel).clamp(4.0, 18.0)),
    ),
    Paint()
      ..color = layout.isSelected
          ? colorLinkSelected.withValues(alpha: 0.16)
          : const Color.fromARGB(190, 18, 18, 24)
      ..style = PaintingStyle.fill,
  );

  var paintX = rect.left + layout.padding.left;
  final contentTop = rect.top + layout.padding.top;
  if (layout.iconPainter != null) {
    layout.iconPainter!.paint(
      canvas,
      Offset(
        paintX,
        contentTop + (layout.contentHeight - layout.iconPainter!.height) / 2,
      ),
    );
    paintX += layout.iconPainter!.width + layout.iconSpacing;
  }

  layout.textPainter.paint(
    canvas,
    Offset(
      paintX,
      contentTop + (layout.contentHeight - layout.textPainter.height) / 2,
    ),
  );
}

Rect _clampRectAroundPreferred(
  Rect rect,
  Offset preferredCenter,
  double maxDistance,
) {
  var dx = rect.center.dx - preferredCenter.dx;
  var dy = rect.center.dy - preferredCenter.dy;
  final distance = math.sqrt((dx * dx) + (dy * dy));
  if (distance <= maxDistance || distance == 0) {
    return rect;
  }

  final ratio = maxDistance / distance;
  dx *= ratio;
  dy *= ratio;
  return Rect.fromCenter(
    center: Offset(preferredCenter.dx + dx, preferredCenter.dy + dy),
    width: rect.width,
    height: rect.height,
  );
}
