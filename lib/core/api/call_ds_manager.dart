import 'package:collection/collection.dart';
import 'package:jsonschema/core/api/widget_api_helper.dart';
import 'package:jsonschema/core/api/call_api_manager.dart';
import 'package:jsonschema/core/api/session_storage.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/util.dart';
import 'package:jsonschema/core/json_browser/browse_model.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/start_core.dart';
import 'package:yaml/yaml.dart';

class CallerDatasource {
  WidgetAPIHelper? helper;
  ConfigDataSource dsConfig = ConfigDataSource();
  String type = '';
  String domainDs = '';
  String dsId = '';
  String dsName = '';

  String? apiShortName;

  ModelSchema? modelHttp200; // pour les type des attributs dans les réponses
  String panBuilderLayout = 'Form';
  List<Map<String, dynamic>> panBuilderConfig = [];
  List<AttributInfo>? listExampleParameters; // pour les critéres de données

  String? modelShortName = '';
  List? facets;
  List? where;
  List? sort;

  bool canSave() {
    return type == 'internal';
  }

  bool isArray() {
    if (dsConfig.criteria.paginationVariable != null) return true;
    return false;
  }

  bool isStorable() {
    if (dsConfig.data.rowsVariable != null) return true;
    return false;
  }

  String? getRowsVariable() {
    return dsConfig.data.rowsVariable;
  }

  Future<void> loadDs(String dataSourceId, String? parentParamId) async {
    dsId = dataSourceId;
    await loadConfig('all', dataSourceId, parentParamId);

    var apiCallInfo = helper!.apiCallInfo;

    apiCallInfo.currentAPIRequest ??= await ApiRequestNavigator()
        .getApiRequestModel(
          apiCallInfo,
          apiCallInfo.namespace,
          apiCallInfo.attrApi.masterID!,
          withDelay: false,
        );

    apiCallInfo.currentAPIResponse ??= await ApiRequestNavigator()
        .getApiResponseModel(
          apiCallInfo,
          apiCallInfo.namespace,
          apiCallInfo.attrApi.masterID!,
          withDelay: false,
        );

    modelHttp200 = await apiCallInfo.currentAPIResponse!.getSubSchema(
      subNode: 200,
    );

    listExampleParameters = await apiCallInfo.getExamples();
  }

  Future<WidgetAPIHelper?> loadConfig(
    String domainName,
    String datasourceId,
    String? parentParamId,
  ) async {
    ModelSchema apps = await getDataSourceModel(domainName);
    late AttributInfo app;

    if (datasourceId.startsWith('#name=')) {
      var name = datasourceId.substring(6);
      app = apps.mapInfoByName[name]!.first;
      datasourceId = app.masterID!;
    } else {
      app = apps.getNodeByMasterIdPath(datasourceId)!.info;
    }
    dsId = datasourceId;
    dsName = app.name;
    print('load ds $datasourceId name = ${app.name}');

    var configText = app.properties!['config'];
    Map configYaml = {};
    try {
      configYaml = loadYaml(configText, recover: true);
    } catch (e) {
      print(e);
    }

    type = getValueFromPath(configYaml, 'type') ?? '';
    domainDs = getValueFromPath(configYaml, 'domain');
    apiShortName = getValueFromPath(configYaml, 'api');
    if (type == '') type = 'api';
    dsConfig.name = apiShortName ?? '';

    var base = getValueFromPath(configYaml, 'base');
    if (base != null) {
      modelShortName = base['table']['model'];
      facets = base['table']['facets'];
      var whereConfig = base['find']['where'];
      print('where = $whereConfig');
      where = yamlToDart(whereConfig);
      var sortConfig = base['find']['sort'];
      print('sort = $sortConfig');
      sort = yamlToDart(sortConfig);
    }
    var pagination = getValueFromPath(configYaml, 'pagination');
    List? links = getValueFromPath(configYaml, 'links');

    if (pagination != null) {
      dsConfig.criteria.paginationVariable = pagination['variable'];
      dsConfig.criteria.min = pagination['min'] ?? 0;
      dsConfig.data.paginationVariable = pagination['maxVariable'];
      dsConfig.data.rowsVariable = pagination['rows'];
    }

    for (var link in links ?? const []) {
      dsConfig.data.links.add(
        ConfigLink(
          onPath: link['link']['on'],
          title: link['link']['title'],
          toDatasrc: link['link']['toDatasrc'],
        ),
      );
    }

    var v = currentCompany.listDomain!;
    var selDomain = v.allAttributInfo.values.firstWhereOrNull((element) {
      return element.name.toLowerCase() == domainDs;
    });

    if (apiShortName != null && selDomain != null) {
      var allApi = await loadAllAPI(namespace: selDomain.masterID);
      var api = allApi.allAttributInfo.values.firstWhereOrNull((element) {
        return element.properties?['short name']?.toString().toLowerCase() ==
            apiShortName;
      });

      if (api != null) {
        String httpOpe = api.name.toLowerCase();
        var apiCallInfo = APICallManager(
          namespace: selDomain.masterID!,
          attrApi: api,
          httpOperation: httpOpe,
        );
        if (parentParamId != null) {
          // affecte la session du parent
          apiCallInfo.parentData = sessionStorage.get(parentParamId);
        }
        var apiNode = await apiCallInfo.initAPIDataSrc(
          dsConfig,
          selDomain,
          allApi,
          configYaml,
        );

        helper = WidgetAPIHelper(
          apiNodeForCalculatePath: apiNode,
          apiCallInfo: apiCallInfo,
        );
      }
    }
    return helper;
  }

  Future<ModelSchema> getDataSourceModel(String domainName) async {
    var apps = await loadDataSource(domainName, false);
    var b = BrowseSingle(config: BrowserConfig());
    b.browse(apps, false);
    return apps;
  }

  void initComputedProps() {
    if (dsConfig.aFactory == null || dsConfig.repositoryId == null) return;
    var repositoryData =
        dsConfig.aFactory!.appData[cwRepos][dsConfig.repositoryId];
    Map computedProps = repositoryData[cwComputed] ?? {};
    dsConfig.computedProps.clear();
    for (var key in computedProps.keys) {
      var cpConfig = computedProps[key];
      dsConfig.computedProps.add(
        ComputedValue(
          id: cpConfig['id'],
          name: cpConfig['name'],
          expression: cpConfig['expression'],
        ),
      );
    }
  }
}

class ConfigDataSource {
  String? name;
  AttributInfo? paramToLoad;
  ConfigBlock criteria = ConfigBlock();
  ConfigBlock data = ConfigBlock();
  WidgetFactory? aFactory;
  String? repositoryId;
  List<ComputedValue> computedProps = [];
}

class ComputedValue {
  String id;
  String name;
  String expression;

  ComputedValue({
    required this.id,
    required this.name,
    required this.expression,
  });
}

class ConfigLink {
  final String onPath;
  final String title;
  final String toDatasrc;

  ConfigLink({
    required this.onPath,
    required this.title,
    required this.toDatasrc,
  });
}

class ConfigBlock {
  List<String> dataDisplayPath = [];
  String? paginationVariable;
  String? rowsVariable;
  int min = 0;
  List<ConfigLink> links = [];
}
