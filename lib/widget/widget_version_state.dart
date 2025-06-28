import 'package:assorted_layout_widgets/assorted_layout_widgets.dart';
import 'package:flutter/material.dart';

class WidgetVersionState extends StatefulWidget {
  const WidgetVersionState({super.key, required this.margeVertical});
  final double margeVertical;

  @override
  State<WidgetVersionState> createState() => _WidgetVersionStateState();
}

class _WidgetVersionStateState extends State<WidgetVersionState> {
  @override
  Widget build(BuildContext context) {
    return RowSuper(
      mainAxisSize: MainAxisSize.min,
      innerDistance: -1,
      children: [
        _BreadButton(
          'W',
          true,
          margeVertical: widget.margeVertical,
          child: Icon(Icons.construction, size: 20),
        ),
        _BreadButton(
          'C',
          false,
          margeVertical: widget.margeVertical,
          child: Icon(Icons.check_circle, size: 20),
        ),
        _BreadButton(
          'I',
          false,
          margeVertical: widget.margeVertical,
          child: Icon(Icons.code, size: 20),
        ),
        _BreadButton(
          'F',
          false,
          margeVertical: widget.margeVertical,
          child: Icon(Icons.sports_score, size: 20),
        ),
      ],
    );
  }
}

class _BreadButton extends StatelessWidget {
  final String text;
  final bool isFirstButton;
  final Widget? child;
  final double margeVertical;

  // ignore: unused_element_parameter
  const _BreadButton(
    this.text,
    this.isFirstButton, {
    this.child,
    required this.margeVertical,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: TriangleClipper(!isFirstButton),
      child: Container(
        color: Colors.grey,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: isFirstButton ? 5 : 8,
            end: 8,
            top: margeVertical,
            bottom: margeVertical,
          ),
          child:
              child ??
              Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
        ),
      ),
    );
  }
}

class TriangleClipper extends CustomClipper<Path> {
  final bool twoSideClip;

  TriangleClipper(this.twoSideClip);

  @override
  Path getClip(Size size) {
    final Path path = Path();
    if (twoSideClip) {
      path.moveTo(0, 0.0);
      path.lineTo(5.0, size.height / 2);
      path.lineTo(0, size.height);
    } else {
      path.lineTo(0, size.height);
    }
    path.lineTo(size.width - 5, size.height);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(size.width - 5, 0);
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return true;
  }
}
