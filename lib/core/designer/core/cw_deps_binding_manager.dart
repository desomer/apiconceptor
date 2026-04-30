import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';

import '../../../feature/content/widget/widget_content_input.dart';

class CwDepsBindingManager {
  // liste des input controleur actif
  final Map<String, List<WidgetBindJsonState>> listInputByPath = {};
  final Map<String, List<State>> listContainerByPath = {};
  final Map<String, Map<String, CwWidgetStateBindJson>>
  listDepsContainerByPath = {};

  void registerInput(String pathData, WidgetBindJsonState ctrl) {
    var list = listInputByPath[pathData];
    if (list == null) {
      list = [];
      listInputByPath[pathData] = list;
    }
    if (!list.contains(ctrl)) {
      list.add(ctrl);
    }
    // if (ctrl.widget is CwWidget) {
    //   print(
    //     "register input for ${(ctrl.widget as CwWidget).ctx.aWidgetPath} ctrl=${ctrl.hashCode} total=${list.length} w=${(ctrl.widget as CwWidget).hashCode}",
    //   );
    // }

    list.removeWhere((role) => role.mounted == false);
  }

  void disposeInput(String pathData, WidgetBindJsonState ctrl) {
    var list = listInputByPath[pathData];
    list?.removeWhere((role) => role == ctrl);
    if (list != null && list.isEmpty) {
      listInputByPath.remove(pathData);
    }
  }

  void registerContainer(String pathData, State widgetState) {
    var list = listContainerByPath[pathData];
    if (list == null) {
      list = [];
      listContainerByPath[pathData] = list;
    }
    if (!list.contains(widgetState)) {
      list.add(widgetState);
    }
    list.removeWhere((role) => role.mounted == false);
    //print("addContainer $pathData");
  }

  void disposeContainer(String pathData, State widgetState) {
    var list = listContainerByPath[pathData];
    list?.removeWhere((role) => role == widgetState);
    if (list != null && list.isEmpty) {
      listContainerByPath.remove(pathData);
    }
  }

  void registerRepaintOnSelect(
    String pathWidget,
    String pathData,
    CwWidgetStateBindJson state,
  ) {
    //remove all idx
    pathData = pathData.replaceAll(RegExp(r'\[\d+\]'), '[]');
    var pathDeps = listDepsContainerByPath.putIfAbsent(pathData, () => {});
    print(
      ' register repaint on select for $pathData on $state $pathWidget hash= ${state.hashCode} w=${state.widget.hashCode} ',
    );
    pathDeps[pathWidget] = state;
  }

  void reloadDependentContainers(String pathData) {
    var p = pathData.split('/');
    var pathContainer = '';
    for (var i = 1; i < p.length; i++) {
      var path = p[i];
      if (path.endsWith(']')) {
        var startIdx = path.indexOf('[');
        String arrayName = path.substring(0, startIdx);
        var pc = '$pathContainer/$arrayName'.replaceAll(
          RegExp(r'\[\d+\]'),
          '[]',
        );

        //print(" reload dependent containers for $pc id= ${repository.hashCode}");
        List<String> listDepsToRemove = [];
        listDepsContainerByPath[pc]?.forEach((key, element) {
          //print("repaint container $key for element $element ${element.pathData} ");
          if (element.mounted) {
            element.widget.ctx.repaint();
          } else {
            listDepsToRemove.add(key);
          }
        });
        for (var key in listDepsToRemove) {
          listDepsContainerByPath[pc]?.remove(key);
        }
      }
      pathContainer += '/$path';
    }
  }
}
