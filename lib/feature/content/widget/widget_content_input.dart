import 'package:flutter/material.dart';
import 'package:jsonschema/core/export/export2ui.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/feature/content/state_manager.dart';
import 'package:jsonschema/feature/content/widget/widget_content_helper.dart';

enum InputType { text, num, bool, choise, date }

class WidgetContentInput extends StatefulWidget {
  const WidgetContentInput({super.key, required this.info});

  final WidgetConfigInfo info;

  @override
  State<WidgetContentInput> createState() => WidgetContentInputState();
}

class WidgetContentInputState extends State<WidgetContentInput>
    with WidgetAnyOfHelper {
  dynamic dataDisplayed;
  String ctrlName = '';
  late TextEditingController ctrl;
  InputType typeInput = InputType.text;

  @override
  void initState() {
    String pathDataContainer = initValueDisplayed();
    ctrl = TextEditingController(text: dataDisplayed.toString());

    ctrlName = '$pathDataContainer/${widget.info.name}';
    if (widget.info.inArrayValue == true) {
      pathDataContainer = widget.info.pathValue!;
      pathDataContainer = pathDataContainer.replaceAll("/##__choise__##", '');
      // cas des tableau de String, int, etc...
      ctrlName = pathDataContainer;
      print("init ctrl $ctrlName");
    }

    widget.info.json2ui.stateMgr.addControler(ctrlName, this);

    ctrl.addListener(() {
      int idx = -1;
      var pathData = pathDataContainer;
      if (pathData.endsWith(']')) {
        pathData = pathData.substring(0, pathData.length - 1);
        int end = pathData.lastIndexOf('[');
        String idxTxt = pathData.substring(end + 1);
        pathData = pathData.substring(0, end);
        idx = int.parse(idxTxt);
      }

      var dataContainer = widget.info.json2ui.getState(pathData);
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
            val = data[widget.info.name];
          } else {
            // cas de liste de String, int
            val = row;
          }
        } else {
          val = data[widget.info.name];
        }

        if (ctrl.text != val?.toString()) {
          if (idx >= 0) {
            data[idx] = ctrl.text;
          } else {
            data[widget.info.name] = ctrl.text;
          }
        }
      }
      //   if (data is Map || data is List) {
      //     if (idx >= 0) {
      //       data = data[idx];
      //     }
      //     if (data is Map) {
      //       val = data[widget.info.name];
      //     } else {
      //       val = data;
      //     }
      //   } else {
      //     val = data;
      //   }
      // }
    });

    super.initState();
  }

  dynamic getValue(String val) {
    switch (typeInput) {
      case InputType.bool:
        return val.toLowerCase() == 'true';
      case InputType.num:
        return int.tryParse(val) ?? double.tryParse(val);
      default:
        return val;
    }
  }

  String initValueDisplayed() {
    // if (widget.info.pathValue == '/orderCategory/isSolvency') {
    //   print("object");
    // }

    var pathDataContainer = widget.info.pathData;
    if (widget.info.inArrayValue == true) {
      pathDataContainer = widget.info.pathValue;
      // cas des tableau de Sting, int, etc...
    }

    pathDataContainer = pathDataContainer!.replaceAll("/##__choise__##", '');
    var pathData = pathDataContainer;
    int idx = -1;
    if (pathData.endsWith(']')) {
      pathData = pathData.substring(0, pathData.length - 1);
      int end = pathData.lastIndexOf('[');
      String idxTxt = pathData.substring(end + 1);
      pathData = pathData.substring(0, end);
      idx = int.parse(idxTxt);
    }
    var dataContainer = widget.info.json2ui.getState(pathData);
    dynamic val = '';
    if (dataContainer != null) {
      var data = dataContainer.jsonData;
      if (data is Map || data is List) {
        if (idx >= 0) {
          data = data[idx];
        }
        if (data is Map) {
          val = data[widget.info.name];
        } else {
          val = data;
        }
      } else {
        val = data;
      }
    }
    dataDisplayed = val;

    switch (val) {
      case int _:
        typeInput = InputType.num;
        break;
      case bool _:
        typeInput = InputType.bool;
        break;
      default:
        typeInput = InputType.text;
    }

    print('${widget.info.pathValue}  $typeInput');

    return pathDataContainer;
  }

  @override
  void dispose() {
    var pathDataContainer = widget.info.pathData;
    pathDataContainer = pathDataContainer!.replaceAll("/##__choise__##", '');
    var ctrlName = '$pathDataContainer/${widget.info.name}';
    if (widget.info.inArrayValue == true) {
      // cas des tableau de Sting, int, etc...
      pathDataContainer = widget.info.pathValue!;
      pathDataContainer = pathDataContainer.replaceAll("/##__choise__##", '');
      ctrlName = pathDataContainer;

      //print("dispose ctrl $ctrlName");
    }
    widget.info.json2ui.stateMgr.removeControler(ctrlName, this);
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String messageTooltip = '';
    List<String>? choiseItem;

    var pathData = widget.info.pathData!;
    pathData = pathData.replaceAll("/##__choise__##", '');

    StateContainer? dataTemplate;

    if (widget.info.json2ui.modeTemplate) {
      dataTemplate = widget.info.json2ui.stateMgr.stateTemplate[pathData];
    }

    var stateWidget = widget.info.json2ui.getState(pathData);
    var displayData = stateWidget?.jsonData;
    var pathTemplate = pathData;
    var attrName = widget.info.name;

    if (widget.info.inArrayValue == true) {
      // gestion des tableau de String, int, etc..
      var lastIndexOf = pathTemplate.lastIndexOf('/');
      var p = pathTemplate.substring(0, lastIndexOf);
      attrName = pathTemplate.substring(lastIndexOf + 1);
      pathTemplate = p;
      pathData = pathTemplate;
    }

    // cherche le template
    if (widget.info.json2ui.haveTemplate && displayData != null) {
      if (widget.info.pathTemplate == null) {
        pathTemplate =
            stateWidget!.currentTemplate ??
            calcPathTemplate(widget.info, pathData).path;
        widget.info.pathTemplate = pathTemplate;
      } else {
        pathTemplate = widget.info.pathTemplate!;
      }

      dataTemplate = widget.info.json2ui.stateMgr.stateTemplate[pathTemplate];
    }

    // cherche la Attribut info du template
    var template = dataTemplate?.jsonTemplate[attrName];
    if (template is Map) {
      AttributInfo? propAttribut;
      if (template[cstProp] != null) {
        propAttribut = template[cstProp];
        messageTooltip = propAttribut!.properties.toString();
      }

      if (propAttribut != null) {
        switch (propAttribut.type) {
          case 'number':
            typeInput = InputType.num;
            break;
          case 'boolean':
            typeInput = InputType.bool;
            break;
          default:
            typeInput = InputType.text;
        }
        if (propAttribut.properties?['enum'] != null) {
          typeInput = InputType.choise;
          choiseItem = propAttribut.properties!['enum'].toString().split('\n');
          if (!choiseItem.contains('')) {
            choiseItem.insert(0, '');
          }
          print(choiseItem);
        }
      }
    } else if (!widget.info.json2ui.modeTemplate) {
      print("no found $pathData");
      if (typeInput == InputType.choise) {
        typeInput = InputType.text;
      }
    }

    // // change la valeur du controleur
    // var pathDataContainer = initValueDisplayed();
    // ctrl.text = dataDisplayed.toString();

    // var name = '$pathDataContainer/${widget.info.name}';
    // if (name != ctrlName) {
    //   print("object");
    // }

    Widget inputWidget;
    switch (typeInput) {
      case InputType.choise:
        // TextField textWidget = TextField(
        //   decoration: InputDecoration(labelText: widget.info.name),
        //   controller: ctrl,
        // );

        // inputWidget = ChoiseWidget(
        //   ctrl: ctrl,
        //   choise: choiseItem!,
        //   child: Expanded(child: textWidget),
        // );

        inputWidget = ValueListenableBuilder(
          valueListenable: ctrl,
          builder: (context, value, child) {
            return DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText:  widget.info.name,
                //border: OutlineInputBorder(),
              ),

              isExpanded: true,
              initialValue: ctrl.text,
              items:
                  choiseItem!.map((value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
              onChanged: (newValue) {
                ctrl.text = newValue ?? '';
              },
            );
          },
        );
        break;

      case InputType.bool:
        inputWidget = Row(
          children: [
            Text(widget.info.name),
            SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: ctrl,
              builder: (context, value, child) {
                return Switch(
                  value: value.text == 'true',
                  onChanged: (v) {
                    ctrl.text = v ? 'true' : 'false';
                  },
                );
              },
            ),
            Spacer(),
          ],
        );
        break;

      default:
        inputWidget = TextField(
          decoration: InputDecoration(labelText: widget.info.name),
          controller: ctrl,
        );
        break;
    }

    return Tooltip(message: messageTooltip, child: inputWidget);
  }
}
