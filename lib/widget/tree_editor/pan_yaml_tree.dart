import 'package:flutter/scheduler.dart';
import 'package:highlight/languages/yaml.dart' show yaml;
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/api/pan_api_editor.dart';
import 'package:jsonschema/feature/api/pan_api_example.dart';
import 'package:jsonschema/feature/model/pan_model_change_log.dart';
import 'package:jsonschema/json_browser/browse_api.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/pages/router_layout.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_md_doc.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/widget/widget_overflow.dart';
import 'package:jsonschema/widget/widget_split.dart';
import 'package:jsonschema/widget/widget_vertical_sep.dart';

// ignore: must_be_immutable
abstract class PanYamlTree extends StatelessWidget with WidgetHelper {
  PanYamlTree({super.key, required this.getSchemaFct, this.showable});

  final Function getSchemaFct;
  final Function? showable;

  Widget? _cacheContent;
  late ModelSchema _schema;
  CodeEditorConfig? _yamlConfig;

  final ValueNotifier<double> _showAttrEditor = ValueNotifier(0);

  final GlobalKey<TreeViewState> keyTreeEditor = GlobalKey(
    debugLabel: 'treeEditor',
  );
  final GlobalKey keyAttrEditor = GlobalKey(debugLabel: 'keyAttrEditor');

  final TreeViewBrowserWidget jsonBrowserWidget = TreeViewBrowserWidget(
    config: BrowserConfig(),
  );

  void onInit(BuildContext context) {}
  void onInitSchema(BuildContext context) {}

  TextSelection? getTextSelection() {
    return _yamlConfig?.codeEditorState?.controller.selection;
  }

  void scrollCodeEditorTo(NodeAttribut attr) {
    var yamlPath = attr.info.getJsonPath(withType: true);
    print("scroll to path $yamlPath");
    //keyTreeEditor.currentState?.scrollToData(attr);
    _yamlConfig?.codeEditorState?.scrollToJsonPath(yamlPath);
  }

  Widget getLoader() {
    return Center(child: CircularProgressIndicator());
  }

  dynamic initSchema() {
    return getSchemaFct();
  }

