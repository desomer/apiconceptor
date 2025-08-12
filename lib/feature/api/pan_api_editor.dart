import 'dart:convert';

import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/caller_api.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/repaint_manager.dart';
import 'package:jsonschema/feature/api/pan_api_example.dart';
import 'package:jsonschema/feature/api/widget_api_param.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_glowing_halo.dart';
import 'package:jsonschema/widget/widget_keep_alive.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget_state/state_api.dart';
import 'package:jsonschema/widget/widget_md_doc.dart';
import 'package:jsonschema/json_browser/browse_model.dart';

import 'pan_api_request.dart';

class PanApiEditor extends StatefulWidget {
  const PanApiEditor({super.key, required this.idApi});

  final String idApi;

  @override
  State<PanApiEditor> createState() => _PanApiEditorState();
}

class _PanApiEditorState extends State<PanApiEditor> with WidgetHelper {
  AttributInfo? displayedSchema;
  String? url;

  @override
  Widget build(BuildContext context) {
    repaintManager.addTag(ChangeTag.apichange, "_PanApiEditorState", this, () {
      currentCompany.apiCallInfo = getAPICall(
        currentCompany.listAPI!.currentAttr!,
      );
      if (url != currentCompany.apiCallInfo!.url) {
        url = currentCompany.apiCallInfo!.url;
        return true;
      }

      return displayedSchema != currentCompany.listAPI!.currentAttr?.info;
    });

    // if (currentCompany.listAPI.currentAttr == null) return Container();
    // if (currentCompany.currentAPIResquest!.loadingTime != 0) return Center();

    //displayedSchema = currentCompany.listAPI.currentAttr!.info;
    //initNewApi();

    var attr = currentCompany.listAPI!.nodeByMasterId[widget.idApi]!;
    currentCompany.listAPI!.currentAttr = attr;
    currentCompany.apiCallInfo ??= getAPICall(
      currentCompany.listAPI!.currentAttr!,
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
        Tab(text: 'Definition'),
        Tab(text: 'Call examples'),
        Tab(
          child: Row(
            spacing: 10,
            children: [
              Text('Test API & check compliant'),
              GlowingHalo(child: Icon(Icons.play_circle_outline)),
            ],
          ),
        ),
        Tab(text: 'Validate Model'),
        Tab(text: 'Mock responses'),
        Tab(text: 'Documentation'),
      ],
      listTabCont: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            currentCompany.apiCallInfo!.getAPIWidgetPath(context, 'view'),
            Expanded(child: getDefinitionApiTab()),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            currentCompany.apiCallInfo!.getAPIWidgetPath(context, 'view'),
            Expanded(child: getExampleTab()),
          ],
        ),
        Container(),
        // Column(
        //   crossAxisAlignment: CrossAxisAlignment.start,
        //   children: [
        //     currentCompany.apiCallInfo!.getAPIWidgetPath(context, 'preview'),
        //     Expanded(
        //       child: KeepAliveWidget(
        //         child: WidgetApiCall(
        //           key: ObjectKey(currentCompany.listAPI.currentAttr),
        //           apiCallInfo: currentCompany.apiCallInfo!,
        //         ),
        //       ),
        //     ),
        //   ],
        // ),
        Container(),
        // PanResponseMapper(
        //   key: ObjectKey(currentCompany.listAPI.currentAttr),
        //   apiCallInfo: currentCompany.apiCallInfo!,
        // ),
        Container(),
        Container(),
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
      listTabCont: [
        KeepAliveWidget(
          child: PanApiExample(
            key: ValueKey(currentCompany.apiCallInfo),
            apiCallInfo: currentCompany.apiCallInfo!,
            getSchemaFct: () async {
              var model = ModelSchema(
                category: Category.exampleApi,
                headerName: 'example',
                id: 'example/temp/${widget.idApi}',
                infoManager: InfoManagerApiExample(),
              );
              await model.loadYamlAndProperties(
                cache: false,
                withProperties: true,
              );
              return model;
            },
          ),
        ),
        Container(),
        Container(),
        Container(),
      ],
      heightTab: 40,
    );
  }

  APICallInfo getAPICall(NodeAttribut attr) {
    String httpOpe = attr.yamlNode.key.toString().toLowerCase();

    var apiCallInfo = APICallInfo(
      currentAPI: currentCompany.currentAPIResquest,
      currentAPIResponse: currentCompany.currentAPIResponse,
      httpOperation: httpOpe,
    );

    return apiCallInfo;
  }

  Widget getDefinitionApiTab() {
    return WidgetTab(
      listTab: [Tab(text: 'Request'), Tab(text: 'Responses')],
      listTabCont: [
        PanRequestApi(
          getSchemaFct: () async {
            return await GoTo().initApiRequest(widget.idApi);
          },
        ),

        PanRequestApi(
          getSchemaFct: () async {
            return await GoTo().initApiResponse(widget.idApi);
          },
        ),

        //PanResponseApi(response: currentCompany.currentAPIResponse),
      ],
      heightTab: 40,
    );
  }

  late TabController tabEditor;
}

