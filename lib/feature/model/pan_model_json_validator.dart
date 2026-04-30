import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:highlight/languages/json.dart' show json;
import 'package:json_schema/json_schema.dart';
import 'package:jsonschema/core/export/export2json_fake.dart';
import 'package:jsonschema/core/export/export2json_schema.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/model/widget_example_choiser.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/start_core.dart';
import 'package:archive/archive.dart';
import 'package:jsonschema/widget/widget_long_json_viewer.dart';
import 'package:jsonschema/widget/widget_split.dart';
import 'package:jsonschema/widget/widget_tab.dart';

class WidgetJsonValidator extends StatefulWidget {
  const WidgetJsonValidator({super.key, required this.idModel});
  final String idModel;

  @override
  State<WidgetJsonValidator> createState() => _WidgetJsonValidatorState();
}

class _WidgetJsonValidatorState extends State<WidgetJsonValidator> {
  late dynamic jsonSchema;
  CodeEditorConfig? textConfig;
  //ExampleManager exampleManager = ExampleManager();

  ModelAccessorAttr getAccessor() {
    ModelSchema model = currentCompany.currentModel!;
    var examplesNode = model.getExtendedNode("#examples");

    var access = ModelAccessorAttr(
      node: examplesNode,
      schema: model,
      propName: '#examples',
    );
    return access;
  }

  ValueNotifier<String> onChangeHeaderInfo = ValueNotifier('');
  Function? onSelect;
  var currentJsonFake = ValueNotifier<String?>(null);

  Widget getExample() {
    var access = getAccessor();
    List? examples = access.get();

    // String? nameExample;
    // int? selectedIdx;
    // Function? onBeforeSave;

    return DraggableExampleList(
      key: ObjectKey(currentCompany.currentModel),
      json: () => currentJsonFake.value!,
      initialItems: examples ?? [],
      onItemChanged: (updatedList) {
        //reorg
        access.set(updatedList, force: true, withHistory: false);
        //clearSelected();
      },
      onLoad: (List<Map<String, dynamic>> list, int idx) {
        currentJsonFake.value = list[idx]['json'];
        // nameExample = list[idx]['name'];
        // selectedIdx = idx;
        //textConfig?.repaintCode();
        onSelect!();
      },
      onReplace: (List<Map<String, dynamic>> list, int idx) {
        list[idx]['json'] = currentJsonFake.value;
        access.set(list, force: true, withHistory: false);
      },
      onJsonChange: currentJsonFake,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.idModel != currentCompany.currentModel?.id) {
      currentCompany.currentModel == null;
      var model = ApiRequestNavigator().getModel(widget.idModel);
      model.then((model) {
        setState(() {
          currentCompany.currentModel = model;
          currentJsonFake.value = null;
          //exampleManager.clearSelected();
          textConfig?.repaintCode();
        });
      });
      return Center(child: CircularProgressIndicator());
    }

    return SplitView(
      primaryWidth: -1,
      flex1: 1,
      flex2: 2,
      children: [
        WidgetTab(
          listTab: [Tab(text: "Manage examples"), Tab(text: "JSON Schema")],
          listTabCont: [getExample(), getViewer()],
          heightTab: 30,
        ),
        Column(
          children: [
            SizedBox(
              height: 30,
              child: Row(
                children: [
                  TextButton.icon(
                    icon: Icon(Icons.casino_outlined),
                    onPressed: () {
                      currentJsonFake.value = null;
                      //exampleManager.clearSelected();
                      textConfig?.repaintCode();
                    },
                    label: Text('Generate fake'),
                  ),
                  FakeModeWidget(
                    modePropertyRequiredEnum: modePropertyRequiredEnum,
                    modeItemsArrayEnum: modeItemsArrayEnum,
                    onSelected: () {
                      currentJsonFake.value = null;
                      //exampleManager.clearSelected();
                      textConfig?.repaintCode();
                    },
                  ),
                  //exampleManager,
                ],
              ),
            ),
            Expanded(child: getEditor()),
          ],
        ),
      ],
    );
  }

  Widget getViewer() {
    if (currentCompany.currentModel == null) {
      return Text('select model first');
    }
    var export = Export2JsonSchema(config: BrowserConfig())
      ..browse(currentCompany.currentModel!, false);
    jsonSchema = export.json;
    try {
      jsonValidator = JsonSchema.create(jsonSchema);
      errorParse.value = '';
    } catch (e) {
      errorParse.value = '$e';
    }

    var prettyPrintJson = export.prettyPrintJson(jsonSchema);
    //print('jsonSchema= $prettyPrintJson');
    return LongJsonViewerSelectableColored(json: prettyPrintJson);
  }

