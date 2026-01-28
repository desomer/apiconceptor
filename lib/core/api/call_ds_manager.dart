import 'package:collection/collection.dart';
import 'package:jsonschema/authorization_manager.dart';
import 'package:jsonschema/core/api/widget_request_helper.dart';
import 'package:jsonschema/core/api/call_api_manager.dart';
import 'package:jsonschema/core/api/sessionStorage.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/util.dart';
import 'package:jsonschema/feature/api/pan_api_example.dart';
import 'package:jsonschema/feature/transform/pan_response_viewer.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/start_core.dart';
import 'package:yaml/yaml.dart';

class CallerDatasource {
  WidgetRequestHelper? helper;
  ConfigApp configApp = ConfigApp();
  String domainDs = '';
  String dsId = '';
  String apiShortName = '';
  String dsName = '';
  ModelSchema? modelHttp200;
  List<AttributInfo>? exampleData;

  String typeLayout = 'Form';
  List<Map<String, dynamic>> selectionConfig = [];

  Future<void> loadDs(String dataSourceId, String? parentParamId) async {
    dsId = dataSourceId;
    await loadConfig('all', dataSourceId, parentParamId);

    var apiCallInfo = helper!.apiCallInfo;

    apiCallInfo.currentAPIRequest ??= await GoTo().getApiRequestModel(
      apiCallInfo,
      apiCallInfo.namespace,
      apiCallInfo.attrApi.masterID!,
      withDelay: false,
    );

    apiCallInfo.currentAPIResponse ??= await GoTo().getApiResponseModel(
      apiCallInfo,
      apiCallInfo.namespace,
      apiCallInfo.attrApi.masterID!,
      withDelay: false,
    );

    modelHttp200 = await apiCallInfo.currentAPIResponse!.getSubSchema(
      subNode: 200,
    );

    exampleData = await apiCallInfo.getExamples();
  }

  Future<WidgetRequestHelper?> loadConfig(
    String domainName,
    String datasourceId,
    String? parentParamId,
  ) async {
    var apps = await loadDataSource(domainName, false);
    var b = BrowseSingle();
    b.browse(apps, false);
    late AttributInfo app;

    if (datasourceId.startsWith('#name=')) {
      var name = datasourceId.substring(6);
      app = apps.mapInfoByName[name]!.first;
      datasourceId = app.masterID!;
    } else {
      app = apps.nodeByMasterId[datasourceId]!.info;
    }
    dsId = datasourceId;
    dsName = app.name;
    print('load ds $datasourceId name = ${app.name}');

    var configText = app.properties!['config'];
    Map config = {};
    try {
      config = loadYaml(configText, recover: true);
    } catch (e) {
      print(e);
    }

    domainDs = getValueFromPath(config, 'domain');
    apiShortName = getValueFromPath(config, 'api');
    var param = getValueFromPath(config, 'param');

    var pagination = getValueFromPath(config, 'pagination');
    List? links = getValueFromPath(config, 'links');

    configApp.name = apiShortName;

    if (pagination != null) {
      configApp.criteria.paginationVariable = pagination['variable'];
      configApp.criteria.min = pagination['min'] ?? 0;
    }

    for (var link in links ?? const []) {
      configApp.data.links.add(
        ConfigLink(
          onPath: link['link']['on'],
          title: link['link']['title'],
          toDatasrc: link['link']['toDatasrc'],
        ),
      );
    }

    var v = currentCompany.listDomain;
    var r = v.allAttributInfo.values.firstWhereOrNull((element) {
      return element.name.toLowerCase() == domainDs;
    });
    if (r != null) {
      var allApi = await loadAllAPI(namespace: r.masterID);
      var api = allApi.allAttributInfo.values.firstWhereOrNull((element) {
        return element.properties?['short name']?.toString().toLowerCase() ==
            apiShortName;
      });

      if (api != null) {
        String httpOpe = api.name.toLowerCase();
        var apiCallInfo = APICallManager(
          namespace: r.masterID!,
          attrApi: api,
          httpOperation: httpOpe,
        );
        if (parentParamId != null) {
          // affecte la session du parent
          apiCallInfo.parentData = sessionStorage.get(parentParamId);
        }
        var apiNode = allApi.nodeByMasterId[api.masterID!]!;
        String url = apiCallInfo.getURLfromNode(apiNode);
        var def = await loadAPI(id: api.masterID!, namespace: r.masterID);
        print("load api $url ${def.id} ");

        if (param != null) {
          print("load param $param");
          var paramModel = ModelSchema(
            category: Category.exampleApi,
            headerName: 'example',
            id: 'example/temp/${apiNode.info.masterID!}',
            infoManager: InfoManagerApiExample(),
            ref: null,
          )..namespace = r.masterID;
          await paramModel.loadYamlAndProperties(
            cache: false,
            withProperties: true,
          );

          var a = BrowseSingle();
          a.browse(paramModel, false);

          var paramAttr = paramModel.mapInfoByName[param]?.firstOrNull;
          configApp.paramToLoad = paramAttr;
        }

        var v = getValueFromPath(config, '/data/path');
        if (v != null) {
          configApp.data.dataDisplayPath = v.toString().split(';');
        }
        v = getValueFromPath(config, '/criteria/path');
        if (v != null) {
          configApp.criteria.dataDisplayPath = v.toString().split(';');
        }

        helper = WidgetRequestHelper(
          apiNode: apiNode,
          apiCallInfo: apiCallInfo,
        );
      }
    }
    return helper;
  }
}
