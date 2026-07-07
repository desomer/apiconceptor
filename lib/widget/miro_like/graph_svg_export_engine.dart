import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jsonschema/widget/miro_like/layers/link_geometry_utils.dart'
    show
        borderPointFromUnit,
        getAnchorSpacingOffset,
        outwardTangentForLinkEndpoint,
        pointOnRectBorderTowards;
import 'package:jsonschema/widget/miro_like/models/block_model.dart';
import 'package:jsonschema/widget/miro_like/models/link_model.dart';

/// Generates a standalone SVG snapshot of the current Miro-like graph model.
///
/// This engine is intentionally UI-agnostic: it only depends on blocks/links
/// data and produces a SVG string.
class MiroLikeSvgExportEngine {
  const MiroLikeSvgExportEngine._();

  static String generate({
    required List<Block> blocks,
    required List<BlockLink> links,
    double padding = 64,
    String backgroundHex = '#303033',
  }) {
    final visibleBlocks = blocks.toList(growable: false);
    if (visibleBlocks.isEmpty) {
      return _emptySvg(backgroundHex);
    }

    final bounds = _computeBounds(visibleBlocks, links, padding: padding);
    final width = math.max(1.0, bounds.width);
    final height = math.max(1.0, bounds.height);

    final tx = -bounds.left;
    final ty = -bounds.top;

    final zoneBlocks = visibleBlocks.where((b) => b.isZone).toList();
    final normalBlocks = visibleBlocks.where((b) => !b.isZone).toList();

    final blockById = {for (final b in visibleBlocks) b.id: b};

    final svg = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<svg xmlns="http://www.w3.org/2000/svg" width="${_f(width)}" height="${_f(height)}" viewBox="0 0 ${_f(width)} ${_f(height)}">',
      )
      ..writeln('<defs>')
      ..writeln(
        '<marker id="arrowHead" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto" markerUnits="strokeWidth">'
        '<path d="M0,0 L10,3.5 L0,7 z" fill="#64C8FF"/>'
        '</marker>',
      )
      ..writeln('</defs>')
      ..writeln(
        '<rect x="0" y="0" width="${_f(width)}" height="${_f(height)}" fill="$backgroundHex"/>',
      );

    for (final zone in zoneBlocks) {
      _writeBlock(svg, zone, tx: tx, ty: ty, isZone: true);
    }

    for (final link in links) {
      final from = blockById[link.fromBlockId];
      final to = blockById[link.toBlockId];
      if (from == null || to == null) {
        continue;
      }
      _writeLink(
        svg,
        link,
        from,
        to,
        blocks: visibleBlocks,
        links: links,
        tx: tx,
        ty: ty,
      );
    }

    for (final block in normalBlocks) {
      _writeBlock(svg, block, tx: tx, ty: ty, isZone: false);
    }

