import 'dart:convert';

import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/export/export2json_fake.dart';
import 'package:jsonschema/core/export/export2ui.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/content/json_to_ui.dart';
import 'package:jsonschema/feature/model/widget_example_choiser.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/tree_editor/pan_yaml_tree.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_md_doc.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_overflow.dart';

class PanContentViewer extends StatefulWidget {
  const PanContentViewer({super.key, this.masterIdModel});

  final String? masterIdModel;

  @override
  State<PanContentViewer> createState() => _PanContentViewerState();
}

class _PanContentViewerState extends State<PanContentViewer> {
  ModelSchema? modelLoaded;

  Future<ModelSchema?> getModel(String idDomain, String idModel) async {
    var aDomain = currentCompany.listDomain.mapInfoByName[idDomain];
    var attr = aDomain?.firstOrNull;
    if (attr != null) {
      var listModel = await loadSchema(
        TypeMD.listmodel,
        'model',
        'Business models',
        TypeModelBreadcrumb.businessmodel,
        namespace: attr.masterID!,
      );
      var m = listModel.mapInfoByName[idModel]?.first;
      if (m != null) {
        var aModel = ModelSchema(
          category: Category.model,
          infoManager: InfoManagerModel(typeMD: TypeMD.model),
          headerName: m.name,
          id: m.masterID!,
          ref: listModel,
        );
        aModel.namespace = attr.masterID!;
        await aModel.loadYamlAndProperties(cache: false, withProperties: true);
        //print(m);
        return aModel;
      }
    }

    return null;
  }

  Future<ModelSchema?> getModelByMasterId(String idModel) async {
    var aModel = ModelSchema(
      category: Category.model,
      infoManager: InfoManagerModel(typeMD: TypeMD.model),
      headerName: "model",
      id: idModel,
      ref: currentCompany.listModel,
    );
    aModel.namespace = currentCompany.currentNameSpace;
    await aModel.loadYamlAndProperties(cache: false, withProperties: true);
    //print(m);
    return aModel;
  }

  late JsonToUi json2ui;

  @override
  void initState() {
    json2ui = JsonToUi(state: this);
    super.initState();
  }

  Future<Widget> getUI(BuildContext context) async {
    if (widget.masterIdModel != null && json2ui.stateMgr.data==null) {
      modelLoaded ??= await getModelByMasterId(widget.masterIdModel!);
      json2ui.saveUIOnModel = true;
      // charge les layout
      json2ui.stateMgr.loadJSonConfigLayout(modelLoaded!);

      // charge un fake
      var dataFake = Export2FakeJson(
        modeArray: ModeArrayEnum.randomInstance,
        mode: ModeEnum.fake,
      );
      await dataFake.browseSync(modelLoaded!, false, 0);
      json2ui.stateMgr.data = dataFake.json;
    } else {
      modelLoaded ??= await getModel('OMS', 'paginedSales');
    }
    //modelLoaded ??= await getModel('Example', 'dataExample');
    //modelLoaded ??= await getModel('Example', 'dogs');

    if (modelLoaded != null) {
      var exportUI = Export2UI();
      json2ui.haveTemplate = false;
      json2ui.modeTemplate = false;
      json2ui.stateMgr.dispose();

      await exportUI.browseSync(modelLoaded!, false, 0);
      json2ui.stateMgr.jsonUI = exportUI.json;
      json2ui.context = context;
      json2ui.modeTemplate = true;
      json2ui.model = modelLoaded;
      var ret =
          json2ui.browseJsonToWidget(
            'root',
            exportUI.json,
            path: '',
            pathData: '',
            parentType: WidgetType.root,
          )!;

      if (json2ui.stateMgr.dataEmpty == null) {
        var dataEmpty = Export2FakeJson(
          modeArray: ModeArrayEnum.anyInstance,
          mode: ModeEnum.empty,
        );
        await dataEmpty.browseSync(modelLoaded!, false, 0);
        json2ui.stateMgr.dataEmpty = dataEmpty.json;
      }

      SchedulerBinding.instance.addPostFrameCallback((timeStamp) async {
        json2ui.haveTemplate = true;
        json2ui.modeTemplate = false;
        // for (var element in json2ui.stateMgr.stateTemplate.entries) {
        //   print("template ${element.key} ${element.value}");
        // }
        var data = json2ui.stateMgr.data;
        if (data != null) {
          // recharge les bonnes datas
          json2ui.loadData(data);
        }
      });

      return ret.widget;
    } else {
      return Text('unknown');
    }
  }

  Widget getLoader() {
    return Center(child: CircularProgressIndicator());
  }

  String prettyPrintJson(dynamic input) {
    //const JsonDecoder decoder = JsonDecoder();
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(input);
  }

  ExampleManager exampleManager = ExampleManager();

  @override
  Widget build(BuildContext context) {
    var ui = getUI(context);
    exampleManager.jsonFake = '';
    exampleManager.onSelect = () {
      try {
        json2ui.loadData(jsonDecode(exampleManager.jsonFake!));
      } catch (e) {
        // TODO
      }
    };
    exampleManager.onBeforeSave = () {
      exampleManager.jsonFake = prettyPrintJson(json2ui.stateMgr.data);
    };

    return FutureBuilder(
      key: GlobalKey(),
      future: ui,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Column(
            children: [
              Row(children: [getLoadBtn(), getClearBtn(), exampleManager]),
              Expanded(child: snapshot.data!),
            ],
          );
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          return getLoader();
        }
      },
    );
  }

  Widget getLoadBtn() {
    return TextButton.icon(
      icon: Icon(Icons.casino_outlined),
      onPressed: () async {
        var dataFake = Export2FakeJson(
          modeArray: ModeArrayEnum.randomInstance,
          mode: ModeEnum.fake,
        );
        await dataFake.browseSync(modelLoaded!, false, 0);
        json2ui.loadData(dataFake.json);
        exampleManager.jsonFake = dataFake.json.toString();
        exampleManager.clearSelected();
      },
      label: Text('Load fake'),
    );
  }

  Widget getClearBtn() {
    return TextButton.icon(
      icon: Icon(Icons.clear),
      onPressed: () async {
        json2ui.stateMgr.clear();
        exampleManager.clearSelected();
      },
      label: Text('Clear'),
    );
  }
}

