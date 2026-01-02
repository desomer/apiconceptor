import 'dart:convert' show JsonEncoder;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight/languages/json.dart' show json;
import 'package:jmespath/jmespath.dart' show search;
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/api/call_api_manager.dart';
import 'package:jsonschema/core/api/widget_request_helper.dart';
import 'package:jsonschema/feature/api/pan_api_doc_response.dart';
import 'package:jsonschema/feature/api/pan_api_example.dart';
import 'package:jsonschema/feature/api/pan_api_param.dart';
import 'package:jsonschema/feature/api/pan_api_selector.dart';
import 'package:jsonschema/feature/api/pan_api_selector_tag.dart';
import 'package:jsonschema/feature/transform/pan_response_viewer.dart';
import 'package:jsonschema/feature/transform/pan_response_mapper.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:jsonschema/widget/widget_disable_overlay.dart';
import 'package:jsonschema/widget/widget_glowing_halo.dart';
import 'package:jsonschema/widget/widget_keep_alive.dart';
import 'package:jsonschema/widget/widget_split.dart';
import 'package:jsonschema/widget/widget_tab.dart';

class BrowseAPIPage extends GenericPageStateful {
  const BrowseAPIPage({
    required this.namespace,
    required this.byTag,
    super.key,
  });
  final String namespace;
  final bool byTag;

  @override
  State<StatefulWidget> createState() {
    return BrowseAPIPageState();
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    PageInit? pageInit,
  ) {
    return NavigationInfo()
      ..navLeft = [
        BreadNode(
          icon: const Icon(Icons.tag),
          settings: const RouteSettings(name: 'API by tag'),
          type: BreadNodeType.widget,
          path: Pages.apiBrowserTag.urlpath,
        ),

        BreadNode(
          icon: const Icon(Icons.api_outlined),
          settings: const RouteSettings(name: 'API UI'),
          type: BreadNodeType.widget,
          path: Pages.apiBrowserUI.urlpath,
        ),

        BreadNode(
          icon: const Icon(Icons.api_outlined),
          settings: const RouteSettings(name: 'API Tree'),
          type: BreadNodeType.widget,
          path: Pages.apiBrowser.urlpath,
        ),

        BreadNode(
          icon: const Icon(Icons.bubble_chart),
          settings: const RouteSettings(name: 'Graph view'),
          type: BreadNodeType.widget,
        ),
      ]
      ..breadcrumbs = [
        BreadNode(
          settings: const RouteSettings(name: 'List API'),
          type: BreadNodeType.widget,
        ),
        BreadNode(
          settings: const RouteSettings(name: 'Domain'),
          type: BreadNodeType.domain,
          path: byTag ? Pages.apiBrowserTag.urlpath : Pages.apiBrowser.urlpath,
        ),
      ];
  }
}

class BrowseAPIPageState extends GenericPageState<BrowseAPIPage> {
  final cController = CarouselController(initialItem: 0);

  final disableSelector = ValueNotifier(false);
  final disableExample = ValueNotifier(false);
  final disableResponse = ValueNotifier(true);
  final disableViewer = ValueNotifier(true);
  final refreshExample = ValueNotifier(0);
  final refreshParam = ValueNotifier(0);
  final refreshResponse = ValueNotifier(0);

  GlobalKey paramKey = GlobalKey(debugLabel: 'paramKey');

  WidgetRequestHelper? requestHelper;

  var flexWeights = [1, 10, 1];

  APICallManager getAPICall(String namespace, NodeAttribut attr) {
    String httpOpe = attr.info.name.toLowerCase();
    var apiCallInfo = APICallManager(
      namespace: namespace,
      attrApi: attr.info,
      httpOperation: httpOpe,
    );
    return apiCallInfo;
  }

