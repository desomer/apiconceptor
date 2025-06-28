import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/repaint_manager.dart';
import 'package:jsonschema/json_browser/browse_api.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/feature/api/pan_api_call.dart';
import 'package:jsonschema/feature/api/pan_api_request.dart';
import 'package:jsonschema/feature/api/pan_api_response.dart';
import 'package:jsonschema/widget/widget_keep_alive.dart';
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
  AttributInfo? displayedSchema;

  @override
  Widget build(BuildContext context) {
    repaintManager.addTag(ChangeTag.apichange, "_PanApiEditorState", this, () {
      return displayedSchema != currentCompany.listAPI.currentAttr?.info;
    });

    if (currentCompany.listAPI.currentAttr == null) return Container();
    displayedSchema = currentCompany.listAPI.currentAttr!.info;

    initNewApi();

    currentCompany.apiCallInfo = getPathWidget(
      currentCompany.listAPI.currentAttr!,
    );

    return WidgetTab(
      onInitController: (TabController tab) {
        stateApi.tabSubApi = tab;
        tab.addListener(() {
          if (tab.index == 2) {
            repaintManager.doRepaint(ChangeTag.apiparam);
          }
        });
      },
      listTab: [
        Tab(text: 'Documentation'),
        Tab(text: 'Call examples'),
        Tab(text: 'Test API & check compliant'),
      ],
      listTabCont: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            currentCompany.apiCallInfo!.widgetPath!,
            Expanded(child: getApiTab()),
          ],
        ),
        getExampleTab(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            currentCompany.apiCallInfo!.widgetPath!,
            Expanded(
              child: KeepAliveWidget(
                child: WidgetApiCall(
                  key: ObjectKey(currentCompany.listAPI.currentAttr),
                  apiCallInfo: currentCompany.apiCallInfo!,
                ),
              ),
            ),
          ],
        ),
      ],
      heightTab: 40,
    );
  }

  Widget getExampleTab() {
    return WidgetTab(
      onInitController: (TabController tab) {},
      listTab: [
        Tab(text: 'Temporary'),
        Tab(text: 'Saved'),
        Tab(text: 'Shared'),
        Tab(text: 'History'),
      ],
      listTabCont: [Container(), Container(), Container(), Container()],
      heightTab: 40,
    );
  }

  APICallInfo getPathWidget(NodeAttribut attr) {
    String name = attr.yamlNode.key.toString().toLowerCase();
    var ret = APICallInfo(
      currentAPI: currentCompany.currentAPIResquest,
      currentAPIResponse: currentCompany.currentAPIResponse,
      httpOperation: name,
    );

    List<Widget> wpath = [];
    Widget wOpe = Text('');
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
      var n = getKeyFromYaml(nd.yamlNode.key).toString();
      if (nd.info.properties?['\$server'] != null) {
        var url = nd.info.properties?['\$server'];
        ret.url = '$url${ret.url}';
        wpath.insert(
          1,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5),
            child: Text(url, style: TextStyle(color: Colors.white60)),
          ),
        );
        break;
      }
      var path = _getPathWidgetFormNode(ret, n);
      wpath.insertAll(1, path);
      if (!n.endsWith('/')) {
        ret.url = '/${ret.url}';
        wpath.insert(1, Text('/'));
      }

      nd = nd.parent;
    }

    ret.widgetPath = Card(
      elevation: 10,
      child: ListTile(leading: Icon(Icons.api), title: Row(children: wpath)),
    );

    return ret;
  }

  List<Widget> _getPathWidgetFormNode(APICallInfo apiinfo, String name) {
    List<Widget> wpath = [];
    List<String> path = name.split('/');
    StringBuffer url = StringBuffer();
    int i = 0;
    for (var element in path) {
      bool isLast = i == path.length - 1;
      if (element.startsWith('{')) {
        String v = element.substring(1, element.length - 1);
        wpath.add(getChip(Text(v), color: null));
        stateApi.urlParam.insert(0, v);
        apiinfo.urlParamId.insert(0, v);
        url.write(element);
        if (!isLast) {
          wpath.add(Text('/'));
          url.write('/');
        }
      } else {
        if (element != '') {
          wpath.add(Text(element + (!isLast ? '/' : '')));
          url.write(element + (!isLast ? '/' : ''));
        }
      }
      i++;
    }
    apiinfo.url = '$url${apiinfo.url}';
    return wpath;
  }

  Widget getApiTab() {
    return WidgetTab(
      listTab: [Tab(text: 'Request'), Tab(text: 'Responses')],
      listTabCont: [
        PanRequestApi(request: currentCompany.currentAPIResquest),
        PanResponseApi(response: currentCompany.currentAPIResponse),
      ],
      heightTab: 40,
    );
  }

  late TabController tabEditor;

  void initNewApi() {
    if (currentCompany.currentAPIResquest!.modelYaml.isEmpty) {
      StringBuffer urlparam = StringBuffer();
      for (var element in stateApi.urlParam) {
        urlparam.writeln('  $element : string');
      }

      currentCompany.currentAPIResquest!.modelYaml = '''
path:
${urlparam}query:
header:        
cookies:        
body :
''';
      currentCompany.currentAPIResquest!.mapModelYaml = loadYaml(
        currentCompany.currentAPIResquest!.modelYaml,
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
      typeStr = 'param';
      if (node.level > 1) {
        typeStr = 'object';
      }
      if (name.startsWith(constRefOn)) {
        typeStr = '\$ref';
      }
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
        typeStr = 'Object';
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
    bool valid = [
      'param',
      'string',
      'number',
      'boolean',
      'object',
      '\$ref',
    ].contains(type);
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
    var isRef = node.data!.info.type == '\$ref';

    if (isRoot && name == 'api') {
      icon = Icon(Icons.business);
    } else if (isPath) {
      if (node.data!.info.properties!['\$server'] != null) {
        icon = Icon(Icons.dns_outlined);
      } else {
        icon = Icon(Icons.lan_outlined);
      }
    } else if (name == ('\$server')) {
      icon = Icon(Icons.http_outlined);
      name = 'URL';
    } else if (isRef) {
      icon = Icon(Icons.link);
      name = '\$${node.data?.info.properties?[constRefOn] ?? '?'}';
    }

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
      List<Widget> wpath = [];
      if (isRef) {
        wpath.add(Text(name));
      } else if (isPath) {
        List<String> path = node.data!.yamlNode.key.toString().split('/');
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
      } else {
        wpath.add(Text(node.data!.yamlNode.key.toString()));
      }
      w = Row(children: wpath);
    }

    bool isAPI = node.data!.info.type == 'ope';
    String bufPath = getTooltip(node, isAPI, name);

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

  String getTooltip(TreeNode<NodeAttribut> node, bool isAPI, String name) {
    String bufPath = '';
    NodeAttribut? nd = node.data!;

    if (isAPI) {
      nd = nd.parent;
    }
    while (nd != null) {
      var sep = '';
      var n = nd.yamlNode.key.toString().toLowerCase();
      var isServer = nd.info.properties?['\$server'];
      if (isServer != null) {
        n = '<$isServer>';
      }
      if (!n.endsWith('/') && !bufPath.startsWith('/')) sep = '/';
      bufPath = n + sep + bufPath;
      if (nd.info.properties?['\$server'] != null) {
        break;
      }
      nd = nd.parent;
    }
    if (isAPI) {
      bufPath = '[${name.toUpperCase()}] $bufPath';
    }
    return bufPath;
  }
}

class APICallInfo {
  final String httpOperation;
  final ModelSchema? currentAPI;
  final ModelSchema? currentAPIResponse;
  String url = '';
  List<String> urlParamId = [];
  List<APIParamInfo> params = [];
  Widget? widgetPath;
  dynamic body;
  String bodyStr = '';

  dynamic toJson() {
    Map<String, dynamic> json = {};
    int pos = 0;
    for (var element in params) {
      var type = element.type;
      Map<String, dynamic>? tj = json[type];
      if (tj == null) {
        tj = {};
        json[type] = tj;
      }
      tj[element.name] = {
        'pos': pos,
        'send': element.toSend,
        'value': element.value,
      };
      pos++;
    }
    if (bodyStr.isNotEmpty) {
      json['body'] = {'send': true, 'value': bodyStr};
    }
    print('$json');
    return json;
  }

  void initWithJson(Map<String, dynamic> json) {
    // params.clear();
    // bodyStr = '';
    // body = null;
    List<APIParamInfo> aParams = [];

    for (var element in json.entries) {
      var type = element.key;
      if (type == 'body') {
        bodyStr = element.value['value'];
      } else {
        Map<String, dynamic> listParam = element.value;
        for (var aParam in listParam.entries) {
          var apiParamInfo = APIParamInfo(
            name: aParam.key,
            type: type,
            info: null,
          );
          apiParamInfo.pos = aParam.value['pos'];
          apiParamInfo.toSend = aParam.value['send'];
          apiParamInfo.value = aParam.value['value'];
          aParams.add(apiParamInfo);
        }
      }
    }
    aParams.sort();
    print(aParams);
  }

  APICallInfo({
    required this.currentAPI,
    required this.currentAPIResponse,
    required this.httpOperation,
  });
}

class APIParamInfo implements Comparable<APIParamInfo> {
  int pos = 0;
  bool toSend = true;
  final AttributInfo? info;
  final String type;
  final String name;
  dynamic value;

  APIParamInfo({required this.type, required this.name, required this.info});

  @override
  int compareTo(APIParamInfo other) {
    return pos.compareTo(other.pos);
  }
}
