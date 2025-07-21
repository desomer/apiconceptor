import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/main.dart';

mixin class WidgetModelHelper {
  Widget? getHttpOpe(String name) {
    if (name == 'get') {
      return getChip(Text('GET'), color: Colors.green, height: 27);
    } else if (name == 'post') {
      return getChip(
        Text('POST', style: TextStyle(color: Colors.black)),
        color: Colors.yellow,
        height: 27,
      );
    } else if (name == 'put') {
      return getChip(Text('PUT'), color: Colors.blue, height: 27);
    } else if (name == 'patch') {
      return getChip(Text('PATCH'), color: Colors.indigoAccent, height: 27);
    } else if (name == 'delete') {
      return getChip(
        Text('DELETE', style: TextStyle(color: Colors.black)),
        color: Colors.redAccent.shade100,
        height: 27,
      );
    }
    return null;
  }

  Widget getChip(Widget content, {required Color? color, double? height}) {
    var w = Chip(
      labelPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 5),
      color: WidgetStatePropertyAll(color),
      padding: EdgeInsets.all(0),
      label: content, // SelectionArea(child: content),
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
          tooltip.add(
            Text(
              '${element.key} = ${element.value}',
              style: TextStyle(fontSize: 15),
            ),
          );
        } else if (element.key == constMasterID) {
          tooltip.insert(
            0,
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 1),
              decoration: BoxDecoration(
                border: BoxBorder.all(color: Colors.grey, width: 1),
              ),
              child: Text(
                'id = ${element.value}',
                style: TextStyle(fontSize: 11),
              ),
            ),
          );
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
    // if (true) return child;

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
