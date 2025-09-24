import 'package:flutter/material.dart';

class WidgetExpansive extends StatefulWidget {
  const WidgetExpansive({
    super.key,
    required this.child,
    required this.color,
    required this.headers,
  });
  final Widget child;
  final Color color;
  final List<Widget> headers;

  @override
  State<WidgetExpansive> createState() => _WidgetExpansiveState();
}

class _WidgetExpansiveState extends State<WidgetExpansive> {
  late ExpansibleController controller;

  @override
  void initState() {
    controller = ExpansibleController();
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    controller.expand();

    return Expansible(
      controller: controller,
      headerBuilder:
          (_, animation) => GestureDetector(
            onTap: () {
              controller.isExpanded
                  ? controller.collapse()
                  : controller.expand();
            },
            child: Container(
              //padding: EdgeInsets.symmetric(horizontal: 10),
              //width: double.infinity,
              decoration: BoxDecoration(
                color: widget.color,
                //border: Border.all(color: Colors.white54, width: 1),
              ),
              child: Row(
                spacing: 10,
                children: [
                  Icon(Icons.arrow_circle_down_sharp),
                  ...widget.headers,
                  //Spacer(),
                ],
              ),
            ),
          ),
      bodyBuilder:
          (_, animation) =>
              FadeTransition(opacity: animation, child: widget.child),
      expansibleBuilder:
          (_, header, body, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [header, body],
          ),
    );
  }
}
