import 'dart:async';

import 'package:flutter/material.dart';

enum ShowcaseTooltipPosition { auto, above, below, left, right }

class ShowcaseCoachConfig {
  const ShowcaseCoachConfig({
    this.tooltipPosition = ShowcaseTooltipPosition.auto,
    this.primaryColor,
    this.buttonColor,
    this.overlayColor,
    this.overlayOpacity = 0.68,
    this.highlightPadding = const EdgeInsets.all(8),
    this.highlightBorderRadius = 16,
    this.dismissOnTapOutside = false,
  });

  final ShowcaseTooltipPosition tooltipPosition;
  final Color? primaryColor;
  final Color? buttonColor;
  final Color? overlayColor;
  final double overlayOpacity;
  final EdgeInsets highlightPadding;
  final double highlightBorderRadius;
  final bool dismissOnTapOutside;
}

class CoachStep {
  const CoachStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.showIf = true,
    this.onNext,
    this.onSkip,
    this.nextButtonText,
    this.skipButtonText,
    this.showSkipButton = true,
  });

  final GlobalKey targetKey;
  final String title;
  final List<String> description;
  final bool showIf;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;
  final String? nextButtonText;
  final String? skipButtonText;
  final bool showSkipButton;
}

class ShowcaseCoach {
  ShowcaseCoach._();

  static Future<void> show(
    BuildContext context, {
    required List<CoachStep> steps,
    ShowcaseCoachConfig? config,
    VoidCallback? onSkip,
    VoidCallback? onDone,
  }) async {
    final visibleSteps = steps.where((e) => e.showIf).toList();
    if (visibleSteps.isEmpty) {
      return;
    }

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      return;
    }

    final completer = Completer<void>();
    late OverlayEntry entry;

    void close() {
      if (entry.mounted) {
        entry.remove();
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    entry = OverlayEntry(
      builder: (_) => _ShowcaseOverlay(
        steps: visibleSteps,
        config: config ?? const ShowcaseCoachConfig(),
        onDone: () {
          onDone?.call();
          close();
        },
        onSkip: () {
          onSkip?.call();
          close();
        },
      ),
    );

    overlay.insert(entry);
    await completer.future;
  }
}

class _ShowcaseOverlay extends StatefulWidget {
  const _ShowcaseOverlay({
    required this.steps,
    required this.config,
    required this.onDone,
    required this.onSkip,
  });

  final List<CoachStep> steps;
  final ShowcaseCoachConfig config;
  final VoidCallback onDone;
  final VoidCallback onSkip;

  @override
  State<_ShowcaseOverlay> createState() => _ShowcaseOverlayState();
}

class _ShowcaseOverlayState extends State<_ShowcaseOverlay> {
  int _index = 0;

