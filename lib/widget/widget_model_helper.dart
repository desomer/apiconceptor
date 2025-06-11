import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/main.dart';

mixin class WidgetModelHelper {
  Widget getChip(Widget content, {required Color? color, double? height}) {
    var w = Chip(
      labelPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 5),
      color: WidgetStatePropertyAll(color),
      padding: EdgeInsets.all(0),
      label: SelectionArea(child: content),
    );
    if (height != null) {
      return SizedBox(height: height, child: w);
    }
    return w;
  }

  List<Widget> getTooltipFromAttr(NodeAttribut attr) {
    List<Widget> tooltip = [];
    if (attr.info.properties != null) {
      for (var element in attr.info.properties!.entries) {
        if (!element.key.startsWith('\$\$')) {
          tooltip.add(Text('${element.key} = ${element.value}'));
        }
      }
    }

    if (tooltip.isEmpty) {
      tooltip.add(Text('No information'));
    }
    return tooltip;
  }

  Widget getToolTip({
    required List<Widget> toolContent,
    required Widget child,
  }) {
    return Tooltip(
      verticalOffset: 4,
      //triggerMode: TooltipTriggerMode.manual,
      showDuration: const Duration(milliseconds: 2500),
      waitDuration: const Duration(milliseconds: 500),

      richMessage: WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Container(
          padding: const EdgeInsets.all(10),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(children: toolContent),
        ),
      ),
      child: child,
    );
  }

  void addWidgetMasterId(NodeAttribut attr, List<Widget> row) {
    dynamic master = attr.info.properties?[constMasterID];
    if (master is Future) {
      row.add(
        getChip(
          FutureBuilder(
            future: attr.info.properties?[constMasterID],
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                attr.info.properties?[constMasterID] = snapshot.data.toString();
                return Text(snapshot.data.toString());
              } else {
                return Text('-');
              }
            },
          ),
          color: null,
        ),
      );
    } else {
      row.add(getChip(Text(master.toString()), color: null));
    }
  }
}