//////////////////////////////////////////////////////////////////////////////
class InfoManagerAPIParam extends InfoManagerModel with WidgetHelper {
  InfoManagerAPIParam({required super.typeMD});

  @override
  Widget getRowHeader(TreeNodeData<NodeAttribut> node) {
    var isParam = node.data.info.type == 'param';
    if (isParam) {
      String name = node.data.info.name;
      return GetRowWidget(
        icon: Icon(Icons.input),
        name: name,
        isObject: false,
        isArray: false,
      );
    }
    return super.getRowHeader(node);
  }

  @override
  String getTypeTitle(NodeAttribut node, String name, dynamic type) {
    String? typeStr;
    if (type is Map) {
      typeStr = 'param';
      if (node.level > 1) {
        return super.getTypeTitle(node, name, type);
      }
    } else {
      return super.getTypeTitle(node, name, type);
    }
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
    bool valid = ['param'].contains(type);
    if (valid) {
      return null;
    }
    return super.isTypeValid(nodeAttribut, name, type, typeTitle);
  }

  @override
  Widget getAttributHeaderOLD(TreeNode<NodeAttribut> node) {
    //var type = node.data!.info.type;
    if (node.level == 1) {
      var name = node.data!.yamlNode.key.toString();
      List<Widget> w = [
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      ];
      if (typeMD == TypeMD.apiresponse) {
        int? v = int.tryParse(name);
        if (v != null) {
          w = [
            getChip(
              w.first,
              color: v < 300 ? Colors.green : Colors.red.shade400,
            ),
          ];
          w.add(Text(' ${interpretHttpStatusCode(v)}'));
        }
      }
      return Row(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(0, 0, 5, 0),
            child: Icon(Icons.api),
          ),
          ...w,
        ],
      );
    } else {
      return super.getAttributHeaderOLD(node);
    }
  }

  String interpretHttpStatusCode(int code) {
    const statusMessages = {
      // Informational
      100: 'Continue',
      101: 'Switching protocols',
      102: 'Processing',

      // Success
      200: 'Success OK',
      201: 'Successfully created',
      202: 'Accepted',
      203: 'Non-authoritative information',
      204: 'No content',
      205: 'Reset content',
      206: 'Partial content',

      // Redirection
      300: 'Multiple choices',
      301: 'Moved permanently',
      302: 'Found (previously "Moved temporarily")',
      303: 'See other',
      304: 'Not modified',
      307: 'Temporary redirect',
      308: 'Permanent redirect',

      // Client Error
      400: 'Bad request',
      401: 'Unauthorized',
      402: 'Payment required',
      403: 'Forbidden access',
      404: 'Resource not found',
      405: 'Method not allowed',
      406: 'Not acceptable',
      407: 'Proxy authentication required',
      408: 'Request timeout',
      409: 'Conflict',
      410: 'Gone',
      411: 'Length required',
      412: 'Precondition failed',
      413: 'Payload too large',
      414: 'URI too long',
      415: 'Unsupported media type',
      416: 'Range not satisfiable',
      417: 'Expectation failed',
      422: 'Unprocessable entity',
      429: 'Too many requests',

      // Server Error
      500: 'Internal server error',
      501: 'Not implemented',
      502: 'Bad gateway',
      503: 'Service unavailable',
      504: 'Gateway timeout',
      505: 'HTTP version not supported',
      507: 'Insufficient storage',
      511: 'Network authentication required',
    };

    return statusMessages[code] ?? '';
  }

  // @override
  // Widget getAttributHeader(TreeNode<NodeAttribut> node) {
  //   Widget icon = Container();
  //   var isRoot = node.isRoot;
  //   var type = node.data!.info.type;
  //   var isPath = type == 'Path';
  //   String name = node.data!.yamlNode.key.toString().toLowerCase();
  //   var isRef = node.data!.info.type == '\$ref';

  //   if (isRoot && name == 'api') {
  //     icon = Icon(Icons.business);
  //   } else if (isPath) {
  //     if (node.data!.info.properties!['\$server'] != null) {
  //       icon = Icon(Icons.dns_outlined);
  //     } else {
  //       icon = Icon(Icons.lan_outlined);
  //     }
  //   } else if (name == ('\$server')) {
  //     icon = Icon(Icons.http_outlined);
  //     name = 'URL';
  //   } else if (isRef) {
  //     icon = Icon(Icons.link);
  //     name = '\$${node.data?.info.properties?[constRefOn] ?? '?'}';
  //   }

  //   late Widget? w = getHttpOpe(name);
  //   if (w == null) {
  //     List<Widget> wpath = [];
  //     if (isRef) {
  //       wpath.add(Text(name));
  //     } else if (isPath) {
  //       List<String> path = node.data!.yamlNode.key.toString().split('/');
  //       int i = 0;
  //       for (var element in path) {
  //         bool isLast = i == path.length - 1;
  //         if (element.startsWith('{')) {
  //           String v = element.substring(1, element.length - 1);
  //           wpath.add(getChip(Text(v), color: null));
  //           if (!isLast) {
  //             wpath.add(Text('/'));
  //           }
  //         } else {
  //           wpath.add(Text(element + (!isLast ? '/' : '')));
  //         }
  //         i++;
  //       }
  //     } else {
  //       wpath.add(Text(node.data!.yamlNode.key.toString()));
  //     }
  //     w = Row(children: wpath);
  //   }

  //   bool isAPI = node.data!.info.type == 'ope';
  //   String bufPath = getTooltip(node, isAPI, name);

  //   return Tooltip(
  //     message: bufPath.toString(),
  //     child: IntrinsicWidth(
  //       //width: 180,
  //       child: Padding(
  //         padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
  //         child: Row(
  //           children: [
  //             Padding(padding: EdgeInsets.fromLTRB(0, 0, 5, 0), child: icon),
  //             w,
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // String getTooltip(TreeNode<NodeAttribut> node, bool isAPI, String name) {
  //   String bufPath = '';
  //   NodeAttribut? nd = node.data!;

  //   if (isAPI) {
  //     nd = nd.parent;
  //   }
  //   while (nd != null) {
  //     var sep = '';
  //     var n = nd.yamlNode.key.toString().toLowerCase();
  //     var isServer = nd.info.properties?['\$server'];
  //     if (isServer != null) {
  //       n = '<$isServer>';
  //     }
  //     if (!n.endsWith('/') && !bufPath.startsWith('/')) sep = '/';
  //     bufPath = n + sep + bufPath;
  //     if (nd.info.properties?['\$server'] != null) {
  //       break;
  //     }
  //     nd = nd.parent;
  //   }
  //   if (isAPI) {
  //     bufPath = '[${name.toUpperCase()}] $bufPath';
  //   }
  //   return bufPath;
  // }
}