  @override
  Widget build(BuildContext context) {
    onInit(context);
    currentYamlTree = this;

    if (showable != null && showable!() == false) {
      return Container();
    }

    dynamic futureModel = initSchema();
    if (futureModel is Future<ModelSchema>) {
      return FutureBuilder<ModelSchema>(
        future: futureModel,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _schema = snapshot.data!;
            onInitSchema(context);
            _cacheContent = _getContent(context);
            if (_yamlConfig != null) {
              _schema.initEventListener(_yamlConfig!);
            }

            return _cacheContent!;
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            return getLoader();
          }
        },
      );
    } else {
      _schema = futureModel as ModelSchema;
      onInitSchema(context);
      _cacheContent = _getContent(context);
      return _cacheContent!;
    }
  }

  bool isReadOnly() {
    return _schema.isReadOnlyModel;
  }

  bool withEditor() {
    return true;
  }

  bool canDrag(TreeNodeData<NodeAttribut> node) {
    return false;
  }

  bool actionRowOnTapDetail = false;

  Widget _getContent(BuildContext context) {
    getYaml() {
      return _schema.modelYaml;
    }

    if (withEditor()) {
      _yamlConfig ??= CodeEditorConfig(
        validateKey: _schema.infoManager.getValidateKey(),
        mode: yaml,
        notifError: ValueNotifier<String>(''),
        onChange: _getOnChange(),
        getText: getYaml,
        readOnly: isReadOnly(),
      );
    }

    var attrViewer = getTree(context);
    var attributProp = getAttributProperties(context);

    if (attributProp != null) {
      attrViewer = ValueListenableBuilder(
        valueListenable: _showAttrEditor,
        builder: (context, value, child) {
          return SplitView(
            key: ValueKey(value),
            secondaryWidth: _showAttrEditor.value,
            primaryWidth: -1,
            children: [
              readOnlyCapable(isReadOnly(), getTree(context)),
              attributProp,
              //WidgetHiddenBox(showNotifier: _showAttrEditor, child: attributProp),
            ],
          );
        },
      );
    } else {
      actionRowOnTapDetail = true;
    }

    if (withEditor()) {
      Widget split = SplitView(
        primaryWidth: 350,
        children: [getLeftPan(true, context), getRightPan(attrViewer, context)],
      );
      return split;
    } else {
      return getRightPan(attrViewer, context);
    }
  }

  Widget? getAttributProperties(BuildContext context) {
    return null;
  }

  Widget getLeftPan(bool withSep, BuildContext context) {
    if (withSep) {
      return Row(children: [Expanded(child: getYamlEditor()), VerticalSep()]);
    } else {
      return getYamlEditor();
    }
  }

  Widget getRightPan(Widget viewer, BuildContext context) {
    var bottomWidget = getBottomWidget(context);
    if (bottomWidget != null) {
      return SplitView(
        axis: Axis.vertical,
        primaryWidth: -1,
        secondaryWidth: -1,
        flex2: 2,
        children: [viewer, bottomWidget],
      );
    } else {
      return viewer;
    }
  }

  ModelSchema getSchema() {
    return _schema;
  }

  CodeEditorConfig getYamlConfig() {
    return _yamlConfig!;
  }

  Widget? getDoc() {
    if (_schema.infoManager is InfoManagerModel) {
      return WidgetMdDoc(
        type: (_schema.infoManager as InfoManagerModel).typeMD,
      );
    } else if (_schema.infoManager is InfoManagerAPI) {
      return WidgetMdDoc(type: TypeMD.listapi);
    } else if (_schema.infoManager is InfoManagerAPIParam) {
      return WidgetMdDoc(type: TypeMD.apiparam);
    } else if (_schema.infoManager is InfoManagerApiExample) {
      return WidgetMdDoc(type: TypeMD.apiExample);
    } else if (_schema.infoManager is InfoManagerListModel) {
      return WidgetMdDoc(
        type: (_schema.infoManager as InfoManagerListModel).typeMD,
      );
    }
    return null;
  }

  String getHeaderCode() {
    return _schema.headerName;
    //    TypeModelBreadcrumb.valString(_schema.typeBreabcrumb);
  }

  int tapSinceEpoch = 0;

  Widget getTree(BuildContext context) {
    return TreeView<NodeAttribut>(
      key: keyTreeEditor,
      isSelected: (node, cur, old) {
        if (node.data.info.masterID == _schema.selectedAttr?.info.masterID) {
          return node.data.info.getJsonPath() ==
              _schema.selectedAttr?.info.getJsonPath();
        }
        return false;
      },
      onBuild: (state, ctx) {
        _schema.infoManager.modelSchema = _schema;
        _schema.infoManager.editor = this;
        _yamlConfig?.treeJsonState = state;
        jsonBrowserWidget.repaintRowState = state;
        currentYamlTree = this;
      },
      getNodes: () {
        NodeBrowser browser = jsonBrowserWidget.browse(_schema, true);
        _schema.lastBrowser = browser;
        _schema.lastJsonBrowser = jsonBrowserWidget;

        List<TreeNodeData<NodeAttribut>> ret = [];
        if (jsonBrowserWidget.rootTree != null) {
          ret.add(jsonBrowserWidget.rootTree!);
        }
        return TreeViewData(nodes: ret, headerSize: jsonBrowserWidget.maxSize);
      },
      getHeader: (node) {
        var canDrag = this.canDrag(node);
        if (canDrag) {
          return Draggable<TreeNodeData<NodeAttribut>>(
            dragAnchorStrategy: pointerDragAnchorStrategy,
            data: node,
            feedback: Material(
              child: getChip(
                Text(node.data.info.getJsonPath()),
                color: Colors.blueAccent,
              ),
            ),
            child: _schema.infoManager.getRowHeader(node, context),
          );
        }

        return _schema.infoManager.getRowHeader(node, context);
      },
      getDataRow: (node) {
        var ret = <Widget>[];
        addRowWidget(node, _schema, ret, context);
        return Listener(
          onPointerDown: (_) {
            if (actionRowOnTapDetail) {
              doSelectedRow(node.data, false);
              onActionRow(node, context);
            } else {
              doSelectedRow(node.data, false);
              doShowAttrEditor(node.data);
            }
          },
          child: getToolTip(
            toolContent: getTooltipFromAttr(node.data.info, _schema),
            child: NoOverflowErrorFlex(
              crossAxisAlignment: CrossAxisAlignment.end,
              direction: Axis.horizontal,
              children: ret,
            ),
          ),
        );
      },
      onTapHeader: (node, ctx, String type) async {
        doSelectedRow(node.data, false);
        if (type == "search") return;

        var millisecondsSinceEpoch2 = DateTime.now().millisecondsSinceEpoch;
        if (millisecondsSinceEpoch2 - tapSinceEpoch < 300) {
          // double tap
          doDoubleTapRow(node.data);
        } else {
          await onActionRow(node, ctx);
        }
        tapSinceEpoch = millisecondsSinceEpoch2;
      },
    );
  }

  // Widget getHover(NodeAttribut attr, Widget child) {
  //   return HoverableCard(
  //     isSelected: (State state) {
  //       bool isSelected = _schema.selectedAttr == attr;
  //       if (isSelected) {
  //         rowSelectedState = state;
  //       }
  //       return isSelected;
  //     },
  //     child: child,
  //   );
  // }

  Widget getYamlEditor() {
    var doc = getDoc();
    final GlobalKey<TextEditorState> yamlEditor = GlobalKey(
      debugLabel: 'yamlEditor',
    );

    return readOnlyCapable(
      isReadOnly(),
      Container(
        color: Colors.black,
        child: TextEditor(
          onHistory: (BuildContext ctx) {
            Size size = MediaQuery.of(ctx).size;
            double width = size.width * 0.8;
            double height = size.height * 0.8;
            showDialog(
              context: ctx,
              barrierDismissible: true,
              builder: (BuildContext context) {
                return AlertDialog(
                  content: SizedBox(
                    width: width,
                    height: height,
                    child: PanModelChangeLog(currentModel: _schema),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Close'),
                    ),
                  ],
                );
              },
            );
          },
          onSelection: (String yamlPath) {
            print("on Selection go to path $yamlPath");
            var attr = _schema.getNodeByMasterJsonPath(yamlPath);
            if (attr != null) {
              doSelectedRow(attr, true);
              doScrollToSelected();
            }
          },
          header: getHeaderCode(),
          onHelp:
              doc != null
                  ? (BuildContext ctx) {
                    showDialog(
                      context: ctx,
                      barrierDismissible: true,
                      builder: (BuildContext context) {
                        return doc;
                      },
                    );
                  }
                  : null,
          key: yamlEditor,
          config: _yamlConfig!,
        ),
      ),
    );
  }

  Function _getOnChange() {
    return (String yaml, CodeEditorConfig config) {
      var model = _schema;
      if (model.modelYaml != yaml) {
        model.modelYaml = yaml;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onYamlChange();

          model.doChangeAndRepaintYaml(
            config,
            model.autoSaveProperties,
            'change',
          );

          // ignore: invalid_use_of_protected_member
          keyTreeEditor.currentState?.setState(() {});
        });
      }
    };
  }

  void doShowAttrEditor(NodeAttribut? attr) {
    if (attr == null || (oldSelected == attr && _showAttrEditor.value == 300)) {
      _showAttrEditor.value = 0;
    } else {
      _showAttrEditor.value = 300;
    }

    if (attr == null) oldSelected = null;

    //ignore: invalid_use_of_protected_member
    keyAttrEditor.currentState?.setState(() {});

    // // ignore: invalid_use_of_protected_member
    // attr.widgetSelectState?.setState(() {});
  }

  NodeAttribut? oldSelected;
  int timeStampSelected = 0;

  void doSelectedRow(NodeAttribut attr, bool withNode) {
    timeStampSelected = DateTime.now().millisecondsSinceEpoch;
    oldSelected = _schema.selectedAttr;
    _schema.selectedAttr = attr;

    if (attr.widgetRowHoverState?.mounted == true) {
      // ignore: invalid_use_of_protected_member
      attr.widgetRowHoverState?.setState(() {});
    }

    if (withNode) {
      TreeNodeData? node =
          keyTreeEditor.currentState?.list.where((element) {
            NodeAttribut attrData = element.data;
            return attrData.info.masterID == attr.info.masterID &&
                attrData.info.getJsonPath() == attr.info.getJsonPath();
          }).firstOrNull;
      if (node != null) {
        // lance la selection des attributes
        onActionRow(
          node as TreeNodeData<NodeAttribut>,
          keyTreeEditor.currentContext!,
        );
      }
    }
  }

  //--------------------------------------------------------------
  void onYamlChange() {}

  Future<void> onActionRow(
    TreeNodeData<NodeAttribut> node,
    BuildContext context,
  ) async {}

  void addRowWidget(
    TreeNodeData<NodeAttribut> node,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {}

  void repaint() {
    _cacheContent = null;
    keyTreeEditor.currentState?.repaintInProgess =
        DateTime.now().millisecondsSinceEpoch;
    // ignore: invalid_use_of_protected_member
    keyTreeEditor.currentState?.setState(() {});
    _yamlConfig?.repaintCode();
  }

  void reload() {
    _cacheContent = null;
    var schema = getSchemaFct();
    if (schema is Future<ModelSchema>) {
      schema.then((value) {
        _schema = value;
        _cacheContent = null;
        keyTreeEditor.currentState?.repaintInProgess =
            DateTime.now().millisecondsSinceEpoch;
        // ignore: invalid_use_of_protected_member
        keyTreeEditor.currentState?.setState(() {});
      });
    } else {
      _schema = schema as ModelSchema;
      _cacheContent = null;
      keyTreeEditor.currentState?.repaintInProgess =
          DateTime.now().millisecondsSinceEpoch;
      // ignore: invalid_use_of_protected_member
      keyTreeEditor.currentState?.setState(() {});
    }
    _yamlConfig?.repaintCode();
  }

  void setOpenFactor(double value) {
    keyTreeEditor.currentState?.openFactor = value.toInt();
    keyTreeEditor.currentState?.openFactorInProgess =
        DateTime.now().millisecondsSinceEpoch;
    keyTreeEditor.currentState?.repaintInProgess =
        DateTime.now().millisecondsSinceEpoch;
    // ignore: invalid_use_of_protected_member
    keyTreeEditor.currentState?.setState(() {});
  }

  int setSearch(String value, int idx) {
    int count = keyTreeEditor.currentState?.doSearch(value, idx) ?? 0;
    // keyTreeEditor.currentState?.repaintInProgess =
    //     DateTime.now().millisecondsSinceEpoch;
    // // ignore: invalid_use_of_protected_member
    // keyTreeEditor.currentState?.setState(() {});
    return count;
  }

  void changeOpenStructure() {
    var mode = keyTreeEditor.currentState?.openStructureMode;
    if (mode == 'all') {
      keyTreeEditor.currentState?.openStructureMode = 'onlyStructure';
    } else if (mode == 'onlyStructure') {
      keyTreeEditor.currentState?.openStructureMode = 'structure';
    } else {
      keyTreeEditor.currentState?.openStructureMode = 'all';
    }

    keyTreeEditor.currentState?.openFactorInProgess =
        DateTime.now().millisecondsSinceEpoch;
    keyTreeEditor.currentState?.repaintInProgess =
        DateTime.now().millisecondsSinceEpoch;
    // ignore: invalid_use_of_protected_member
    keyTreeEditor.currentState?.setState(() {});
  }

  void changeFilterTarget(String target) {
    //var mode = keyTreeEditor.currentState?.filterType;
    //if (mode == 'all') {
    keyTreeEditor.currentState?.filterType = target;
    //}

    // keyTreeEditor.currentState?.openFactorInProgess =
    //     DateTime.now().millisecondsSinceEpoch;
    keyTreeEditor.currentState?.repaintInProgess =
        DateTime.now().millisecondsSinceEpoch;
    // ignore: invalid_use_of_protected_member
    keyTreeEditor.currentState?.setState(() {});
  }

  void updateYaml(String aYaml) {
    _yamlConfig?.onChange(aYaml, _yamlConfig);
    _yamlConfig?.repaintCode();
  }

  Widget? getBottomWidget(BuildContext context) {
    return null;
  }

  void doScrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      var attr = _schema.selectedAttr;
      if (attr != null) {
        var yamlPath = attr.info.getJsonPath();
        print("scroll to path $yamlPath");
        keyTreeEditor.currentState?.scrollToData(attr);
      }
    });
  }

  void doDoubleTapRow(NodeAttribut data) {}
}

