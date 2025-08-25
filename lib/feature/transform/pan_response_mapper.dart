import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/api/call_manager.dart';
import 'package:jsonschema/widget/tree_editor/pan_yaml_tree.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_value_viewer.dart';

class PanResponseMapper extends StatefulWidget {
  const PanResponseMapper({super.key, required this.apiCallInfo});
  final APICallManager apiCallInfo;

  @override
  State<PanResponseMapper> createState() => _PanResponseMapperState();
}

class _PanResponseMapperState extends State<PanResponseMapper> {
  @override
  Widget build(BuildContext context) {
    Response? reponse = widget.apiCallInfo.aResponse?.reponse;
    Map? retJson;
    if (reponse?.data is Map) {
      retJson = reponse?.data;
    }
    return PanModelResponse(
      key: ObjectKey(reponse),
      retJson: retJson,
      getSchemaFct: () async {
        return widget.apiCallInfo.responseSchema!;
      },
      showable: () {
        return widget.apiCallInfo.responseSchema != null && retJson != null;
      },
    );
  }
}

// ignore: must_be_immutable
class PanModelResponse extends PanYamlTree {
  PanModelResponse({
    super.key,
    required super.getSchemaFct,
    required super.showable,
    required this.retJson,
  });
  final Map? retJson;
  Map<String, int> idxArray = {};

  @override
  void addRowWidget(
    TreeNodeData<NodeAttribut> node,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    var attr = node.data;
    var path = attr.info.getJsonPath().split('.');
    dynamic value = retJson;
    StringBuffer curPath = StringBuffer("root");
    List? lastArray;
    bool parentNull = false;

    for (var i = 1; i < path.length; i++) {
      var p = path[i];
      curPath.write('.$p');

      if (value != null) {
        if (p.endsWith('[]')) {
          p = p.substring(0, p.length - 2);
          lastArray = (value[p] as List?);
          if (lastArray != null) {
            int? idxa = idxArray[curPath.toString()];
            if (idxa == null) {
              idxa = 0;
              idxArray[curPath.toString()] = idxa;
            } else if (idxa >= lastArray.length) {
              idxa = lastArray.length - 1;
              idxArray[curPath.toString()] = idxa;
            }
            if (lastArray.isNotEmpty) {
              value = lastArray[idxa];
            } else {
              // tableau vide
              value = null;
            }
          } else {
            // tableau non instancier
            lastArray = null;
            value = null;
            parentNull = parentNull || (i < path.length - 1);
          }
        } else {
          // attribut normal
          value = value[p];
          if (value == null) {
            lastArray = null;
            parentNull = parentNull || (i < path.length - 1);
          }
        }
      } else {
        // valeur null
        lastArray = null;
        parentNull = parentNull || (i < path.length - 1);
      }
    }

    if ((attr.info.type == 'Array') && lastArray != null) {
      // si taleau de json
      row.addAll(getNextPrevBtn(attr));
      var key = curPath.toString();
      row.add(Text(' ${(idxArray[key] ?? -1) + 1} / ${lastArray.length}'));
    } else if (attr.info.type.endsWith('[]') && lastArray != null) {
      // si taleau de string / number
      row.add(
        SelectableText(
          key: ValueKey(value),
          lastArray.toString(),
          style: TextStyle(color: Color.fromARGB(255, 230, 219, 116)),
        ),
      );
    } else if (value is Map) {
      // si objet
    } else {
      var data = value?.toString() ?? 'null';
      if (data.length > 50) {
        row.add(ValueViewer(longText: data));
      }

      // si attribut
      row.add(
        SelectableText(
          key: ValueKey(value),
          data,
          style: TextStyle(
            color:
                value == null
                    ? (parentNull ? Colors.grey : Colors.red)
                    : Color.fromARGB(255, 230, 219, 116),
          ),
        ),
      );
    }
  }

  @override
  bool isReadOnly() {
    return true;
  }

  @override
  bool withEditor() {
    return false;
  }

  List<Widget> getNextPrevBtn(NodeAttribut attr) {
    return [
      InkWell(
        child: Icon(Icons.arrow_left),
        onTap: () {
          var path = attr.info.getJsonPath();
          attr.info.cacheRowWidget = null;
          if (idxArray[path]! > 0) {
            idxArray[path] = idxArray[path]! - 1;
            reinitChildIndex(path);
            attr.repaint();
            attr.repaintChild();
          }
        },
      ),
      InkWell(
        child: Icon(Icons.arrow_right),
        onTap: () {
          var path = attr.info.getJsonPath();
          attr.info.cacheRowWidget = null;
          idxArray[path] = idxArray[path]! + 1;
          reinitChildIndex(path);
          attr.repaint();
          attr.repaintChild();
        },
      ),
    ];
  }

  void reinitChildIndex(String path) {
    List<String> toRemove = [];
    for (var element in idxArray.entries) {
      if (element.key != path && element.key.startsWith(path)) {
        toRemove.add(element.key);
      }
    }
    for (var key in toRemove) {
      idxArray.remove(key);
    }
  }
}
