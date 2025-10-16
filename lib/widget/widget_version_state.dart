import 'package:assorted_layout_widgets/assorted_layout_widgets.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';

class WidgetVersionState extends StatefulWidget {
  const WidgetVersionState({
    super.key,
    required this.margeVertical,
    required this.version,
    this.model,
    this.attr,
  });
  final double margeVertical;
  final ModelSchema? model;
  final NodeAttribut? attr;
  final ModelVersion? version;

  @override
  State<WidgetVersionState> createState() => _WidgetVersionStateState();
}

class _WidgetVersionStateState extends State<WidgetVersionState>
    with WidgetHelper {
  BuildContext? aCtx;

  var listOptionsDesign = [
    Options(
      label: 'Idea',
      name: 'idea',
      color: Colors.grey,
      icon: Icons.tips_and_updates,
    ),
    Options(
      label: 'Design In Progress',
      name: 'inprogress',
      color: Colors.orangeAccent,
      icon: Icons.work_history,
    ),
    Options(
      label: 'Design Finish',
      name: 'finish',
      color: Colors.greenAccent,
      icon: Icons.sports_score,
    ),
  ];

  var listOptionsCheck = [
    Options(
      label: 'Waiting',
      name: 'waiting',
      color: Colors.grey,
      icon: Icons.hourglass_empty,
    ),
    Options(
      label: 'Check In Progress',
      name: 'inprogress',
      color: Colors.blue,
      icon: Icons.work_history,
    ),
    Options(
      label: 'Rejected',
      name: 'rejected',
      color: Colors.red,
      icon: Icons.close,
    ),    
    Options(
      label: 'Check OK',
      name: 'finish',
      color: Colors.greenAccent,
      icon: Icons.sports_score,
    ),
  ];  

  var listOptionsDev = [
    Options(
      label: 'Waiting',
      name: 'waiting',
      color: Colors.grey,
      icon: Icons.hourglass_empty,
    ),
    Options(
      label: 'Implementation In Progress',
      name: 'inprogress',
      color: Colors.blue,
      icon: Icons.work_history,
    ),  
    Options(
      label: 'Terminated',
      name: 'finish',
      color: Colors.greenAccent,
      icon: Icons.sports_score,
    ),
  ]; 

  var listFinishCheck = [
    Options(
      label: 'Waiting',
      name: 'waiting',
      color: Colors.grey,
      icon: Icons.hourglass_empty,
    ),
    Options(
      label: 'Validate in Progress',
      name: 'inprogress',
      color: Colors.blue,
      icon: Icons.work_history,
    ),
    Options(
      label: 'Rejected',
      name: 'rejected',
      color: Colors.red,
      icon: Icons.close,
    ),    
    Options(
      label: 'Check OK',
      name: 'finish',
      color: Colors.greenAccent,
      icon: Icons.sports_score,
    ),
  ];  

  @override
  Widget build(BuildContext context) {
    return RowSuper(
      mainAxisSize: MainAxisSize.min,
      innerDistance: -1,
      children: [
        getWidgetDesignState('design', listOptionsDesign, Icons.construction),
        getWidgetDesignState('check', listOptionsCheck, Icons.check_circle),
        getWidgetDesignState('implement', listOptionsDev, Icons.code),
        getWidgetDesignState('finish', listFinishCheck, Icons.sports_score),
      ],
    );
  }

  Widget getWidgetDesignState(
    String step,
    List<Options> listOptions,
    IconData icon,
  ) {
    var state = widget.version?.data['state'];
    Color color = Colors.grey;

    if (state == null && widget.model != null && widget.attr != null) {
      state =
          ModelAccessorAttr(
            node: widget.attr!,
            schema: widget.model!,
            propName: '#versionState',
          ).get();
    }

    if (state is Map) {
      var dstate = state[step];
      color =
          listOptions
              .firstWhere(
                (element) => element.name == dstate,
                orElse: () => listOptions[0],
              )
              .color;
    }

    GlobalKey k = GlobalKey();
    var btn = _BreadButton(
      key: k,
      '',
      true,
      margeVertical: widget.margeVertical,
      color: color,
      child: Icon(icon, size: 20),
    );

    if (widget.version == null) return btn;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          dialogBuilderBelow(
            context,
            SizedBox(
              width: 110,
              height: 200,
              child: Column(
                children:
                    listOptions.map<Widget>((option) {
                      return ListTile(
                        leading: Icon(option.icon, color: option.color),
                        title: Text(option.label),
                        onTap: () {
                          changeState(step, option.name);
                        },
                      );
                    }).toList(),
              ),
            ),
            k,
            Offset(-40, -20),
            (BuildContext ctx) {
              aCtx = ctx;
            },
          );
        },
        child: btn,
      ),
    );
  }

  void changeState(String step, String name) {
    Navigator.of(aCtx!).pop();
    setState(() {
      var state = widget.version?.data['state'];
      if (state is! Map) {
        state = {step: name};
        widget.version!.data['state'] = state;
      }
      state[step] = name;
      bddStorage.storeVersion(widget.model!, widget.version!);

      if (widget.version == widget.model!.versions!.first) {
        var accessor = ModelAccessorAttr(
          node: currentCompany.listModel!.selectedAttr!,
          schema: currentCompany.listModel!,
          propName: '#versionState',
        );
        accessor.set(state);
      }
    });
  }
}

class Options {
  final String label;
  final Color color;
  final String name;
  final IconData icon;

  Options({
    required this.color,
    required this.name,
    required this.label,
    required this.icon,
  });
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
