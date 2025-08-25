import 'package:highlight/languages/yaml.dart' show yaml;
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_hidden_box.dart';
import 'package:jsonschema/widget/widget_md_doc.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/widget/widget_overflow.dart';
import 'package:jsonschema/widget/widget_split.dart';

// ignore: must_be_immutable
abstract class PanYamlTree extends StatelessWidget with WidgetHelper {
  PanYamlTree({super.key, required this.getSchemaFct, this.showable});

  final Function getSchemaFct;
  final Function? showable;

  Widget? _cacheContent;
  late ModelSchema _schema;
  CodeEditorConfig? _yamlConfig;

  final ValueNotifier<double> _showAttrEditor = ValueNotifier(0);

  final GlobalKey keyTreeEditor = GlobalKey(debugLabel: 'treeEditor');
  final GlobalKey keyAttrEditor = GlobalKey(debugLabel: 'keyAttrEditor');

  final TreeViewBrowserWidget jsonBrowserWidget = TreeViewBrowserWidget();

  // State? rowSelectedState;

  void onInit(BuildContext context) {}

  Widget getLoader() {
    return Center(child: CircularProgressIndicator());
  }

  @override
  Widget build(BuildContext context) {
    onInit(context);

    if (showable != null && showable!() == false) {
      return Container();
    }

    dynamic futureModel = getSchemaFct();
    if (futureModel is Future<ModelSchema>) {
      return FutureBuilder<ModelSchema>(
        future: futureModel,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _schema = snapshot.data!;

            _cacheContent = _getContent(context);

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
      _cacheContent = _getContent(context);
      return _cacheContent!;
    }
  }

  bool isReadOnly() {
    return false;
  }

  bool withEditor() {
    return true;
  }

  bool actionRowOnTapDetail = false;

  Widget _getContent(BuildContext context) {
    getYaml() {
      return _schema.modelYaml;
    }

    _yamlConfig ??= CodeEditorConfig(
      mode: yaml,
      notifError: ValueNotifier<String>(''),
      onChange: _getOnChange(),
      getText: getYaml,
      readOnly: isReadOnly(),
    );

    var attrViewer = getTree(context);
    var attributProp = getAttributProperties(context);

    if (attributProp != null) {
      attrViewer = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: getTree(context)),
          WidgetHiddenBox(showNotifier: _showAttrEditor, child: attributProp),
        ],
      );
    } else {
      actionRowOnTapDetail = true;
    }

    if (withEditor()) {
      Widget split = SplitView(
        primaryWidth: 350,
        children: [getLeftPan(context), getRightPan(attrViewer, context)],
      );
      return split;
    } else {
      return getRightPan(attrViewer, context);
    }
  }

  Widget? getAttributProperties(BuildContext context) {
    return null;
  }

  Widget getLeftPan(BuildContext context) {
    return getYamlEditor();
  }

  Widget getRightPan(Widget viewer, BuildContext context) {
    return viewer;
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
    }
    return null;
  }

  String getHeaderCode() {
    return _schema.headerName;
    //    TypeModelBreadcrumb.valString(_schema.typeBreabcrumb);
  }

  State? selectedState;

  Widget getTree(BuildContext context) {
    return TreeView<NodeAttribut>(
      key: keyTreeEditor,
      isSelected: (node, cur, old) {
        selectedState = old;
        return node.data == _schema.selectedAttr;
      },
      onBuild: (state, ctx) {
        _yamlConfig?.treeJsonState = state;
        jsonBrowserWidget.repaintRowState = state;
      },
      getNodes: () {
        // stateOpenFactor?.setList(this);
        //_textConfig?.treeJsonState = this;
        //..state = this
        //..pathFilter = pathFilter

        NodeBrower browser = jsonBrowserWidget.browse(_schema, true);
        _schema.lastBrowser = browser;
        _schema.lastJsonBrowser = jsonBrowserWidget;

        List<TreeNodeData<NodeAttribut>> ret = [];
        if (jsonBrowserWidget.rootTree != null) {
          ret.add(jsonBrowserWidget.rootTree!);
        }
        return TreeViewData(nodes: ret, headerSize: jsonBrowserWidget.maxSize);
      },
      getHeader: (node) {
        return _schema.infoManager.getRowHeader(node);
      },
      getDataRow: (node) {
        var ret = <Widget>[];
        addRowWidget(node, _schema, ret, context);
        return GestureDetector(
          onTap: () {
            if (actionRowOnTapDetail) {
              doSelectedRow(node.data);
              onActionRow(node, context);
            } else {
              doShowAttrEditor(node.data);
            }
          },
          child: getToolTip(
            toolContent: getTooltipFromAttr(node.data.info),
            child: NoOverflowErrorFlex(
              direction: Axis.horizontal,
              children: ret,
            ),
          ),
        );
      },
      onTapHeader: (node, ctx) async {
        doSelectedRow(node.data);
        await onActionRow(node, ctx);
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

    return Container(
      color: Colors.black,
      child: TextEditor(
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

  void doShowAttrEditor(NodeAttribut attr) {
    doSelectedRow(attr);

    if (_schema.selectedAttr == attr && _showAttrEditor.value == 300) {
      _showAttrEditor.value = 0;
    } else {
      _showAttrEditor.value = 300;
    }
    //ignore: invalid_use_of_protected_member
    keyAttrEditor.currentState?.setState(() {});

    // // ignore: invalid_use_of_protected_member
    // attr.widgetSelectState?.setState(() {});
  }

  void doSelectedRow(NodeAttribut attr) {
    _schema.selectedAttr = attr;
    if (selectedState?.mounted == true) {
      // ignore: invalid_use_of_protected_member
      selectedState?.setState(() {});
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
}

//-------------------------------------------------------------------------------
class TreeViewBrowserWidget extends JsonBrowser {
  TreeViewBrowserWidget();

  List<String>? pathFilter;
  double maxSize = 0;
  TreeNodeData<NodeAttribut>? rootTree;
  TreeViewState? repaintRowState;

  @override
  void onStrutureChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      repaintRowState!.headerSize = -1;
      repaintRowState!.repaintInProgess = DateTime.now().millisecondsSinceEpoch;
      // ignore: invalid_use_of_protected_member
      repaintRowState!.setState(() {});
    });
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
  dynamic getChild(NodeAttribut parentNode, NodeAttribut node, dynamic parent) {
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

    node.info.widgetRowState = repaintRowState;
    newNode.setCache(
      '${node.info.name}%${node.info.type}%${node.info.timeLastChange}',
    );
    newNode.bgColor = node.bgcolor;

    double wIcon = 30;

    double sizeType = wIcon + node.info.type.length * 8 * (zoom.value / 100);
    double size =
        wIcon +
        (node.info.name.length * 8 * (zoom.value / 100)) +
        (node.level * repaintRowState!.indent.height) +
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
