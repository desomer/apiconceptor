import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:highlight/languages/yaml.dart' show yaml;
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/editor/cell_prop_editor.dart';
import 'package:jsonschema/editor/code_editor.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/pan_attribut_editor.dart';
import 'package:jsonschema/widget/json_editor/widget_json_tree.dart';
import 'package:jsonschema/widget/widget_hidden_box.dart';
import 'package:jsonschema/widget/widget_hover.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget_state/state_api.dart';
import 'package:yaml/yaml.dart';

class PanApiEditor extends StatefulWidget {
  const PanApiEditor({super.key});

  @override
  State<PanApiEditor> createState() => _PanApiEditorState();
}

class _PanApiEditorState extends State<PanApiEditor> with WidgetModelHelper {
  State? rowSelected;
  final GlobalKey keyApiYamlEditor = GlobalKey();
  final GlobalKey keyApiTreeEditor = GlobalKey();
  final GlobalKey keyAttrEditor = GlobalKey();
  final ValueNotifier<double> showAttrEditor = ValueNotifier(0);
  late final TextConfig textConfig;

  @override
  Widget build(BuildContext context) {
    if (currentCompany.listAPI.currentAttr == null) return Container();

    return WidgetTab(
      listTab: [
        Tab(text: 'Documentation'),
        Tab(text: 'Example'),
        Tab(text: 'Execute call api'),
      ],
      listTabCont: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            getPath(currentCompany.listAPI.currentAttr!),
            Expanded(child: getApiTab()),
          ],
        ),
        Container(),
        Container(),
      ],
      heightTab: 40,
    );
  }

  Widget getPath(NodeAttribut attr) {
    // var type = attr.info.type;
    String name = attr.yamlNode.key.toString().toLowerCase();

    List<Widget> wpath = [];
    late Widget wOpe;
    if (name == 'get') {
      wOpe = getChip(Text('GET'), color: Colors.green, height: 27);
    } else if (name == 'post') {
      wOpe = getChip(
        Text('POST', style: TextStyle(color: Colors.black)),
        color: Colors.yellow,
        height: 27,
      );
    } else if (name == 'put') {
      wOpe = getChip(Text('PUT'), color: Colors.blue, height: 27);
    } else if (name == 'delete') {
      wOpe = getChip(
        Text('DELETE', style: TextStyle(color: Colors.black)),
        color: Colors.redAccent.shade100,
        height: 27,
      );
    }

    wpath.add(wOpe);

    var nd = attr.parent;

    stateApi.urlParam.clear();
    while (nd != null) {
      var n = nd.yamlNode.key.toString();
      //var isServer = nd.info.properties?['\$url'];
      if (nd.info.properties?['\$url'] != null) {
        wpath.insert(
          1,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5),
            child: Text('<URL>'),
          ),
        );
        break;
      }
      var path = doPath(n);
      wpath.insertAll(1, path);
      if (!n.endsWith('/')) {
        wpath.insert(1, Text('/'));
      }

      // bufPath = n + sep + bufPath;
      nd = nd.parent;
    }

    return Card(
      elevation: 10,
      child: ListTile(leading: Icon(Icons.api), title: Row(children: wpath)),
    );
  }

  List<Widget> doPath(String name) {
    List<Widget> wpath = [];
    List<String> path = name.split('/');
    int i = 0;
    for (var element in path) {
      bool isLast = i == path.length - 1;
      if (element.startsWith('{')) {
        String v = element.substring(1, element.length - 1);
        wpath.add(getChip(Text(v), color: null));
        stateApi.urlParam.insert(0, v);
        if (!isLast) {
          wpath.add(Text('/'));
        }
      } else {
        if (element != '') {
          wpath.add(Text(element + (!isLast ? '/' : '')));
        }
      }
      i++;
    }
    return wpath;
  }

  Widget getApiTab() {
    return WidgetTab(
      listTab: [Tab(text: 'Request'), Tab(text: 'Responses')],
      listTabCont: [_getEditorLeftTab(), Container()],
      heightTab: 40,
    );
  }

  late TabController tabEditor;

  Widget _getEditorLeftTab() {
    void onYamlChange(String yaml, TextConfig config) {
      if (currentCompany.currentAPI == null) return;

      var modelSchemaDetail = currentCompany.currentAPI!;
      if (modelSchemaDetail.modelYaml != yaml) {
        modelSchemaDetail.modelYaml = yaml;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          //tabEditor.index = 0;

          var parser = ParseYamlManager();
          bool parseOk = parser.doParseYaml(
            modelSchemaDetail.modelYaml,
            config,
          );
          // bool parseOk = false;
          // try {
          //   modelSchemaDetail.mapModelYaml = loadYaml(
          //     modelSchemaDetail.modelYaml,
          //   );
          //   parseOk = true;
          //   config.notifError.value = '';
          // } catch (e) {
          //   config.notifError.value = '$e';
          //}

          if (parseOk) {
            modelSchemaDetail.mapModelYaml = parser.mapYaml!;
            //bddStorage.setItem(modelSchemaDetail.id, modelSchemaDetail.modelYaml);
            // ignore: invalid_use_of_protected_member
            keyApiTreeEditor.currentState?.setState(() {});
          }
        });
      }
    }

    getYaml() {
      initNewApi();
      return currentCompany.currentAPI!.modelYaml;
    }

    textConfig = TextConfig(
      mode: yaml,
      notifError: notifierErrorYaml,
      onChange: onYamlChange,
      getText: getYaml,
    );

    return WidgetTab(
      listTab: [
        Tab(text: 'Parameters'),
        Tab(text: 'Info'),
        Tab(text: 'Version'),
      ],
      listTabCont: [
        Row(
          children: [
            SizedBox(width: 350, child: getYamlParam()),
            Expanded(child: _getTreeEditor()),
          ],
        ),
        getInfoForm(),
        Container(),
      ],
      heightTab: 40,
    );
  }

  Widget getInfoForm() {
    return Container();
  }

  Widget _getTreeEditor() {
    getJsonYaml() {
      return currentCompany
          .currentAPI!
          .mapModelYaml; //currentCompany.currentModel!.mapModelYaml;
    }

    return Row(
      children: [
        Expanded(
          child: JsonEditor(
            key: keyApiTreeEditor,
            config:
                JsonTreeConfig(
                    textConfig: textConfig,
                    getModel: () {
                      return currentCompany.currentAPI;
                    },
                    onTap: (NodeAttribut node) {
                      // doShowAttrEditor(currentCompany.currentModel!, node);
                    },
                  )
                  ..getJson = getJsonYaml
                  ..getRow = _getRowsAttrInfo,
          ),
        ),
        WidgetHiddenBox(
          showNotifier: showAttrEditor,
          child: AttributProperties(key: keyAttrEditor),
        ),
      ],
    );
  }

  Widget _getRowsAttrInfo(NodeAttribut attr, ModelSchemaDetail schema) {
    if (attr.info.type == 'root') {
      return Container(height: rowHeight);
    }

    List<Widget> rowWidget = [SizedBox(width: 10)];
    rowWidget.add(
      CellEditor(
        key: ValueKey('${attr.hashCode}#title'),
        acces: ModelAccessorAttr(
          node: attr,
          schema: currentCompany.currentAPI!,
          propName: 'title',
        ),
        inArray: true,
      ),
    );

    bool minmax =
        (attr.info.properties?['minimum'] != null) ||
        (attr.info.properties?['maximun'] != null) ||
        (attr.info.properties?['minLength'] != null) ||
        (attr.info.properties?['maxLength'] != null);

    rowWidget.addAll(<Widget>[
      SizedBox(width: 10),
      if (attr.info.properties?['required'] != null)
        Icon(Icons.check_circle_outline),
      if (attr.info.properties?['const'] != null)
        getChip(Text('const'), color: null),
      if (attr.info.properties?['enum'] != null) Icon(Icons.checklist),
      if (attr.info.properties?['pattern'] != null)
        getChip(Text('regex'), color: null),
      if (minmax) Icon(Icons.tune),
      Spacer(),
      getChip(
        Row(children: [Icon(Icons.warning_amber, size: 20), Text('Glossary')]),
        color: Colors.red,
      ),
    ]);

    // row.add(getChip(Text(attr.info.treePosition ?? ''), color: null));
    // row.add(getChip(Text(attr.info.path), color: null));
    // addWidgetMasterId(attr, row);

    attr.info.cache = SizedBox(
      height: rowHeight,
      child: InkWell(
        onTap: () {
          // doShowAttrEditor(schema, attr);
          // //bool isSelected = schema.currentAttr == attr.info;
          // if (rowSelected?.mounted == true) {
          //   // ignore: invalid_use_of_protected_member
          //   rowSelected?.setState(() {});
          // }
        },
        child: HoverableCard(
          isSelected: (State state) {
            bool isSelected = schema.currentAttr == attr.info;
            if (isSelected) {
              //   var repaint = rowSelected;
              //   WidgetsBinding.instance.addPostFrameCallback((_) {
              //     // ignore: invalid_use_of_protected_member
              //     repaint?.setState(() {});
              //   });
              rowSelected = state;
            }
            return isSelected;
          },
          key: ObjectKey(attr),
          //margin: EdgeInsets.all(1),
          child: Row(spacing: 5, children: rowWidget),
        ),
      ),
    );
    return attr.info.cache!;
  }

  Widget getYamlParam() {
    return Container(
      color: Colors.black,
      child: TextEditor(
        header: "Parameters query, header, cookies, body",
        key: keyApiYamlEditor,
        config: textConfig,
      ),
    );
  }

  void initNewApi() {
    if (currentCompany.currentAPI!.modelYaml.isEmpty) {
      StringBuffer urlparam = StringBuffer();
      for (var element in stateApi.urlParam) {
        urlparam.writeln('  $element : string');
      }

      currentCompany.currentAPI!.modelYaml = '''
url:
${urlparam}query:
header:        
cookies:        
body :
''';

      currentCompany.currentAPI!.mapModelYaml = loadYaml(
        currentCompany.currentAPI!.modelYaml,
        recover: true,
      );
    }
  }
}

