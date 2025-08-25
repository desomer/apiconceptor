import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class TooltipArrowPainter extends CustomPainter {
  final Size size;
  final Color color;
  final bool isInverted;

  TooltipArrowPainter({
    required this.size,
    required this.color,
    required this.isInverted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final path = Path();

    if (isInverted) {
      path.moveTo(0.0, size.height);
      path.lineTo(size.width / 2, 0.0);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0.0, 0.0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0.0);
    }

    path.close();

    canvas.drawShadow(path, Colors.black, 4.0, false);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TooltipArrow extends StatelessWidget {
  final Size size;
  final Color color;
  final bool isInverted;

  const TooltipArrow({
    super.key,
    this.size = const Size(16.0, 16.0),
    this.color = Colors.white,
    this.isInverted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(40.0, 0.0),
      child: CustomPaint(
        size: size,
        painter: TooltipArrowPainter(
          size: size,
          color: color,
          isInverted: isInverted,
        ),
      ),
    );
  }
}

// A tooltip with text, action buttons, and an arrow pointing to the target.
class AnimatedTooltip extends StatefulWidget {
  final Widget content;
  final GlobalKey? targetGlobalKey;
  final Duration? delay;
  final ThemeData? theme;
  final Widget? child;

  const AnimatedTooltip({
    super.key,
    required this.content,
    this.targetGlobalKey,
    this.theme,
    this.delay,
    this.child,
  }) : assert(child != null || targetGlobalKey != null);

  @override
  State<StatefulWidget> createState() => AnimatedTooltipState();
}

class AnimatedTooltipState extends State<AnimatedTooltip>
    with SingleTickerProviderStateMixin {
  late double? _tooltipTop;
  late double? _tooltipBottom;
  //late Alignment _tooltipAlignment;
  //late Alignment _transitionAlignment;
  //late Alignment _arrowAlignment;
  bool _isInverted = false;
  //Timer? _delayTimer;

  final _arrowSize = const Size(16.0, 16.0);
  final _tooltipMinimumHeight = 140;

  Offset? _cursorPosition;

  final _overlayController = OverlayPortalController();
  // late final AnimationController _animationController = AnimationController(
  //   duration: const Duration(milliseconds: 200),
  //   vsync: this,
  // );
  // late final Animation<double> _scaleAnimation = CurvedAnimation(
  //   parent: _animationController,
  //   curve: Curves.easeOutBack,
  // );

  void _toggle() {
    //_delayTimer?.cancel();
    //_animationController.stop();
    if (_overlayController.isShowing) {
      // _animationController.reverse().then((_) {
      _overlayController.hide();
      // });
    } else {
      _updatePosition();
      _overlayController.show();
      //_animationController.forward();
    }
  }

  double x = 0;

  void _updatePosition() {
    final Size contextSize = MediaQuery.of(context).size;
    final BuildContext? targetContext =
        widget.targetGlobalKey != null
            ? widget.targetGlobalKey!.currentContext
            : context;
    final targetRenderBox = targetContext?.findRenderObject() as RenderBox;
    final targetOffset = targetRenderBox.localToGlobal(Offset.zero);

    x = _cursorPosition!.dx;
    //targetRenderBox.localToGlobal(_cursorPosition!).dx;

    final targetSize = targetRenderBox.size;
    // Try to position the tooltip above the target,
    // otherwise try to position it below or in the center of the target.
    final tooltipFitsAboveTarget = targetOffset.dy - _tooltipMinimumHeight >= 0;
    final tooltipFitsBelowTarget =
        targetOffset.dy + targetSize.height + _tooltipMinimumHeight <=
        contextSize.height;
    _tooltipTop =
        tooltipFitsAboveTarget
            ? null
            : tooltipFitsBelowTarget
            ? targetOffset.dy + targetSize.height
            : null;
    _tooltipBottom =
        tooltipFitsAboveTarget
            ? contextSize.height - targetOffset.dy
            : tooltipFitsBelowTarget
            ? null
            : targetOffset.dy + targetSize.height / 2;
    // If the tooltip is below the target, invert the arrow.
    _isInverted = _tooltipTop != null;
    // Align the tooltip horizontally relative to the target.
    // _tooltipAlignment = Alignment(
    //   (targetOffset.dx) / (contextSize.width - targetSize.width) * 2 - 1.0,
    //   _isInverted ? 1.0 : -1.0,
    // );

    // Make the tooltip appear from the target.
    // _transitionAlignment = Alignment(
    //   (targetOffset.dx + targetSize.width / 2) / contextSize.width * 2 - 1.0,
    //   _isInverted ? -1.0 : 1.0,
    // );
    // Center the arrow horizontally on the target.
    // _arrowAlignment = Alignment(
    //   (targetOffset.dx + targetSize.width / 2) /
    //           (contextSize.width - _arrowSize.width) *
    //           2 -
    //       1.0,
    //   _isInverted ? 1.0 : -1.0,
    // );
  }

  @override
  void initState() {
    super.initState();
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   // If the tooltip is delayed, start a timer to show it.
    //   if (widget.delay != null) {
    //     _delayTimer = Timer(widget.delay!, _toggle);
    //   }
    // });
  }

  @override
  void dispose() {
    // _delayTimer?.cancel();
    // _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If no theme is provided,
    // use the opposite brightness of the current theme to make the tooltip stand out.
    final theme =
        widget.theme ??
        ThemeData(
          useMaterial3: true,
          brightness:
              Theme.of(context).brightness == Brightness.light
                  ? Brightness.dark
                  : Brightness.light,
        );

    return OverlayPortal.targetsRootOverlay(
      controller: _overlayController,
      child:
          widget.child != null
              ? MouseRegion(
                onEnter: (event) {
                  _cursorPosition = event.position;
                  _toggle();
                },
                onExit: (event) {
                  _toggle();
                },
                onHover: (PointerHoverEvent event) {
                  _cursorPosition =
                      event.position; // Position absolue dans l'écran
                  setState(() {
                    _updatePosition();
                  });
                },

                child: widget.child,
              )
              : null,
      overlayChildBuilder: (context) {
        return Positioned(
          top: _tooltipTop,
          bottom: _tooltipBottom,
          left: x - 40,
          // Provide a transition alignment to make the tooltip appear from the target.
          child: Theme(
            data: theme,
            // Don't allow the tooltip to get wider than the screen.
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isInverted)
                    TooltipArrow(
                      size: _arrowSize,
                      isInverted: true,
                      color: theme.canvasColor,
                    ),
                  IntrinsicWidth(
                    child: Material(
                      elevation: 4.0,
                      color: theme.canvasColor,
                      borderRadius: BorderRadius.circular(8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: widget.content,
                      ),
                    ),
                  ),

                  if (!_isInverted)
                    TooltipArrow(
                      size: _arrowSize,
                      isInverted: false,
                      color: theme.canvasColor,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