class APICallInfo with WidgetHelper {
  APICallInfo({
    required this.currentAPI,
    required this.currentAPIResponse,
    required this.httpOperation,
  });

  final String httpOperation;
  final ModelSchema? currentAPI;
  final ModelSchema? currentAPIResponse;

  NodeAttribut? selectedExample;
  String url = '';
  List<String> urlParamId = [];
  List<APIParamInfo> params = [];

  dynamic body;
  String bodyStr = '';

  ValueNotifier<int> changeUrl = ValueNotifier(0);

  APIResponse? aResponse;
  ModelSchema? responseSchema;

  Widget getAPIWidgetPath(BuildContext context, String mode) {
    return ValueListenableBuilder(
      valueListenable: changeUrl,
      builder: (context, value, child) {
        var attr = currentCompany.listAPI!.currentAttr;
        if (attr != null) {
          String httpOpe = attr.yamlNode.key.toString().toLowerCase();
          url = '';
          List<Widget> wpath = [];
          Widget wOpe = getHttpOpe(httpOpe) ?? Container();

          wpath.add(wOpe);

          var nd = attr.parent;

          stateApi.urlParam.clear();
          while (nd != null) {
            var n = nd.info.name; // getKeyParamFromYaml(nd.yamlNode.key);
            if (nd.info.properties?['\$server'] != null) {
              var urlserv = nd.info.properties?['\$server'];
              url = '$urlserv$url';
              wpath.insert(
                1,
                Padding(
                  padding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                  child: Text(urlserv, style: TextStyle(color: Colors.white60)),
                ),
              );
              break;
            }
            var path = _getPathWidgetFormNode(n);

            wpath.insertAll(1, path);
            if (!n.endsWith('/')) {
              url = '/$url';
              wpath.insert(1, Text('/'));
            }

            nd = nd.parent;
          }

          wpath.add(WidgetApiParam(apiCallInfo: this));

          wpath.add(
            Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 10),
              child: IconButton.filledTonal(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: addParametersOnUrl(url)),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('URL copied to clipboard')),
                  );
                },
                icon: Icon(Icons.copy),
              ),
            ),
          );

          return Card(
            elevation: 10,
            child: ListTile(
              leading: Icon(Icons.api),
              title: Row(children: wpath),
            ),
          );
        } else {
          return Container();
        }
      },
    );
  }

  List<Widget> _getPathWidgetFormNode(String name) {
    List<Widget> wpath = [];
    List<String> path = name.split('/');
    StringBuffer urlStr = StringBuffer();
    int i = 0;
    for (var element in path) {
      bool isLast = i == path.length - 1;
      if (element.startsWith('{')) {
        String v = element.substring(1, element.length - 1);
        wpath.add(getChip(Text(v), color: null));
        stateApi.urlParam.insert(0, v);
        urlParamId.insert(0, v);
        urlStr.write(element);
        if (!isLast) {
          wpath.add(Text('/'));
          urlStr.write('/');
        }
      } else {
        if (element != '') {
          wpath.add(
            Text(
              element + (!isLast ? '/' : ''),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          );
          urlStr.write(element + (!isLast ? '/' : ''));
        }
      }
      i++;
    }
    url = urlStr.toString() + url;
    return wpath;
  }

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
      json['body'] = {'send': true, 'value': body};
    }
    print('$json');
    return json;
  }

  void initWithJson(Map<String, dynamic> json) {
    List<APIParamInfo> aParams = [];

    for (var element in json.entries) {
      var type = element.key;
      if (type == 'body') {
        body = element.value['value'];
        const JsonEncoder encoder = JsonEncoder.withIndent('  ');
        bodyStr = encoder.convert(body);
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
    // print(aParams);
    params = aParams;
  }

  String addParametersOnUrl(String urlstr) {
    int nbPathParam = 0;
    for (var element in params) {
      if (element.type == 'path') {
        urlstr = urlstr.replaceAll(
          '{${element.name}}',
          getEscapeUrl(element.value) ?? '',
        );
      } else if (element.type == 'query' && element.toSend) {
        if (nbPathParam == 0) {
          urlstr = '$urlstr?${element.name}=${getEscapeUrl(element.value)}';
        } else {
          urlstr = '$urlstr&${element.name}=${getEscapeUrl(element.value)}';
        }
        nbPathParam++;
      }
    }
    return urlstr;
  }

  String? getEscapeUrl(String? param) {
    if (param == null) return null;
    return Uri.encodeComponent(param);
  }
}

class APIParamInfo implements Comparable<APIParamInfo> {
  int pos = 0;
  bool toSend = true;
  AttributInfo? info;
  final String type;
  final String name;
  dynamic value;
  bool exist = false;

  APIParamInfo({required this.type, required this.name, required this.info});

  @override
  int compareTo(APIParamInfo other) {
    return pos.compareTo(other.pos);
  }
}
