import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/widget_event_bus.dart';
import 'package:jsonschema/core/designer/widget_selectable.dart';
import 'package:jsonschema/core/designer/pages_designer.dart';

class WidgetOverlySelector extends StatefulWidget {
  const WidgetOverlySelector({super.key});

  @override
  State<WidgetOverlySelector> createState() => _WidgetOverlySelectorState();
}

class _WidgetOverlySelectorState extends State<WidgetOverlySelector> {
  CWRec position = CWRec();

  @override
  void dispose() {
    removeAllListener(CDDesignEvent.select);
    super.dispose();
  }

  @override
  void initState() {
    removeAllListener(CDDesignEvent.select);
    on(CDDesignEvent.select, (selected) {
      CWContext ctx = selected;
      initRecWithKeyPosition(ctx.keybox!, designerKey, position);
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: Duration(milliseconds: 200),
      top: position.top,
      left: position.left,
      child: IgnorePointer(
        child: Container(
          width: position.right - position.left,
          height: position.bottom - position.top,
          decoration: BoxDecoration(border: Border.all(color: Colors.blueGrey)),
        ),
      ),
    );
  }
}