//-------------------------------------------------------------------------------
class TreeViewBrowserWidget extends JsonBrowser {
  TreeViewBrowserWidget({required super.config});

  List<String>? pathFilter;
  double maxSize = 0;
  TreeNodeData<NodeAttribut>? rootTree;
  TreeViewState? repaintRowState;

  bool isInBuildPhase() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    return phase == SchedulerPhase.persistentCallbacks;
  }

  @override
  void onStrutureChanged() {
    if (repaintRowState == null) return;

    if (isInBuildPhase()) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        repaintRowState!.headerSize = -1;
        repaintRowState!.repaintInProgess =
            DateTime.now().millisecondsSinceEpoch;
        if (repaintRowState!.mounted) {
          // ignore: invalid_use_of_protected_member
          repaintRowState!.setState(() {});
        }
      });
    } else {
      repaintRowState!.headerSize = -1;
      repaintRowState!.repaintInProgess = DateTime.now().millisecondsSinceEpoch;
      if (repaintRowState!.mounted) {
        // ignore: invalid_use_of_protected_member
        repaintRowState!.setState(() {});
      }
    }
  }

  @override
  dynamic getRoot(NodeAttribut node) {
    rootTree ??= TreeNodeData<NodeAttribut>(data: node, children: []);
    rootTree!.data = node;
    rootTree!.reinitRoot();
    rootTree!.setCache(
      '${node.info.name}%${node.info.type}%${node.info.timeLastChange}',
    );
    return rootTree;
  }

  @override
  dynamic getChild(
    ModelSchema model,
    NodeAttribut parentNode,
    NodeAttribut node,
    dynamic parent,
  ) {
    TreeNodeData<NodeAttribut> pn = parent as TreeNodeData<NodeAttribut>;
    TreeNodeData<NodeAttribut> newNode = pn.exist(node, (NodeAttribut e) {
      return e.info;
    });

    newNode.data = node;

    if (pathFilter != null) {
      var find = false;
      for (var element in pathFilter!) {
        if (element.startsWith(node.info.path)) {
          find = true;
          break;
        }
      }
      if (!find) return null;
    }

    if (config.isGet == true) {
      bool wr = node.info.properties?['writeOnly'] ?? false;
      if (wr) {
        return null;
      }
    }

    if (config.isApi == true &&
        !(node.info.properties?['#target']?.toString().contains('api') ??
            true)) {
      return null;
    }

    node.info.widgetRowState = repaintRowState;
    newNode.setCache(
      '${node.info.name}%${node.info.type}%${node.info.timeLastChange}',
    );
    newNode.bgColor = node.bgcolor;

    double wIcon = 30;
    double marge = 10;

    double sizeType = wIcon + node.info.type.length * 8 * (zoom.value / 100);
    double size =
        marge +
        wIcon +
        (node.info.name.length * 8 * (zoom.value / 100)) +
        (node.level * (repaintRowState?.indent.indent ?? 0)) +
        sizeType;

    if (maxSize < size) {
      maxSize = size;
    }

    if (!parentNode.addChildAsync) {
      (parent as TreeNodeData).add(newNode);
    } else {
      parentNode.addChildAsync = false;
      (parent as TreeNodeData).add(newNode);
    }
    return newNode;
  }
}