  JsonSchema? jsonValidator;
  ValueNotifier<String> error = ValueNotifier('');
  ValueNotifier<String> errorParse = ValueNotifier('');
  ValueNotifier<String> modePropertyRequiredEnum = ValueNotifier('max');
  ValueNotifier<String> modeItemsArrayEnum = ValueNotifier('any');

  Widget getEditor() {
    if (currentCompany.currentModel == null) {
      return Text('select model first');
    }

    textConfig = CodeEditorConfig(
      mode: json,
      notifError: error,
      onChange: (String json, CodeEditorConfig config) {
        try {
          currentJsonFake.value = json; // Notify that JSON has changed
          if (json != '' && jsonValidator != null) {
            var jsonMap = jsonDecode(removeComments(json));
            validateJsonSchemas(jsonValidator!, jsonMap, config.notifError);
          } else {
            config.notifError.value = '';
          }
        } catch (e) {
          config.notifError.value = '$e';
        }
      },
      getText: () {
        if (currentJsonFake.value == null) {
          var export =
              Export2FakeJson(
                  modeArray: switch (modeItemsArrayEnum.value) {
                    'any' => ModeArrayEnum.anyInstance,
                    'random' => ModeArrayEnum.randomInstance,
                    _ => ModeArrayEnum.anyInstance,
                  },
                  mode: ModeEnum.fake,
                  propMode: switch (modePropertyRequiredEnum.value) {
                    'min' => PropertyRequiredEnum.required,
                    'max' => PropertyRequiredEnum.all,
                    _ => PropertyRequiredEnum.all,
                  },
                  config: BrowserConfig(),
                )
                ..maxArrayItems = 4
                ..browse(currentCompany.currentModel!, false);

          currentJsonFake.value = export.prettyPrintJson(export.json);
        }

        var encode = utf8.encode(currentJsonFake.value ?? '');
        var zip = GZipEncoder().encode(encode);
        String size = getFileSizeString(bytes: encode.length, decimals: 2);
        String sizezip = getFileSizeString(bytes: zip.length, decimals: 2);
        onChangeHeaderInfo.value = ' ($size compressed $sizezip)';
        return currentJsonFake.value ?? '';
      },
    );

    onSelect = () {
      textConfig?.repaintCode();
    };

    return TextEditor(
      headerWidget: ValueListenableBuilder(
        valueListenable: onChangeHeaderInfo,
        builder: (context, value, child) {
          return Text("JSON example $value");
        },
      ),
      config: textConfig!,
    );
  }

  String getFileSizeString({required int bytes, int decimals = 0}) {
    const suffixes = ["b", "kb", "mb", "gb", "tb"];
    if (bytes == 0) return '0 ${suffixes[0]}';
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}

class FakeModeWidget extends StatefulWidget {
  const FakeModeWidget({
    super.key,
    required this.modePropertyRequiredEnum,
    required this.onSelected,
    required this.modeItemsArrayEnum,
  });
  final ValueNotifier<String> modePropertyRequiredEnum;
  final ValueNotifier<String> modeItemsArrayEnum;
  final Function onSelected;

  @override
  State<FakeModeWidget> createState() => _FakeModeWidgetState();
}

class _FakeModeWidgetState extends State<FakeModeWidget> {
  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 10,
      children: [
        Text('Items'),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: 'any',
              label: Icon(Icons.one_x_mobiledata_outlined),
            ),
            ButtonSegment(value: 'random', label: Icon(Icons.shuffle)),
          ],
          selected: {widget.modeItemsArrayEnum.value},
          onSelectionChanged: (newSelection) {
            setState(() {
              widget.modeItemsArrayEnum.value = newSelection.first;
              widget.onSelected();
            });
          },
        ),
        Text('Required'),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: 'max',
              label: Icon(Icons.check_box_outline_blank),
            ),
            ButtonSegment(value: 'min', label: Icon(Icons.check_box)),
          ],
          selected: {widget.modePropertyRequiredEnum.value},
          onSelectionChanged: (newSelection) {
            setState(() {
              widget.modePropertyRequiredEnum.value = newSelection.first;
              widget.onSelected();
            });
          },
        ),
      ],
    );
  }
}
