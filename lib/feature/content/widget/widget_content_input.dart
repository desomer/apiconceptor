import 'package:flutter/material.dart';
import 'package:jsonschema/core/export/export2ui.dart';
import 'package:jsonschema/feature/content/pan_content_viewer.dart';
import 'package:jsonschema/feature/content/widget/widget_content_helper.dart';
import 'package:jsonschema/start_core.dart';

enum InputType { text, num, bool, choise, date, link }

class WidgetContentInput extends StatefulWidget {
  const WidgetContentInput({super.key, required this.info});

  final WidgetConfigInfo info;

  @override
  State<WidgetContentInput> createState() => WidgetContentInputState();
}

class WidgetContentInputState extends State<WidgetContentInput>
    with WidgetUIHelper {
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
      pathDataContainer = pathDataContainer.replaceAll("/$cstAnyChoice", '');
      // cas des tableau de String, int, etc...
      ctrlName = pathDataContainer;
      print("init ctrl $ctrlName");
    }

    widget.info.json2ui.stateMgr.addControler(ctrlName, this);

    ctrl.addListener(() {
      setValue(widget.info, typeInput, pathDataContainer, ctrl.text);
    });

    super.initState();
  }

  String initValueDisplayed() {
    var pathDataContainer = widget.info.pathData;
    if (widget.info.inArrayValue == true) {
      pathDataContainer = widget.info.pathValue;
      // cas des tableau de String, int, etc...
    }

    pathDataContainer = pathDataContainer!.replaceAll("/$cstAnyChoice", '');
    var pathData = pathDataContainer;
    int idx = -1;
    if (pathData.endsWith(']')) {
      // cas des tableau de xxxx
      pathData = pathData.substring(0, pathData.length - 1);
      int end = pathData.lastIndexOf('[');
      String idxTxt = pathData.substring(end + 1);
      pathData = pathData.substring(0, end);
      idx = int.parse(idxTxt);
    }
    var dataContainer  = widget.info.json2ui.getState(pathData);
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

    //print('${widget.info.pathValue}  $typeInput');

    return pathDataContainer;
  }

  @override
  void dispose() {
    var pathDataContainer = widget.info.pathData;
    pathDataContainer = pathDataContainer!.replaceAll("/$cstAnyChoice", '');
    var ctrlName = '$pathDataContainer/${widget.info.name}';
    if (widget.info.inArrayValue == true) {
      // cas des tableau de Sting, int, etc...
      pathDataContainer = widget.info.pathValue!;
      pathDataContainer = pathDataContainer.replaceAll("/$cstAnyChoice", '');
      ctrlName = pathDataContainer;
    }

    widget.info.json2ui.stateMgr.removeControler(ctrlName, this);
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    InputDesc inputDesc = getInputDesc(widget.info);

    typeInput = inputDesc.typeInput;

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
            // print('c<${ctrl.text}>');
            // var v =
            //     inputDesc.choiseItem!.map((value) {
            //       print('i<$value>');
            //     }).toList();

            return DropdownButtonFormField<String>(
              decoration: getInputDecorator(inputDesc.isRequired),
              isExpanded: true,
              initialValue: ctrl.text,
              items:
                  inputDesc.choiseItem!.map((value) {
                    var trim = value;
                    return DropdownMenuItem<String>(
                      value: trim,
                      child: Text(trim),
                    );
                  }).toList(),
              onChanged: (newValue) {
                ctrl.text = newValue ?? '';
              },
            );
          },
        );
        break;

      case InputType.link:
        inputWidget = TextField(
          decoration: getInputDecorator(
            inputDesc.isRequired,
            suffixIcon: IconButton(
              icon: Icon(Icons.search),
              onPressed: () {
                showLinkDialog(inputDesc.link!, context);
              },
            ),
          ),
          controller: ctrl,
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
          decoration: getInputDecorator(inputDesc.isRequired),
          controller: ctrl,
        );
        break;
    }

    return Tooltip(message: inputDesc.messageTooltip, child: inputWidget);
  }

  InputDecoration? getInputDecorator(bool isRequired, {Widget? suffixIcon}) {
    InputDecoration? inputDecoration;
    if (isRequired) {
      inputDecoration = InputDecoration(
        suffixIcon: suffixIcon,
        label: getLabelWithAsterix(widget.info.name, Colors.deepOrange),
      );
    } else {
      inputDecoration = InputDecoration(
        suffixIcon: suffixIcon,
        labelText: widget.info.name,
      );
    }
    return inputDecoration;
  }

  Widget getLabelWithAsterix(String label, Color asteriskColor) {
    return RichText(
      text: TextSpan(
        text: '$label ',
        style: TextStyle(color: Colors.grey),
        children: [
          TextSpan(
            text: '*',
            style: TextStyle(fontSize: 16, color: asteriskColor),
          ),
        ],
      ),
    );
  }

  Future<void> showLinkDialog(String link, BuildContext ctx) async {
    var l = link.split('.');
    var m = currentCompany.listModel!.mapInfoByName[l[0]];
    if (m == null || m.isEmpty) return;

    return showDialog<void>(
      context: ctx,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) {
        Size size = MediaQuery.of(ctx).size;
        double width = size.width * 0.9;
        double height = size.height * 0.8;
        return AlertDialog(
          content: SizedBox(
            width: width,
            height: height,
            child: Column(
              children: [
                ListTile(title: Text(m.first.name)),
                Expanded(
                  child: Container(
                    color: Colors.black,
                    child: PanContentViewer(masterIdModel: m.first.masterID),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
