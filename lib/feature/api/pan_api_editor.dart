import 'dart:convert' show JsonEncoder;

import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:highlight/languages/json.dart';
import 'package:jmespath/jmespath.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/repaint_manager.dart';
import 'package:jsonschema/core/api/call_api_manager.dart';
import 'package:jsonschema/core/api/widget_request_helper.dart';
import 'package:jsonschema/feature/api/pan_api_call.dart';
import 'package:jsonschema/feature/api/pan_api_example.dart';
import 'package:jsonschema/feature/api/pan_api_mock.dart';
import 'package:jsonschema/feature/transform/pan_response_viewer.dart';
import 'package:jsonschema/feature/transform/pan_response_mapper.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_glowing_halo.dart';
import 'package:jsonschema/widget/widget_keep_alive.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget/widget_md_doc.dart';
import 'package:jsonschema/json_browser/browse_model.dart';

import '../../widget/editor/doc_editor.dart';
import 'pan_api_request.dart';

TabController? tabSubApi;

class PanApiEditor extends StatefulWidget {
  const PanApiEditor({super.key, required this.idApi});

  final String idApi;

  @override
  State<PanApiEditor> createState() => _PanApiEditorState();
}

class _PanApiEditorState extends State<PanApiEditor> with WidgetHelper {
  String? url;
  late WidgetRequestHelper requestHelper;

  @override
  Widget build(BuildContext context) {
    var attr = currentCompany.listAPI!.nodeByMasterId[widget.idApi]!;
    currentCompany.listAPI!.selectedAttr = attr;
    requestHelper = WidgetRequestHelper(
      apiNode: currentCompany.listAPI!.selectedAttr!,
      apiCallInfo: getAPICall(
        currentCompany.currentNameSpace,
        currentCompany.listAPI!.selectedAttr!,
      ),
    );

    // callInfo = currentCompany.currentAPICallInfo!;

    return WidgetTab(
      onInitController: (TabController tab) {
        tabSubApi = tab;
        tab.addListener(() {
          if (tab.index == 4) {
            repaintManager.doRepaint(ChangeTag.apiparam);
          }
        });
      },
      listTab: [
        Tab(text: 'Definition'),
        Tab(text: 'Documentation'),
        Tab(text: 'Parameters examples'),
        Tab(text: 'Mock responses'),
        Tab(
          child: Row(
            spacing: 10,
            children: [
              Text('Test & check compliant'),
              RepaintBoundary(
                child: GlowingHalo(child: Icon(Icons.play_circle_outline)),
              ),
            ],
          ),
        ),
        Tab(text: 'Browse response'),
      ],
      listTabCont: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            requestHelper.getAPIWidgetPath(context, 'view'),
            Expanded(child: getDefinitionApiTab()),
          ],
        ),
        WidgetDoc(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            requestHelper.getAPIWidgetPath(context, 'view'),
            Expanded(child: getExampleTab()),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            requestHelper.getAPIWidgetPath(context, 'view'),
            Expanded(
              child: WidgetApiMock(
                idApi: widget.idApi,
                // key: ObjectKey(attr),
                requestHelper: requestHelper,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            requestHelper.getAPIWidgetPath(context, 'preview'),
            Expanded(
              child: KeepAliveWidget(
                child: WidgetApiCall(
                  idApi: widget.idApi,
                  // key: ObjectKey(attr),
                  requestHelper: requestHelper,
                ),
              ),
            ),
          ],
        ),
        //        Container(),
        getBrowseModel(),
      ],
      heightTab: 40,
    );
  }

  Widget getBrowseModel() {
    TextEditingController ctrl = TextEditingController();

    CodeEditorConfig conf = CodeEditorConfig(
      getText: () {
        var encoder = JsonEncoder.withIndent("  ");
        var json = requestHelper.apiCallInfo.aResponse?.reponse?.data ?? {};
        var result = json;
        if (ctrl.text.isNotEmpty) {
          try {
            var r = search(ctrl.text, json);
            if (r != null) {
              result = r;
            }
          } catch (e) {
            print("$e");
          }
        }
        var response = encoder.convert(result);
        return response;
      },
      mode: json,
      onChange: (String json, CodeEditorConfig config) {},
      notifError: ValueNotifier<String>(''),
    );

    ctrl.addListener(() {
      conf.repaintCode();
    });

    return WidgetTab(
      listTab: [
        Tab(text: 'UI'),
        Tab(text: 'form viewer'),
        Tab(text: 'jmse search'),
      ],
      listTabCont: [
        PanResponseViewer(modeLegacy: true, requestHelper: requestHelper),
        PanResponseMapper(
          //key: ObjectKey(currentCompany.listAPI.selectedAttr),
          apiCallInfo: requestHelper.apiCallInfo,
        ),
        Column(
          children: [
            Row(
              spacing: 20,
              children: [
                Icon(Icons.search),
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    decoration: InputDecoration(
                      labelText: 'jmsepath expression',
                    ),
                  ),
                ),
                Icon(Icons.help),
              ],
            ),
            Expanded(child: TextEditor(config: conf, header: 'search')),
          ],
        ),
      ],
      heightTab: 40,
    );
  }

  Widget getExampleTab() {
    return PanApiExample(
      config: ExampleConfig(
        mode: ModeExample.design,
        onSelectHeader: () {
          tabSubApi?.animateTo(4);
        },
        onSelectMock: () {
          tabSubApi?.animateTo(3);
        },
      ),
      requesthelper: requestHelper,
      getSchemaFct: () async {
        var model = ModelSchema(
          category: Category.exampleApi,
          headerName: 'example',
          id: 'example/temp/${widget.idApi}',
          infoManager: InfoManagerApiExample(),
          ref: null,
        );
        await model.loadYamlAndProperties(cache: false, withProperties: true);
        return model;
      },
    );
  }

  APICallManager getAPICall(String namespace, NodeAttribut attr) {
    String httpOpe = attr.info.name.toLowerCase();
    var apiCallInfo = APICallManager(
      namespace: namespace,
      attrApi: attr.info,
      httpOperation: httpOpe,
    );
    return apiCallInfo;
  }

  Widget getDefinitionApiTab() {
    return WidgetTab(
      listTab: [
        Tab(text: 'Request'),
        Tab(text: 'Responses'),
        Tab(text: 'DTO Version'),
      ],
      listTabCont: [
        PanRequestApi(
          getSchemaFct: () async {
            return await GoTo().getApiRequestModel(
              requestHelper.apiCallInfo,
              currentCompany.listAPI!.namespace!,
              widget.idApi,
              withDelay: false,
            );
          },
        ),

        PanRequestApi(
          getSchemaFct: () async {
            return await GoTo().getApiResponseModel(
              requestHelper.apiCallInfo,
              currentCompany.listAPI!.namespace!,
              widget.idApi,
              withDelay: false,
            );
          },
        ),

        Container(),
      ],
      heightTab: 30,
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
      return GetHeaderRowWidget(
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
}