  CoachStep get _step => widget.steps[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureVisible();
    });
  }

  Future<void> _ensureVisible() async {
    final ctx = _step.targetKey.currentContext;
    if (ctx == null) {
      return;
    }
    // await Scrollable.ensureVisible(
    //   ctx,
    //   duration: const Duration(milliseconds: 260),
    //   curve: Curves.easeOutCubic,
    //   alignment: 0.35,
    // );
    if (mounted) {
      setState(() {});
    }
  }

  Rect? _targetRect() {
    final box =
        _step.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) {
      return null;
    }
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }

  void _next() {
    _step.onNext?.call();
    if (_index >= widget.steps.length - 1) {
      widget.onDone();
      return;
    }
    setState(() {
      _index += 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureVisible();
    });
  }

  void _skip() {
    _step.onSkip?.call();
    widget.onSkip();
  }

  @override
  Widget build(BuildContext context) {
    final rect = _targetRect();
    final size = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    final primary =
        widget.config.primaryColor ?? Theme.of(context).colorScheme.primary;
    final buttonColor = widget.config.buttonColor ?? primary;
    final overlayColor = widget.config.overlayColor ?? Colors.black;
    final holeRect = rect == null
        ? null
        : Rect.fromLTWH(
            rect.left - widget.config.highlightPadding.left,
            rect.top - widget.config.highlightPadding.top,
            rect.width +
                widget.config.highlightPadding.left +
                widget.config.highlightPadding.right,
            rect.height +
                widget.config.highlightPadding.top +
                widget.config.highlightPadding.bottom,
          );

    const spacing = 16.0;
    const horizontalPadding = 20.0;
    final spaceAbove = rect == null ? 0.0 : rect.top - safe.top - spacing;
    final spaceBelow = rect == null
        ? 0.0
        : size.height - rect.bottom - safe.bottom - spacing;
    final spaceLeft = rect == null ? 0.0 : rect.left - safe.left - spacing;
    final spaceRight = rect == null
        ? 0.0
        : size.width - rect.right - safe.right - spacing;

    final placeAbove = switch (widget.config.tooltipPosition) {
      ShowcaseTooltipPosition.above => true,
      ShowcaseTooltipPosition.below => false,
      ShowcaseTooltipPosition.left => false,
      ShowcaseTooltipPosition.right => false,
      ShowcaseTooltipPosition.auto => spaceAbove >= spaceBelow,
    };

    final requestedLeft =
        widget.config.tooltipPosition == ShowcaseTooltipPosition.left;
    final requestedRight =
        widget.config.tooltipPosition == ShowcaseTooltipPosition.right;

    final placeLeft = requestedLeft
        ? (spaceLeft >= 140 || spaceLeft >= spaceRight)
        : (requestedRight
              ? !(spaceRight >= 140 || spaceRight >= spaceLeft)
              : false);

    final useHorizontalPlacement = requestedLeft || requestedRight;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.config.dismissOnTapOutside ? _skip : null,
              behavior: HitTestBehavior.opaque,
              child: CustomPaint(
                painter: _OverlayPainter(
                  color: overlayColor.withValues(
                    alpha: widget.config.overlayOpacity,
                  ),
                  holeRect: holeRect,
                  radius: widget.config.highlightBorderRadius,
                ),
              ),
            ),
          ),
          if (holeRect != null)
            Positioned(
              left: holeRect.left,
              top: holeRect.top,
              width: holeRect.width,
              height: holeRect.height,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      widget.config.highlightBorderRadius,
                    ),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.transparent,
                        //color: primary.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (rect != null)
            (() {
              final card = _CoachCard(
                step: _step,
                index: _index,
                total: widget.steps.length,
                isLast: _index == widget.steps.length - 1,
                primary: primary,
                buttonColor: buttonColor,
                onNext: _next,
                onSkip: _skip,
              );

              if (useHorizontalPlacement) {
                final maxCardWidth = (size.width - (horizontalPadding * 2))
                    .clamp(220.0, 520.0);
                const estimatedCardHeight = 220.0;
                final left = placeLeft
                    ? (rect.left - spacing - maxCardWidth).clamp(
                        horizontalPadding,
                        size.width - maxCardWidth - horizontalPadding,
                      )
                    : (rect.right + spacing).clamp(
                        horizontalPadding,
                        size.width - maxCardWidth - horizontalPadding,
                      );
                final top = (rect.center.dy - (estimatedCardHeight / 2)).clamp(
                  safe.top + horizontalPadding,
                  size.height -
                      safe.bottom -
                      estimatedCardHeight -
                      horizontalPadding,
                );

                return Positioned(
                  left: left,
                  top: top,
                  width: maxCardWidth,
                  child: card,
                );
              }

              return Positioned(
                left: horizontalPadding,
                right: horizontalPadding,
                top: placeAbove ? null : rect.bottom + spacing,
                bottom: placeAbove
                    ? (size.height - rect.top + spacing).clamp(
                        horizontalPadding,
                        size.height - horizontalPadding,
                      )
                    : null,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: card,
                  ),
                ),
              );
            })()
          else
            Positioned(
              left: 20,
              right: 20,
              bottom: safe.bottom + 20,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: _CoachCard(
                    step: _step,
                    index: _index,
                    total: widget.steps.length,
                    isLast: _index == widget.steps.length - 1,
                    primary: primary,
                    buttonColor: buttonColor,
                    onNext: _next,
                    onSkip: _skip,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.color,
    required this.holeRect,
    required this.radius,
  });

  final Color color;
  final Rect? holeRect;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    if (holeRect == null) {
      canvas.drawRect(full, Paint()..color = color);
      return;
    }

    final overlayPaint = Paint()..color = color;
    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, overlayPaint);

    final clearPaint = Paint()..blendMode = BlendMode.clear;
    final rrect = RRect.fromRectAndRadius(holeRect!, Radius.circular(radius));
    canvas.drawRRect(rrect, clearPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.holeRect != holeRect ||
        oldDelegate.radius != radius;
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.step,
    required this.index,
    required this.total,
    required this.isLast,
    required this.primary,
    required this.buttonColor,
    required this.onNext,
    required this.onSkip,
  });

  final CoachStep step;
  final int index;
  final int total;
  final bool isLast;
  final Color primary;
  final Color buttonColor;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final desc = step.description.join('\n');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(172, 255, 255, 255),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${index + 1} / $total',
            style: TextStyle(
              color: primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            step.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF101828),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              color: Color(0xFF344054),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (step.showSkipButton)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: buttonColor,
                  ),
                  onPressed: onSkip,
                  child: Text(step.skipButtonText ?? 'Skip'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(step.nextButtonText ?? (isLast ? 'Done' : 'Next')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
