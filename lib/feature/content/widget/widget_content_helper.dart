import 'package:flutter/material.dart';
import 'package:jsonschema/core/export/export2ui.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/feature/content/browser_pan.dart';
import 'package:jsonschema/feature/content/json_to_ui.dart';
import 'package:jsonschema/feature/content/state_manager.dart';
import 'package:jsonschema/feature/content/widget/widget_content_input.dart';

class WidgetConfigInfo {
  final String name;
  final GenericToUi json2ui;
  Function? onTapSetting;

  String? pathValue;
  String? pathData;
  String? pathTemplate;

  dynamic inArrayValue;
  PanInfo? panInfo;

  WidgetConfigInfo({required this.json2ui, required this.name});

  void setPathData(String path) {
    pathData = path;
  }

  void setPathValue(String path) {
    pathValue = path;
  }
}

class InfoTemplate {
  String path;
  bool anyOf = false;
  bool isArray = false;
  PanInfoObject? panInfoChoised;

  InfoTemplate({required this.path});
}

class InputDesc {
  String messageTooltip = '';
  List<String>? choiseItem;
  InputType typeInput = InputType.text;
  bool isRequired = false;
  String? link;
}

mixin WidgetUIHelper {
  final StateManager stateMgr = StateManager();
  bool haveTemplate = false; // sans jsonSchemas
  bool modeTemplate = false; // plus utile

  String replaceAllIndexes(String input) {
    return input.replaceAllMapped(RegExp(r'\[\d+\]'), (match) => '[*]');
  }

  Widget getArrayItemAction(
    int i,
    Widget w,
    dynamic rowData,
    Key? k,
    Function onDelete,
  ) {
    return IntrinsicHeight(
      child: Row(
        key: k,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            width: 50,
            color: Colors.blue,
            child: Row(
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      onDelete();
                    },
                    child: Icon(Icons.delete),
                  ),
                ),
                Expanded(child: Center(child: Text('$i'))),
              ],
            ),
          ),
          Expanded(child: w),
        ],
      ),
    );
  }

  WidgetTyped getObjectInput(
    GenericToUi genui,
    PanInfo? panInfo,
    UIParamContext ctx,
  ) {
    return WidgetTyped(
      name: ctx.attrName,
      content: ctx.data,
      type: WidgetType.input,
      height: -1,
      widget: WidgetContentInput(
        key: ObjectKey(ctx.data), // obligatoire pour les onglets
        info:
            WidgetConfigInfo(json2ui: genui, name: ctx.attrName)
              ..inArrayValue = (ctx.parentType == WidgetType.list)
              ..setPathValue(ctx.path)
              ..setPathData(ctx.pathData)
              ..panInfo = panInfo,
      ),
    );
  }

  StateContainer? getState(String pathData) {
    var p = pathData.split('/');
    StateContainer? last;
    if (p.length == 1) {
      return stateMgr.statesTreeData[""];
    }
    last = stateMgr.statesTreeData[""];
    for (var i = 1; i < p.length; i++) {
      last = last?.stateChild[p[i]];
    }
    return last;
  }

  void setValue(
    WidgetConfigInfo info,
    InputType type,
    String pathDataContainer,
    dynamic value,
  ) {
    int idx = -1;
    var pathData = pathDataContainer;
    if (pathData.endsWith(']')) {
      pathData = pathData.substring(0, pathData.length - 1);
      int end = pathData.lastIndexOf('[');
      String idxTxt = pathData.substring(end + 1);
      pathData = pathData.substring(0, end);
      idx = int.parse(idxTxt);
    }

    var dataContainer = info.json2ui.getState(pathData);
    if (dataContainer != null) {
      var data = dataContainer.jsonData;
      dynamic row;
      dynamic val;
      if (data is List) {
        if (idx >= 0) {
          row = data[idx];
        }
        if (row is Map) {
          idx = -1;
          data = row;
          val = data[info.name];
        } else {
          // cas de liste de String, int
          val = row;
        }
      } else {
        val = data[info.name];
      }

      if (value != val?.toString()) {
        if (idx >= 0) {
          data[idx] = getValue(type, value);
        } else {
          data[info.name] = getValue(type, value);
        }
      }
    }
  }

  dynamic getValue(InputType type, String val) {
    switch (type) {
      case InputType.bool:
        return val.toLowerCase() == 'true';
      case InputType.num:
        return int.tryParse(val) ?? double.tryParse(val);
      default:
        return val;
    }
  }

  InputDesc getInputDesc(WidgetConfigInfo info) {
    InputDesc inputDesc = InputDesc();

    var pathData = info.pathData!;
    pathData = pathData.replaceAll("/$cstAnyChoice", '');

    StateContainer? dataTemplate;

    if (info.json2ui.modeTemplate) {
      dataTemplate = info.json2ui.stateMgr.stateTemplate[pathData];
    }

    var stateWidget = info.json2ui.getState(pathData);
    var displayData = stateWidget?.jsonData;
    var pathTemplate = pathData;
    var attrName = info.name;
    inputDesc.isRequired = false;

    if (info.inArrayValue == true) {
      // gestion des tableau de String, int, etc..
      var lastIndexOf = pathTemplate.lastIndexOf('/');
      var p = pathTemplate.substring(0, lastIndexOf);
      attrName = pathTemplate.substring(lastIndexOf + 1);
      pathTemplate = p;
      pathData = pathTemplate;
    }

    // cherche le template
    if (info.json2ui.haveTemplate && displayData != null) {
      if (info.pathTemplate == null) {
        pathTemplate =
            stateWidget!.currentTemplate ??
            getInfoTemplate(info, pathData, false).path;
        info.pathTemplate = pathTemplate;
      } else {
        pathTemplate = info.pathTemplate!;
      }

      dataTemplate = info.json2ui.stateMgr.stateTemplate[pathTemplate];
    }

    // cherche la Attribut info du template
    var template = dataTemplate?.jsonTemplate[attrName];
    if (info.panInfo != null) {
      template = info.panInfo!.dataJsonSchema;
    }

    if (template is Map) {
      AttributInfo? propAttribut;
      if (template[cstProp] != null) {
        propAttribut = template[cstProp];
        inputDesc.messageTooltip = propAttribut!.properties.toString();
      }

      if (propAttribut != null) {
        switch (propAttribut.type) {
          case 'number':
            inputDesc.typeInput = InputType.num;
            break;
          case 'boolean':
            inputDesc.typeInput = InputType.bool;
            break;
          default:
            inputDesc.typeInput = InputType.text;
        }
        if (propAttribut.properties?['enum'] != null) {
          inputDesc.typeInput = InputType.choise;
          inputDesc.choiseItem =
              propAttribut.properties!['enum']
                  .toString()
                  .split('\n')
                  .map((e) => e.trim())
                  .toList();
          if (!inputDesc.choiseItem!.contains('')) {
            inputDesc.choiseItem!.insert(0, '');
          }
        }
        if (propAttribut.properties?['#link'] != null) {
          inputDesc.typeInput = InputType.link;
          inputDesc.link = propAttribut.properties?['#link'];
        }
        if (propAttribut.properties?['required'] == true) {
          inputDesc.isRequired = true;
        }
      }
    } else if (!info.json2ui.modeTemplate) {
      print("no found $pathData");
      if (inputDesc.typeInput == InputType.choise) {
        inputDesc.typeInput = InputType.text;
      }
    }
    return inputDesc;
  }

  InfoTemplate getInfoTemplate(
    WidgetConfigInfo info,
    String pathData,
    bool withChoise,
  ) {
    if (info.panInfo != null) {
      // pas de template
      var infoTemplate = InfoTemplate(path: pathData);
      infoTemplate.isArray =
          info.panInfo!.type == 'Array' ||
          info.panInfo!.type == 'PrimitiveArray';

      if (info.panInfo!.type == 'Array') {
        PanInfoObject rowTemplate =
            (info.panInfo as PanInfoObject).children.first as PanInfoObject;
        infoTemplate.anyOf = rowTemplate.children.length > 1;
        if (infoTemplate.anyOf && withChoise) {
          var stateContainer = info.json2ui.getState(pathData);
          var data = stateContainer?.jsonData;
          infoTemplate.panInfoChoised = _getTemplateCompliant(
            info,
            data,
            rowTemplate,
          );
        }
      }

      return infoTemplate;
    } else {
      var s = pathData.split('/');
      pathData = '';
      InfoTemplate infoTemplate = InfoTemplate(path: '');
      var stateTemplate = info.json2ui.stateMgr.stateTemplate;
      for (var i = 0; i < s.length; i++) {
        String p = s[i];
        int idx = -1;
        if (p.endsWith(']')) {
          p = p.substring(0, s[i].length - 1);
          int end = p.lastIndexOf('[');
          String idxTxt = p.substring(end + 1);
          p = p.substring(0, end);
          idx = int.parse(idxTxt);
        }
        if (p != "") {
          infoTemplate.path = '${infoTemplate.path}/$p';
          if (idx >= 0) {
            pathData = '$pathData/$p[$idx]';
          } else {
            pathData = '$pathData/$p';
          }
        }
        var stateContainer = info.json2ui.getState(pathData);
        var data = stateContainer?.jsonData;

        if (idx == -1 && data != null) {
          StateContainer? t = stateTemplate[infoTemplate.path];
          // y a t'il plusieur possibilite
          if (t is StateContainerObjectAny) {
            infoTemplate.path = _getTemplateCompliantByJson(
              info,
              stateContainer,
              infoTemplate.path,
              data,
            );
            infoTemplate.isArray = true;
          } else {
            StateContainer? t = stateTemplate['${infoTemplate.path}[1]'];
            if (t != null) {
              infoTemplate.anyOf = true;
            }
          }
        } else if (idx >= 0 && data != null) {
          // y a t'il plusieur possibilite
          StateContainer? t = stateTemplate['${infoTemplate.path}[1]'];
          if (t != null) {
            //plusieur choix possible dans le tableau
            infoTemplate.path = _getTemplateCompliantByJson(
              info,
              stateContainer,
              infoTemplate.path,
              data,
            );
            infoTemplate.anyOf = true;
          } else {
            infoTemplate.path = '${infoTemplate.path}[0]';
          }
        } else if (idx >= 0) {
          infoTemplate.path = '${infoTemplate.path}[0]';
        }
      }

      return infoTemplate;
    }
  }

  void setContainerTemplate(StateContainer t, String pathTemplate) {
    //print("set on ${t.hashCode}");
    // SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
    t.currentTemplate = pathTemplate;
    // });
  }

  PanInfoObject _getTemplateCompliant(
    WidgetConfigInfo info,
    dynamic data,
    PanInfoObject rowTemplate,
  ) {
    for (var element in rowTemplate.children) {
      if (element is PanInfoObject) {
        var jsonTemplate = element.dataJsonSchema;
        if (jsonTemplate is Map && data is Map) {
          bool ok = true;
          for (var k in data.keys) {
            if (k == cstProp) continue;
            var kt = jsonTemplate[k];
            if (kt == null) {
              ok = false;
              break;
            }
          }
          if (ok) {
            //print('found compliant template ${element.name}');
            return element;
          }
        }
      }
    }
    return rowTemplate.children[0] as PanInfoObject;
  }

  String _getTemplateCompliantByJson(
    WidgetConfigInfo info,
    StateContainer? stateWidget,
    String pathTemplate,
    dynamic data,
  ) {
    var stateTemplate = info.json2ui.stateMgr.stateTemplate;
    var idxT = 0;
    while (true) {
      StateContainer? t = stateTemplate['$pathTemplate[$idxT]'];
      var jsonTemplate = t!.jsonTemplate;
      if (jsonTemplate is Map && data is Map) {
        bool ok = true;
        for (var k in data.keys) {
          if (k == cstProp) continue;
          var kt = jsonTemplate[k];
          if (kt == null) {
            ok = false;
            break;
          }
        }
        if (ok) {
          //print('found $idxT');
          pathTemplate = '$pathTemplate[$idxT]';
          if (stateWidget != null) {
            setContainerTemplate(stateWidget, pathTemplate);
          }
          break;
        }
      }

      idxT++;
    }
    return pathTemplate;
  }
}
