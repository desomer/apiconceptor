
import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';

abstract class Node {
  double x, y, dx = 0, dy = 0;
  Node(this.x, this.y, this.name, this.info);
  double height = 100;
  double width = 200;
  String name;
  AttributInfo info;
  ModelSchema? model; // Added to allow assignment to node.model

  Widget getWidget();
}

class ApiNode extends Node with WidgetModelHelper {
  ApiNode(super.x, super.y, super.name, super.info);

  @override
  Widget getWidget() {

    return Container(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.grey),
      ),
      child: Row(
        spacing: 5,
        children: [getHttpOpe(info.name) ?? Container(), Text(name)],
      ),
    );
  }
}

class ModelNode extends Node {
  ModelNode(super.x, super.y, super.name, super.info);
  int nbRow = 3; // 3 par defaut
  List<Widget> listRowYaml = [];

  @override
  Widget getWidget() {
    var scrollController = ScrollController();
    return Column(
      children: [
        Text(name, style: TextStyle(fontSize: 14)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(4),
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            border: Border.all(color: Colors.white, width: 1),
          ),
          alignment: Alignment.topLeft,
          child: Scrollbar(
            controller: scrollController,

            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: scrollController,
              child: ListView.builder(
                itemBuilder: (context, index) {
                  return listRowYaml.length > index
                      ? getOverflowHidden(listRowYaml[index])
                      : Container();
                },
                itemExtent: 19 * (zoom.value / 100),
                itemCount: nbRow,
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget getOverflowHidden(Widget child) {
    return SizedBox(
      height: 19 * (zoom.value / 100),
      child: OverflowBox(
        alignment: Alignment.topLeft,
        maxWidth: double.infinity,
        child: child,
      ),
    );
  }  
}