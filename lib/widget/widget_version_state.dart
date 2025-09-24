import 'package:assorted_layout_widgets/assorted_layout_widgets.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';

class WidgetVersionState extends StatefulWidget {
  const WidgetVersionState({super.key, required this.margeVertical});
  final double margeVertical;

  @override
  State<WidgetVersionState> createState() => _WidgetVersionStateState();
}

class _WidgetVersionStateState extends State<WidgetVersionState>
    with WidgetHelper {
  @override
  Widget build(BuildContext context) {
    GlobalKey k = GlobalKey();

   // BuildContext aCtx;

    return RowSuper(
      mainAxisSize: MainAxisSize.min,
      innerDistance: -1,
      children: [
        GestureDetector(
          onTap: () {
            dialogBuilderBelow(
              context,
              SizedBox(
                width: 110,
                height: 200,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.tips_and_updates),
                      title: Text('Idea'),
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.work_history),
                      title: Text('Design In Progress'),
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.sports_score),
                      title: Text('Design Finish'),
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                    ),                    
                  ],
                ),
              ),
              k,
              Offset(-40, -20),
              (BuildContext ctx) {
                //aCtx = ctx;
              },
            );
          },
          child: _BreadButton(
            key: k,
            'W',
            true,
            margeVertical: widget.margeVertical,
            color: Colors.greenAccent,
            child: Icon(Icons.construction, size: 20),
          ),
        ),

        _BreadButton(
          'C',
          false,
          margeVertical: widget.margeVertical,
          color: Colors.orangeAccent,
          child: Icon(Icons.check_circle, size: 20),
        ),
        _BreadButton(
          'I',
          false,
          margeVertical: widget.margeVertical,
          color: Colors.grey,
          child: Icon(Icons.code, size: 20),
        ),
        _BreadButton(
          'F',
          false,
          margeVertical: widget.margeVertical,
          color: Colors.grey,
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
  final Color color;

  // ignore: unused_element_parameter
  const _BreadButton(
    this.text,
    this.isFirstButton, {
    super.key,
    this.child,
    required this.margeVertical,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: TriangleClipper(!isFirstButton),
      child: Container(
        color: color,
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