    svg.writeln('</svg>');
    return svg.toString();
  }

  static String _emptySvg(String backgroundHex) {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="720" viewBox="0 0 1280 720">
  <rect x="0" y="0" width="1280" height="720" fill="$backgroundHex"/>
</svg>
''';
  }

  static Rect _computeBounds(
    List<Block> blocks,
    List<BlockLink> links, {
    required double padding,
  }) {
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;

    void includePoint(Offset p) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }

    for (final block in blocks) {
      includePoint(block.position);
      includePoint(
        Offset(
          block.position.dx + block.size.width,
          block.position.dy + block.size.height,
        ),
      );
    }

    for (final link in links) {
      for (final p in link.inflectionPoints) {
        includePoint(p);
      }
    }

    if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
      return Rect.fromLTWH(0, 0, 1280, 720);
    }

    return Rect.fromLTRB(
      minX - padding,
      minY - padding,
      maxX + padding,
      maxY + padding,
    );
  }

  static void _writeBlock(
    StringBuffer svg,
    Block block, {
    required double tx,
    required double ty,
    required bool isZone,
  }) {
    final x = block.position.dx + tx;
    final y = block.position.dy + ty;
    final w = block.size.width;
    final h = block.size.height;

    final fill = _colorToHex(
      kBlockColorMap[block.colorKey] ?? const Color(0xFF212124),
    );
    final stroke = isZone ? '#999999' : '#424245';
    final fillOpacity = isZone ? (block.zoneTransparent ? 0.05 : 0.2) : 0.96;

    switch (block.nodeShape) {
      case BlockNodeShape.circle:
      case BlockNodeShape.doubleCircle:
        final cx = x + w / 2;
        final cy = y + h / 2;
        final r = math.min(w, h) / 2;
        svg.writeln(
          '<circle cx="${_f(cx)}" cy="${_f(cy)}" r="${_f(r)}" fill="$fill" fill-opacity="${_f(fillOpacity)}" stroke="$stroke" stroke-width="1.2"/>',
        );
        if (block.nodeShape == BlockNodeShape.doubleCircle) {
          svg.writeln(
            '<circle cx="${_f(cx)}" cy="${_f(cy)}" r="${_f(math.max(0, r - 6))}" fill="none" stroke="$stroke" stroke-width="1.0"/>',
          );
        }
      case BlockNodeShape.hexagon:
        final p = [
          Offset(x + w * 0.2, y),
          Offset(x + w * 0.8, y),
          Offset(x + w, y + h * 0.5),
          Offset(x + w * 0.8, y + h),
          Offset(x + w * 0.2, y + h),
          Offset(x, y + h * 0.5),
        ];
        svg.writeln(
          '<polygon points="${p.map((e) => '${_f(e.dx)},${_f(e.dy)}').join(' ')}" fill="$fill" fill-opacity="${_f(fillOpacity)}" stroke="$stroke" stroke-width="1.2"/>',
        );
      case BlockNodeShape.parallelogram:
      case BlockNodeShape.parallelogramInverted:
      case BlockNodeShape.trapezoid:
      case BlockNodeShape.trapezoidInverted:
        final leftSkew =
            block.nodeShape == BlockNodeShape.parallelogramInverted ||
            block.nodeShape == BlockNodeShape.trapezoidInverted;
        final d = math.min(30.0, w * 0.2);
        final topInset =
            block.nodeShape == BlockNodeShape.trapezoid ||
            block.nodeShape == BlockNodeShape.trapezoidInverted;
        final p = topInset
            ? [
                Offset(x + (leftSkew ? d : 0), y),
                Offset(x + w - (leftSkew ? 0 : d), y),
                Offset(x + w, y + h),
                Offset(x, y + h),
              ]
            : [
                Offset(x + (leftSkew ? d : 0), y),
                Offset(x + w, y),
                Offset(x + w - (leftSkew ? d : 0), y + h),
                Offset(x, y + h),
              ];
        svg.writeln(
          '<polygon points="${p.map((e) => '${_f(e.dx)},${_f(e.dy)}').join(' ')}" fill="$fill" fill-opacity="${_f(fillOpacity)}" stroke="$stroke" stroke-width="1.2"/>',
        );
      case BlockNodeShape.person:
        final cx = x + w / 2;
        final headR = math.min(w, h) * 0.17;
        final headCy = y + h * 0.25;
        final bodyX = x + w * 0.12;
        final bodyY = y + h * 0.50;
        final bodyW = w * 0.76;
        final bodyH = h * 0.50;
        final rx = math.min(bodyW * 0.32, bodyH * 0.46);
        svg.writeln(
          '<circle cx="${_f(cx)}" cy="${_f(headCy)}" r="${_f(headR)}" fill="$fill" fill-opacity="${_f(fillOpacity)}" stroke="$stroke" stroke-width="1.2"/>',
        );
        svg.writeln(
          '<rect x="${_f(bodyX)}" y="${_f(bodyY)}" width="${_f(bodyW)}" height="${_f(bodyH)}" rx="${_f(rx)}" ry="${_f(rx)}" fill="$fill" fill-opacity="${_f(fillOpacity)}" stroke="$stroke" stroke-width="1.2"/>',
        );
      default:
        final rx =
            (block.nodeShape == BlockNodeShape.roundedRectangle ||
                block.nodeShape == BlockNodeShape.stadium)
            ? math.min(h * 0.35, 16.0).toDouble()
            : 4.0;
        svg.writeln(
          '<rect x="${_f(x)}" y="${_f(y)}" width="${_f(w)}" height="${_f(h)}" rx="${_f(rx)}" ry="${_f(rx)}" fill="$fill" fill-opacity="${_f(fillOpacity)}" stroke="$stroke" stroke-width="1.2"/>',
        );
    }

    final title = _escapeXml(block.title.trim());
    final fontSize = math.max(9.0, math.min(16.0, h * 0.12));
    final lines = _splitLabelLines(title, maxCharsPerLine: 26, maxLines: 3);
    final centerX = x + w / 2;
    final startY = y + h / 2 - ((lines.length - 1) * fontSize * 0.55);

    svg.writeln(
      '<text x="${_f(centerX)}" y="${_f(startY)}" fill="#FFFFFF" font-family="Segoe UI, Arial, sans-serif" font-size="${_f(fontSize)}" font-weight="600" text-anchor="middle">',
    );
    for (var i = 0; i < lines.length; i++) {
      svg.writeln(
        '<tspan x="${_f(centerX)}" dy="${i == 0 ? 0 : _f(fontSize * 1.2)}">${lines[i]}</tspan>',
      );
    }
    svg.writeln('</text>');

    if (!isZone) {
      _writeBlockTagSquares(svg, block, x: x, y: y, w: w, h: h);
    }
  }

  static void _writeBlockTagSquares(
    StringBuffer svg,
    Block block, {
    required double x,
    required double y,
    required double w,
    required double h,
  }) {
    final tags = block.tagColorKeys
        .where((k) => kBlockTagColorMap.containsKey(k))
        .toList(growable: false);
    if (tags.isEmpty) {
      return;
    }

    const size = 8.0;
    const gap = 4.0;
    final maxVisible = math.max(1, ((h - 16) / (size + gap)).floor());
    final visible = tags.take(maxVisible).toList(growable: false);

    var cy = y + 10.0;
    final cx = x + w - 14.0;
    for (final key in visible) {
      final c = _colorToHex(kBlockTagColorMap[key] ?? Colors.white);
      svg.writeln(
        '<rect x="${_f(cx)}" y="${_f(cy)}" width="${_f(size)}" height="${_f(size)}" rx="1.2" ry="1.2" fill="$c" stroke="#FFFFFF" stroke-width="0.8"/>',
      );
      cy += size + gap;
    }

    final hidden = tags.length - visible.length;
    if (hidden > 0) {
      svg.writeln(
        '<text x="${_f(cx + size / 2)}" y="${_f(math.min(y + h - 6, cy + 10))}" fill="#FFFFFF" font-family="Segoe UI, Arial, sans-serif" font-size="9" font-weight="700" text-anchor="middle">+$hidden</text>',
      );
    }
  }

  static void _writeLink(
    StringBuffer svg,
    BlockLink link,
    Block from,
    Block to, {
    required List<Block> blocks,
    required List<BlockLink> links,
    required double tx,
    required double ty,
  }) {
    final fromRect = Rect.fromLTWH(
      from.position.dx,
      from.position.dy,
      from.size.width,
      from.size.height,
    );
    final toRect = Rect.fromLTWH(
      to.position.dx,
      to.position.dy,
      to.size.width,
      to.size.height,
    );

    final via = link.inflectionPoints;
    final fromRef = via.isNotEmpty ? via.first : toRect.center;
    final toRef = via.isNotEmpty ? via.last : fromRect.center;

    final fromEdge = link.sourceAnchorUnit != null
        ? borderPointFromUnit(
            fromRect,
            link.sourceAnchorUnit!,
            spacingOffset: getAnchorSpacingOffset(
              currentLink: link,
              blockId: link.fromBlockId,
              anchorUnit: link.sourceAnchorUnit!,
              blocks: blocks,
              links: links,
              zoomLevel: 1,
              canvasOffset: Offset.zero,
            ),
          )
        : pointOnRectBorderTowards(fromRect, fromRef);

    final toEdge = link.targetAnchorUnit != null
        ? borderPointFromUnit(
            toRect,
            link.targetAnchorUnit!,
            spacingOffset: getAnchorSpacingOffset(
              currentLink: link,
              blockId: link.toBlockId,
              anchorUnit: link.targetAnchorUnit!,
              blocks: blocks,
              links: links,
              zoomLevel: 1,
              canvasOffset: Offset.zero,
            ),
          )
        : pointOnRectBorderTowards(toRect, toRef);

    final points = <Offset>[fromEdge, ...via, toEdge];
    final svgPoints = points
        .map((point) => Offset(point.dx + tx, point.dy + ty))
        .toList(growable: false);

    final startTangent = outwardTangentForLinkEndpoint(
      link: link,
      isSource: true,
      rect: fromRect,
      edgePoint: fromEdge,
      showSequenceParticipantLifelines: false,
      blocks: blocks,
      zoomLevel: 1,
      canvasOffset: Offset.zero,
    );
    final targetOutward = outwardTangentForLinkEndpoint(
      link: link,
      isSource: false,
      rect: toRect,
      edgePoint: toEdge,
      showSequenceParticipantLifelines: false,
      blocks: blocks,
      zoomLevel: 1,
      canvasOffset: Offset.zero,
    );
    final endTangent = Offset(-targetOutward.dx, -targetOutward.dy);

    final pathData = link.connectorType == ConnectorType.orthogonal
        ? _svgOrthogonalPath(svgPoints)
        : _svgBezierPath(
            svgPoints,
            startTangent: startTangent,
            endTangent: endTangent,
          );

    final stroke = _colorToHex(
      kLinkColorMap[link.colorKey] ?? const Color(0xFF64C8FF),
    );
    svg.writeln(
      '<path d="$pathData" fill="none" stroke="$stroke" stroke-width="2.0" marker-end="url(#arrowHead)"/>',
    );

    final label = link.name.trim();
    if (label.isNotEmpty) {
      _writeLinkLabel(svg, link, svgPoints, label, tx: 0, ty: 0);
    }
  }

  static void _writeLinkLabel(
    StringBuffer svg,
    BlockLink link,
    List<Offset> polyline,
    String label, {
    required double tx,
    required double ty,
  }) {
    final sample = _pointAndAngleOnPolyline(polyline, link.labelPosition);
    final normal = Offset(-math.sin(sample.$2), math.cos(sample.$2));

    final baseCenter = sample.$1 + (normal * 18) + link.labelOffset;

    final escaped = _escapeXml(label);
    final textWidth = math.max(26.0, math.min(230.0, escaped.length * 7.0));
    final textHeight = 16.0;

    final tagKeys = link.tagColorKeys
        .where((k) => kBlockTagColorMap.containsKey(k))
        .toList(growable: false);
    final tagCols = math.min(3, tagKeys.length);
    final tagRows = tagKeys.isEmpty ? 0 : (tagKeys.length / 3).ceil();
    final tagSize = 8.0;
    final tagGap = 2.0;
    final tagWidth = tagKeys.isEmpty
        ? 0.0
        : tagCols * tagSize + (tagCols - 1) * tagGap;
    final tagHeight = tagKeys.isEmpty
        ? 0.0
        : tagRows * tagSize + (tagRows - 1) * tagGap;
    final tagSpacing = tagKeys.isEmpty ? 0.0 : 6.0;

    final contentW = tagWidth + tagSpacing + textWidth;
    final contentH = math.max(textHeight, tagHeight);
    final padX = 8.0;
    final padY = 4.0;

    final left = baseCenter.dx - (contentW + padX * 2) / 2 + tx;
    final top = baseCenter.dy - (contentH + padY * 2) / 2 + ty;

    svg.writeln(
      '<rect x="${_f(left)}" y="${_f(top)}" width="${_f(contentW + padX * 2)}" height="${_f(contentH + padY * 2)}" rx="7" ry="7" fill="#121218" fill-opacity="0.78"/>',
    );

    var cx = left + padX;
    if (tagKeys.isNotEmpty) {
      for (var i = 0; i < tagKeys.length; i++) {
        final row = i ~/ 3;
        final col = i % 3;
        final color = _colorToHex(
          kBlockTagColorMap[tagKeys[i]] ?? Colors.white,
        );
        final tx0 = cx + col * (tagSize + tagGap);
        final ty0 =
            top + padY + (contentH - tagHeight) / 2 + row * (tagSize + tagGap);
        svg.writeln(
          '<rect x="${_f(tx0)}" y="${_f(ty0)}" width="${_f(tagSize)}" height="${_f(tagSize)}" rx="1.2" ry="1.2" fill="$color" stroke="#FFFFFF" stroke-width="0.8"/>',
        );
      }
      cx += tagWidth + tagSpacing;
    }

    final textY = top + padY + contentH / 2 + 4.5;
    svg.writeln(
      '<text x="${_f(cx)}" y="${_f(textY)}" fill="#FFFFFF" font-family="Segoe UI, Arial, sans-serif" font-size="12" font-weight="600">$escaped</text>',
    );
  }

  static (Offset, double) _pointAndAngleOnPolyline(
    List<Offset> points,
    double t,
  ) {
    if (points.isEmpty) {
      return (Offset.zero, 0.0);
    }
    if (points.length == 1) {
      return (points.first, 0.0);
    }

    final clamped = t.clamp(0.0, 1.0);
    final lengths = <double>[];
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final len = (points[i + 1] - points[i]).distance;
      lengths.add(len);
      total += len;
    }

    if (total <= 0) {
      final dir = points.last - points.first;
      return (points.first, math.atan2(dir.dy, dir.dx));
    }

    final target = total * clamped;
    var acc = 0.0;
    for (var i = 0; i < lengths.length; i++) {
      final seg = lengths[i];
      if (acc + seg >= target) {
        final local = seg == 0 ? 0.0 : (target - acc) / seg;
        final a = points[i];
        final b = points[i + 1];
        final p = Offset(
          a.dx + (b.dx - a.dx) * local,
          a.dy + (b.dy - a.dy) * local,
        );
        final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
        return (p, angle);
      }
      acc += seg;
    }

    final a = points[points.length - 2];
    final b = points.last;
    return (b, math.atan2(b.dy - a.dy, b.dx - a.dx));
  }

  static String _svgOrthogonalPath(List<Offset> points) {
    if (points.isEmpty) {
      return 'M0 0';
    }
    final routed = <Offset>[points.first];

    for (var i = 1; i < points.length; i++) {
      final from = routed.last;
      final to = points[i];
      final dx = to.dx - from.dx;
      final dy = to.dy - from.dy;

      if (dx.abs() < 0.001 || dy.abs() < 0.001) {
        routed.add(to);
        continue;
      }

      final horizontalFirst = dx.abs() >= dy.abs();
      routed.add(
        horizontalFirst ? Offset(to.dx, from.dy) : Offset(from.dx, to.dy),
      );
      routed.add(to);
    }

    final b = StringBuffer('M${_f(routed.first.dx)} ${_f(routed.first.dy)}');
    for (var i = 1; i < routed.length; i++) {
      b.write(' L${_f(routed[i].dx)} ${_f(routed[i].dy)}');
    }
    return b.toString();
  }

  static String _svgBezierPath(
    List<Offset> points, {
    Offset? startTangent,
    Offset? endTangent,
  }) {
    if (points.isEmpty) {
      return 'M0 0';
    }
    if (points.length == 1) {
      return 'M${_f(points.first.dx)} ${_f(points.first.dy)}';
    }

    final path = StringBuffer('M${_f(points.first.dx)} ${_f(points.first.dy)}');
    if (points.length == 2) {
      final cps = _bezierControlPoints(
        points[0],
        points[1],
        startTangent: startTangent,
        endTangent: endTangent,
      );
      path.write(
        ' C${_f(cps.$1.dx)} ${_f(cps.$1.dy)} ${_f(cps.$2.dx)} ${_f(cps.$2.dy)} ${_f(points[1].dx)} ${_f(points[1].dy)}',
      );
      return path.toString();
    }

    const tension = 1.0;
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];

      var c1 = p1 + ((p2 - p0) * (tension / 6));
      var c2 = p2 - ((p3 - p1) * (tension / 6));

      final segmentLength = (p2 - p1).distance;
      final handleLength = math.max(24.0, segmentLength * 0.45);

      if (i == 0 && startTangent != null) {
        final dir = _unitOrFallback(startTangent, const Offset(1, 0));
        c1 = p1 + dir * handleLength;
      }
      if (i == points.length - 2 && endTangent != null) {
        final dir = _unitOrFallback(endTangent, const Offset(-1, 0));
        c2 = p2 - dir * handleLength;
      }

      path.write(
        ' C${_f(c1.dx)} ${_f(c1.dy)} ${_f(c2.dx)} ${_f(c2.dy)} ${_f(p2.dx)} ${_f(p2.dy)}',
      );
    }

    return path.toString();
  }

  static (Offset, Offset) _bezierControlPoints(
    Offset from,
    Offset to, {
    Offset? startTangent,
    Offset? endTangent,
  }) {
    final delta = to - from;
    final distance = delta.distance;
    final curvature = math.max(40.0, distance * 0.35);

    if (startTangent != null || endTangent != null) {
      final startDir = _unitOrFallback(
        startTangent ?? delta,
        const Offset(1, 0),
      );
      final endDir = _unitOrFallback(endTangent ?? delta, const Offset(1, 0));
      return (from + startDir * curvature, to - endDir * curvature);
    }

    if (delta.dx.abs() >= delta.dy.abs()) {
      final dir = delta.dx >= 0 ? 1.0 : -1.0;
      return (
        from + Offset(curvature * dir, 0),
        to - Offset(curvature * dir, 0),
      );
    }

    final dir = delta.dy >= 0 ? 1.0 : -1.0;
    return (from + Offset(0, curvature * dir), to - Offset(0, curvature * dir));
  }

  static Offset _unitOrFallback(Offset value, Offset fallback) {
    final length = value.distance;
    if (length == 0) {
      return fallback;
    }
    return value / length;
  }

  static List<String> _splitLabelLines(
    String text, {
    required int maxCharsPerLine,
    required int maxLines,
  }) {
    if (text.isEmpty) {
      return const [''];
    }

    final words = text.split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';

    for (final word in words) {
      final candidate = current.isEmpty ? word : '$current $word';
      if (candidate.length <= maxCharsPerLine) {
        current = candidate;
        continue;
      }
      if (current.isNotEmpty) {
        lines.add(current);
      }
      current = word;
      if (lines.length >= maxLines - 1) {
        break;
      }
    }

    if (current.isNotEmpty && lines.length < maxLines) {
      lines.add(current);
    }

    if (lines.isEmpty) {
      lines.add(text);
    }

    if (lines.length > maxLines) {
      return lines.take(maxLines).toList(growable: false);
    }

    if (words.join(' ').length > lines.join(' ').length && lines.isNotEmpty) {
      final last = lines.last;
      lines[lines.length - 1] = last.length > 3
          ? '${last.substring(0, last.length - 1)}…'
          : '$last…';
    }

    return lines;
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _colorToHex(Color color) {
    final r = color.red.toRadixString(16).padLeft(2, '0');
    final g = color.green.toRadixString(16).padLeft(2, '0');
    final b = color.blue.toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  static String _f(double value) {
    return value.toStringAsFixed(2);
  }
}
