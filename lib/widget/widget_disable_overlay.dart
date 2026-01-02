import 'package:flutter/material.dart';

class WidgetToggleDisabled extends StatefulWidget {
  const WidgetToggleDisabled({
    super.key,
    required this.child,
    required this.toogle,
    required this.onTapForEnable,
    this.childOnDisabled,
  });
  final Widget child;
  final ValueNotifier<bool> toogle;
  final Function onTapForEnable;
  final Widget? childOnDisabled;

  @override
  State<WidgetToggleDisabled> createState() => _WidgetToggleDisabledState();
}

class _WidgetToggleDisabledState extends State<WidgetToggleDisabled> {
  bool isDisabled = true;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.toogle,
      builder: (context, value, child) {
        isDisabled = value;
        return DisabledOverlay(
          isDisabled: isDisabled,
          onTap: widget.onTapForEnable,
          childOnDisabled: widget.childOnDisabled,
          child: widget.child,
        );
      },
    );
  }
}

// 🔧 Composant réutilisable
class DisabledOverlay extends StatelessWidget {
  final Function onTap;
  final Widget child;
  final Widget? childOnDisabled;
  final bool isDisabled;
  final double overlayOpacity;
  final Duration animationDuration;

  const DisabledOverlay({
    super.key,
    required this.child,
    required this.isDisabled,
    this.overlayOpacity = 0.5,
    this.animationDuration = const Duration(milliseconds: 300),
    required this.onTap,
    this.childOnDisabled,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AbsorbPointer(absorbing: isDisabled, child: child),
        if (isDisabled)
          GestureDetector(
            onTap: () {
              onTap();
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                // borderRadius: BorderRadius.circular(12),
              ),
              child: childOnDisabled,
            ),
          ),

        // AnimatedOpacity(
        //   opacity: isDisabled ? overlayOpacity : 0.0,
        //   duration: animationDuration,
        //   child: Container(
        //     decoration: BoxDecoration(
        //       color: Colors.grey.withValues(alpha: overlayOpacity),
        //      // borderRadius: BorderRadius.circular(12),
        //     ),
        //   ),
        // ),
      ],
    );
  }
}