  GlobalKey exampleKey = GlobalKey(debugLabel: "exampleKey");
  String currentIdApi = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    disableSelector.dispose();
    disableExample.dispose();
    refreshExample.dispose();
    refreshParam.dispose();
    refreshResponse.dispose();
    cController.dispose();
    super.dispose();
  }

  Widget _createExampleTab(String idApi) {
    return PanApiExample(
      config: ExampleConfig(
        mode: ModeExample.browse,
        onSelectHeader: () {},
        onSelectMock: () {},
      ),
      key: exampleKey,
      requesthelper: requestHelper!,
      getSchemaFct: () async {
        // callInfo.currentAPIRequest = null;
        // refreshParam.value++;

        var model = ModelSchema(
          category: Category.exampleApi,
          headerName: 'Parameters book',
          id: 'example/temp/$idApi',
          infoManager: InfoManagerApiExample(),
          ref: null,
        );
        await model.loadYamlAndProperties(cache: false, withProperties: true);

        var request = await GoTo().getApiRequestModel(
          requestHelper!.apiCallInfo,
          currentCompany.listAPI!.namespace!,
          idApi,
          withDelay: false,
        );

        var resp = await GoTo().getApiResponseModel(
          requestHelper!.apiCallInfo,
          currentCompany.listAPI!.namespace!,
          idApi,
          withDelay: false,
        );

        requestHelper!.apiCallInfo.currentAPIRequest = request;
        requestHelper!.apiCallInfo.currentAPIResponse = resp;
        refreshParam.value++;

        return model;
      },
    );
  }

  var currentNamespace = "";

  @override
  Widget build(BuildContext context) {
    if (currentNamespace != widget.namespace) {
      currentIdApi = '';
      requestHelper = null;
      disableSelector.value = false;
      disableExample.value = false;
      refreshExample.value++;
      refreshParam.value++;
      refreshResponse.value++;

      cController.animateToItem(
        0,
        curve: Curves.easeInOut,
        duration: Duration(milliseconds: 200),
      );
    }

    Widget panAPISelector;
    if (widget.byTag) {
      panAPISelector = PanApiSelectorTag(
        getSchemaFct: () async {
          await loadAllAPIGlobal();
          return currentCompany.listAPI!;
        },
        onSelModel: (idApi) {
          gotoApi(idApi);
        },
      );
    } else {
      panAPISelector = PanAPISelector(
        browseOnly: true,
        onSelModel: (idApi) {
          gotoApi(idApi);
        },
        //   key: keySel,
        getSchemaFct: () async {
          await loadAllAPIGlobal();
          return currentCompany.listAPI!;
        },
      );
    }

    var viewSelector = KeepAliveWidget(
      child: WidgetToggleDisabled(
        toogle: disableSelector,
        child: panAPISelector,
        onTapForEnable: () {
          disableSelector.value = false;
          cController.animateToItem(
            0,
            curve: Curves.easeInOut,
            duration: Duration(milliseconds: 200),
          );
          currentIdApi = "";
          requestHelper = null;
          refreshExample.value++;
        },
      ),
    );

    var viewExample = WidgetToggleDisabled(
      toogle: disableExample,
      child: getExampleAndDoc(),
      onTapForEnable: () {
        disableExample.value = false;
        disableSelector.value = true;
        requestHelper?.doClearResponse(inProgress: false);
        cController.animateToItem(
          1,
          curve: Curves.easeInOut,
          duration: Duration(milliseconds: 200),
        );
      },
    );

    void onTapForEnable() {
      disableResponse.value = true;
      disableViewer.value = false;
      cController.animateToItem(
        3,
        curve: Curves.easeInOut,
        duration: Duration(milliseconds: 200),
      );
    }

    var viewResponse = WidgetToggleDisabled(
      toogle: disableViewer,
      childOnDisabled: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Colors.blue),
            ),
            onPressed: onTapForEnable,
            label: Text('Browse Data'),
            icon: Icon(Icons.browse_gallery_outlined),
          ),
        ],
      ),
      onTapForEnable: onTapForEnable,
      child: ValueListenableBuilder(
        valueListenable: disableViewer,
        builder: (context, value, child) {
          if (disableViewer.value) {
            return Container();
          } else {
            return FutureBuilder(
              future: Future.delayed(Duration(milliseconds: 300)),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  return getBrowseModel();
                }
              },
            );
          }
        },
      ),
    );

    return CarouselView.weighted(
      consumeMaxWeight: true,
      controller: cController,
      enableSplash: false,
      flexWeights: flexWeights,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadiusGeometry.all(Radius.circular(10)),
      ),
      children: [viewSelector, viewExample, getResponse(), viewResponse],
    );
  }

  Widget getBrowseModel() {
    TextEditingController ctrl = TextEditingController();

    CodeEditorConfig conf = CodeEditorConfig(
      getText: () {
        var encoder = JsonEncoder.withIndent("  ");
        var json = requestHelper!.apiCallInfo.aResponse?.reponse?.data ?? {};
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
        PanResponseViewer(modeLegacy: true, requestHelper: requestHelper!),
        PanResponseMapper(
          //key: ObjectKey(currentCompany.listAPI.selectedAttr),
          apiCallInfo: requestHelper!.apiCallInfo,
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

  void gotoApi(String idApi) {
    disableSelector.value = true;
    cController.animateToItem(
      1,
      curve: Curves.easeInOut,
      duration: Duration(milliseconds: 200),
    );

    var attr = currentCompany.listAPI!.nodeByMasterId[idApi]!;
    currentCompany.listAPI!.selectedAttr = attr;

    requestHelper = null;
    currentIdApi = '';

    Future.delayed(Duration(milliseconds: 10)).then((value) {
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        requestHelper = WidgetRequestHelper(
          apiNode: attr,
          apiCallInfo: getAPICall(
            currentCompany.currentNameSpace,
            currentCompany.listAPI!.selectedAttr!,
          ),
        );
        currentIdApi = idApi;
        refreshExample.value++;
      });
    });
  }

  Widget getExampleAndDoc() {
    return WidgetTab(
      listTab: [
        Tab(text: 'Parameters examples'),
        Tab(text: 'Request documentation'),
        Tab(text: 'Responses documentation'),
      ],
      listTabCont: [getExample(), getDocRequest(), getDocResponse()],
      heightTab: 40,
    );
  }

  Widget getDocRequest() {
    return ValueListenableBuilder(
      valueListenable: refreshExample,
      builder: (context, value, child) {
        if (currentIdApi != '' && requestHelper != null) {
          return PanApiDocResponse(
            key: ObjectKey(requestHelper),
            getSchemaFct: () async {
              await Future.delayed(Duration(milliseconds: gotoDelay * 2));
              return requestHelper!.apiCallInfo.currentAPIRequest!;
            },
          );
        }
        return Container();
      },
    );
  }

  Widget getDocResponse() {
    return ValueListenableBuilder(
      valueListenable: refreshExample,
      builder: (context, value, child) {
        if (currentIdApi != '' && requestHelper != null) {
          return PanApiDocResponse(
            key: ObjectKey(requestHelper),
            getSchemaFct: () async {
              await Future.delayed(Duration(milliseconds: gotoDelay * 2));
              return requestHelper!.apiCallInfo.currentAPIResponse!;
            },
          );
        }
        return Container();
      },
    );
  }

  Widget getExample() {
    return ValueListenableBuilder(
      valueListenable: refreshExample,
      builder: (context, value, child) {
        if (currentIdApi != '') {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ClipRect(
                      child: requestHelper!.getAPIWidgetPath(context, 'view'),
                    ),
                  ),
                  GlowingHalo(
                    child: TextButton.icon(
                      onPressed: () {
                        disableExample.value = true;
                        disableResponse.value = false;
                        cController.animateToItem(
                          2,
                          curve: Curves.easeInOut,
                          duration: Duration(milliseconds: 200),
                        );
                        refreshResponse.value++;
                        SchedulerBinding.instance.addPostFrameCallback((
                          timeStamp,
                        ) {
                          requestHelper!.doSend();
                        });
                      },
                      icon: Icon(Icons.send),
                      label: Text("Send"),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: SplitView(
                  primaryWidth: -1,
                  flex1: 1,
                  flex2: 1,
                  children: [_createExampleTab(currentIdApi), getParam()],
                ),
              ),
            ],
          );
        }
        return Container();
      },
    );
  }

  Widget getParam() {
    return ValueListenableBuilder(
      key: paramKey,
      valueListenable: refreshParam,
      builder: (context, value, child) {
        if (requestHelper != null &&
            requestHelper!.apiCallInfo.currentAPIRequest != null) {
          return PanApiParam(
            requestHelper: requestHelper!,
            config: ApiParamConfig(
              action: Container(),
              modeSeparator: Separator.left,
              withBtnAddMock: false,
              modeMock: false,
            ),
          );
        }
        return Container();
      },
    );
  }

  Widget getResponse() {
    return WidgetToggleDisabled(
      toogle: disableResponse,
      onTapForEnable: () {
        disableResponse.value = false;
        disableViewer.value = true;
        cController.animateToItem(
          2,
          curve: Curves.easeInOut,
          duration: Duration(milliseconds: 200),
        );
      },
      child: ValueListenableBuilder(
        valueListenable: refreshResponse,
        builder: (context, value, child) {
          if (requestHelper != null &&
              requestHelper!.apiCallInfo.currentAPIRequest != null) {
            return requestHelper!.getPanResponse(context);
          }
          return Container();
        },
      ),
    );
  }
}