//************************************************************************* */
// ignore: must_be_immutable
class PanContentSelectorTree extends PanYamlTree {
  PanContentSelectorTree({super.key, required super.getSchemaFct});
}

//************************************************************************* */
class InfoManagerContent extends InfoManager with WidgetHelper {
  @override
  String getTypeTitle(NodeAttribut node, String name, dynamic type) {
    String? typeStr;
    if (type is Map) {
      // if (name.startsWith(constRefOn)) {
      //   typeStr = '\$ref';
      // } else if (name.startsWith(constTypeAnyof)) {
      //   typeStr = '\$anyOf';
      // } else if (name.endsWith('[]')) {
      //   node.bgcolor = Colors.blue.withAlpha(50);
      //   typeStr = 'Array';
      // } else {
      //   node.bgcolor = Colors.blueGrey.withAlpha(50);
      //   typeStr = typeMD == TypeMD.listmodel ? 'folder' : 'Object';
      // }
    } else if (type is List) {
      if (name.endsWith('[]')) {
        typeStr = 'Array';
        node.bgcolor = Colors.blue.withAlpha(50);
      } else {
        node.bgcolor = Colors.blue.withAlpha(50);
        typeStr = 'Array';
      }
    } else if (type is int) {
      typeStr = 'number';
    } else if (type is double) {
      typeStr = 'number';
    } else if (type is String) {
      if (name.endsWith('[]')) {
        node.bgcolor = Colors.blue.withAlpha(50);
        if (type.startsWith('\$')) {
          typeStr = 'Array';
        } else {
          typeStr = '$type[]';
        }
      } else if (type.startsWith('\$')) {
        typeStr = 'Object';
      }
    }
    typeStr ??= '$type';
    return typeStr;
  }

  @override
  InvalidInfo? isTypeValid(
    NodeAttribut nodeAttribut,
    String name,
    dynamic type,
    String typeTitle,
  ) {
    var type = typeTitle.toLowerCase();

    if (type.endsWith('[]')) {
      type = type.substring(0, type.length - 2);
    }

    bool valid = [
      'folder',
      'model',

      'string',
      'number',
      'object',
      'array',
      'boolean',
      '\$ref',
      '\$anyof',
    ].contains(type);
    if (!valid) {
      return InvalidInfo(color: Colors.red);
    }
    return null;
  }

  @override
  Widget getRowHeader(TreeNodeData<NodeAttribut> node) {
    Widget? icon;
    var isRoot = node.isRoot;
    var isFolder = node.data.info.type == 'folder';
    var isModel = node.data.info.type == 'model';

    var isObject = node.data.info.type == 'Object';
    var isOneOf = node.data.info.type == '\$anyOf';
    var isRef = node.data.info.type == '\$ref';
    var isType = node.data.info.name == constType;
    var isArray =
        node.data.info.type == 'Array' || node.data.info.type.endsWith('[]');
    String name = node.data.info.name;

    if (isRoot) {
      icon = Icon(Icons.business);
    } else if (isFolder) {
      icon = Icon(Icons.folder);
    } else if (isModel) {
      icon = Icon(Icons.data_object);
    } else if (isObject) {
      icon = Icon(Icons.data_object);
    } else if (isRef) {
      icon = Icon(Icons.link);
      name = '\$${node.data.info.properties?[constRefOn] ?? '?'}';
    } else if (isOneOf) {
      name = '\$anyOf';
      icon = Icon(Icons.looks_one_rounded);
    } else if (isArray) {
      icon = Icon(Icons.data_array);
    } else if (isType) {
      name = '\$type';
      icon = Icon(Icons.type_specimen_outlined);
    }

    return NoOverflowErrorFlex(
      direction: Axis.horizontal,
      children: [
        if (icon != null)
          Padding(padding: const EdgeInsets.fromLTRB(0, 0, 5, 0), child: icon),

        Expanded(
          child: InkWell(
            onTap: () {
              node.doTapHeader();
            },
            child: Row(
              children: [
                Text(
                  name,
                  style:
                      (isObject || isArray)
                          ? const TextStyle(fontWeight: FontWeight.bold)
                          : null,
                ),
                Spacer(),
                getWidgetType(node.data, isModel, isRoot),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget getWidgetType(NodeAttribut attr, bool isModel, bool isRoot) {
    if (isRoot) return Container();

    bool hasError = attr.info.error?[EnumErrorType.errorRef] != null;
    hasError = hasError || attr.info.error?[EnumErrorType.errorType] != null;
    String msg = hasError ? 'string\nnumber\nboolean\n\$type' : '';

    return Tooltip(
      message: msg,
      child: getChip(
        isModel
            ? Row(
              spacing: 5,
              children: [
                Text(attr.info.type),
                Icon(Icons.arrow_forward_ios, size: 10),
              ],
            )
            : Text(attr.info.type),
        color: hasError ? Colors.redAccent : (isModel ? Colors.blue : null),
      ),
    );
  }

  @override
  Widget getAttributHeaderOLD(TreeNode<NodeAttribut> node) {
    // TODO: implement getAttributHeaderOLD
    throw UnimplementedError();
  }
}