//////////////////////////////////////////////////////////////////////////////
class InfoManagerAPIParam extends InfoManager with WidgetModelHelper {
  @override
  String getTypeTitle(NodeAttribut node, String name, dynamic type) {
    String? typeStr;
    if (type is Map) {
      typeStr = 'Param';
    } else if (type is List) {
      // if (name.endsWith('[]')) {
      //   typeStr = 'Array';
      // } else {
      //   typeStr = 'Object';
      // }
    } else if (type is int) {
      typeStr = '?';
    } else if (type is double) {
      typeStr = '?';
    } else if (type is String) {
      if (type.startsWith('\$')) {
        typeStr = type.substring(1);
      }
    }
    typeStr ??= '$type';
    return typeStr;
  }

  @override
  void onNode(NodeAttribut? parent, NodeAttribut child) {}

  @override
  InvalidInfo? isTypeValid(
    NodeAttribut nodeAttribut,
    String name,
    dynamic type,
    String typeTitle,
  ) {
    var type = typeTitle.toLowerCase();
    bool valid = ['path', 'server', 'api'].contains(type);
    if (!valid) {
      return InvalidInfo(color: Colors.red);
    }
    return null;
  }

  @override
  Widget getAttributHeader(TreeNode<NodeAttribut> node) {
    Widget icon = Container();
    var isRoot = node.isRoot;
    var type = node.data!.info.type;
    var isPath = type == 'Path';
    String name = node.data!.yamlNode.key.toString().toLowerCase();

    if (isRoot && name == 'api') {
      icon = Icon(Icons.business);
    } else if (isPath) {
      if (node.data!.info.properties!['\$url'] != null) {
        icon = Icon(Icons.dns_outlined);
      } else {
        icon = Icon(Icons.lan_outlined);
      }
    } else if (name == ('\$url')) {
      icon = Icon(Icons.http_outlined);
      name = 'URL';
    }

    bool isAPI = node.data!.info.type == 'api';
    late Widget w;
    if (name == 'get') {
      w = getChip(Text('GET'), color: Colors.green, height: 27);
    } else if (name == 'post') {
      w = getChip(
        Text('POST', style: TextStyle(color: Colors.black)),
        color: Colors.yellow,
        height: 27,
      );
    } else if (name == 'put') {
      w = getChip(Text('PUT'), color: Colors.blue, height: 27);
    } else if (name == 'delete') {
      w = getChip(
        Text('DELETE', style: TextStyle(color: Colors.black)),
        color: Colors.redAccent.shade100,
        height: 27,
      );
    } else {
      List<String> path = name.split('/');
      List<Widget> wpath = [];
      int i = 0;
      for (var element in path) {
        bool isLast = i == path.length - 1;
        if (element.startsWith('{')) {
          String v = element.substring(1, element.length - 1);
          wpath.add(getChip(Text(v), color: null));
          if (!isLast) {
            wpath.add(Text('/'));
          }
        } else {
          wpath.add(Text(element + (!isLast ? '/' : '')));
        }
        i++;
      }
      w = Row(children: wpath);
    }

    String bufPath = '';
    NodeAttribut? nd = node.data!;

    if (isAPI) {
      nd = nd.parent;
    }
    while (nd != null) {
      var sep = '';
      var n = nd.yamlNode.key.toString().toLowerCase();
      var isServer = nd.info.properties?['\$url'];
      if (isServer != null) {
        n = '<$isServer>';
      }
      if (!n.endsWith('/') && !bufPath.startsWith('/')) sep = '/';
      bufPath = n + sep + bufPath;
      if (nd.info.properties?['\$url'] != null) {
        break;
      }
      nd = nd.parent;
    }
    if (isAPI) {
      bufPath = '[${name.toUpperCase()}] $bufPath';
    }

    return Tooltip(
      message: bufPath.toString(),
      child: IntrinsicWidth(
        //width: 180,
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
          child: Row(
            children: [
              Padding(padding: EdgeInsets.fromLTRB(0, 0, 5, 0), child: icon),
              w,
            ],
          ),
        ),
      ),
    );
  }
}
