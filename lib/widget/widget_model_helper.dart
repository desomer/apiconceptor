import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/main.dart';

mixin class WidgetModelHelper {
  Widget getChip(Widget content, {required Color? color, double? height }) {
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
