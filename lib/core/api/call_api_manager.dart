import 'dart:convert';
import 'dart:developer' as dev show log;
import 'dart:math';
import 'package:jsonschema/authorization_manager.dart';
import 'package:jsonschema/core/api/caller_api.dart';
import 'package:jsonschema/core/api/session_storage.dart';
import 'package:jsonschema/core/export/export2json_schema.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/repaint_manager.dart';
import 'package:jsonschema/feature/api/pan_api_example.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/start_core.dart';

class APICallManager {
  APICallManager({
    required this.namespace,
    required this.attrApi,
    required this.httpOperation,
  });

  PageData? parentData;
  bool? modeAPIResponse;
  String namespace;
  AttributInfo attrApi;
  AttributInfo? selectedExample;

  ModelSchema? currentAPIRequest;
  ModelSchema? currentAPIResponse;
  ModelSchema? responseSchema; // en fonction du code retour

  final String httpOperation;
  String url = ''; // url sans les params

  List<String> urlParamFromNode = [];
  List<APIParamInfo> params = [];
  List<String> variablesId = [];
  Map<String, dynamic> requestVariableValue = {};

  dynamic body;
  String bodyStr = '';

  dynamic mock;
  String mockStr = '';

  String preRequestStr = '';
  String postResponseStr = '';

  APIResponse? aResponse;

  List<String> logs = [];

  Future<Map> generateSwagger(
    List<dynamic> servers,
    Map<String, Map<dynamic, dynamic>> cmp,
  ) async {
    currentAPIRequest ??= await ApiRequestNavigator().getApiRequestModel(
      this,
      namespace,
      attrApi.masterID!,
      withDelay: false,
    );

    String httpOpe = httpOperation.toLowerCase();
    var api = currentCompany.listAPI!.selectedAttr!;
    var aServer = getServerFromNode(api);
    servers.removeWhere((s) => s['url'] == aServer);
    servers.add({'url': aServer, 'description': 'Production'});
    var url = getURLfromNode(api, withServer: false);

    String tag = api.info.properties?['tag'] ?? 'default';
    NodeAttribut? docNode = currentAPIRequest!.modelPropExtended['#doc'];
    String? doc = docNode?.info.properties?['#doc'];
    String? summary = api.info.properties?['summary'];
    String? description = api.info.properties?['description'];

    params.clear();
    initParamsForDoc();
    var allparam = [];
    for (var param in params) {
      var info = param.info!;
      var entry = info.properties ?? {};
      bool requi = (entry['required'] == true);
      if (param.type == 'path') {
        requi = true;
      }
      String title = entry['title'] ?? '';
      String description = entry['description'] ?? '';
      var p = {
        'name': info.name,
        'description': '$title $description',
        'in': param.type,
        if (requi) 'required': requi,
        'schema': {'type': info.type},
      };
      allparam.add(p);
    }

    currentAPIResponse ??= await ApiRequestNavigator().getApiResponseModel(
      this,
      namespace,
      attrApi.masterID!,
      withDelay: false,
    );

    var responses = {};
    var r = currentAPIResponse?.mapModelYaml.entries;

    for (MapEntry element in r ?? {}) {
      if (element.key != null && element.value != null) {
        // valide key with regex for http status code
        if (RegExp(r'^[1-5][0-9]{2}$').hasMatch('${element.key}')) {
          var sub = await currentAPIResponse!.getSubSchema(
            subNode: element.key,
          );
          if (sub == null) continue;

          var d = Export2JsonSchema(
            config: BrowserConfig(
              isGet: httpOperation == 'get',
              isApi: true,
              refTarget: 'components/schemas',
            ),
          )..browse(sub, false);

          d.json.remove("\$schema");
          d.json.remove("\$id");
          d.json.remove("\$example");

          var aComp = d.json.remove("components");

          var s = cmp['schemas'] as Map;

          Map allCmp = aComp['schemas'] ?? {};
          for (var e in allCmp.entries) {
            (e.value as Map).remove('title');
            s[e.key] = e.value;
          }

          if (element.value.toString().startsWith('\$')) {
            String ref = element.value.toString().substring(1);
            responses['"${element.key}"'] = {
              'description': '',
              'content': {
                'application/json': {
                  'schema': {'\$ref': '#/components/schemas/$ref'},
                },
              },
            };
            cmp['schemas']![ref] = d.json;
            d.json.remove('title');
          } else {
            responses['"${element.key}"'] = {
              'description': '',
              'content': {
                'application/json': {'schema': d.json},
              },
            };
          }
        }
      }
    }

    var opertionId = api.info.properties?['short name'];
    var aPath = {
      url: {
        httpOpe: {
          if (opertionId != null) 'operationId': opertionId,
          'tags': [tag],
          if (summary != null) 'summary': summary,
          if (description != null || doc != null)
            'description':
                (description ?? '') + (doc != null ? '\n\n$doc' : ''),
          'parameters': allparam,
          if (responses.isNotEmpty) 'responses': responses,
        },
      },
    };

    return aPath;
  }

  Future<List<AttributInfo>> getExamples() async {
    var exampleModel = ModelSchema(
      category: Category.exampleApi,
      headerName: 'example',
      id: 'example/temp/${attrApi.masterID!}',
      infoManager: InfoManagerApiExample(),
      refDomain: null,
    )..namespace = namespace;
    await exampleModel.loadYamlAndProperties(
      cache: false,
      withProperties: true,
    );

    var a = BrowseSingle(config: BrowserConfig());
    a.browse(exampleModel, false);

    var examples = exampleModel.mapInfoByJsonPath.values.where((e) {
      return e.type == 'example';
    });
    return examples.toList();
  }

  void clearRequest() {
    params.clear();
    body = null;
    bodyStr = '';
    preRequestStr = '';
    postResponseStr = '';
    logs = [];
    aResponse = null;
    variablesId = [];
  }

  void initApiParamIfEmpty(ModelSchema currentAPIResquest) {
    if (currentAPIResquest.modelYaml.isEmpty) {
      StringBuffer urlp = StringBuffer();
      for (var element in urlParamFromNode) {
        urlp.writeln('  $element : string');
      }

      currentAPIResquest.modelYaml = '''
path:
${urlp}query:
header:        
cookie:        
body :
''';
      currentAPIResquest.doChangeAndRepaintYaml(null, true, 'init');
    }
  }

  void initParamsForDoc() {
    Map<String, APIParamInfo> mapParam = {};
    _addParams('path', params, mapParam, {});
    _addParams('query', params, mapParam, {});
  }

  bool initListParams({Map<String, dynamic>? paramJson}) {
    Map<String, APIParamInfo> mapParam = {};
    for (var element in params) {
      // garde les parametres
      mapParam['${element.type}/${element.name}'] = element;
    }

    _addParams('path', params, mapParam, paramJson);
    _addParams('query', params, mapParam, paramJson);

    int nbBody = _getNbParam('body');
    params.removeWhere((n) => n.exist == false);

    initUsedVariables();

    return nbBody > 0;
  }

  Future<void> fillVar() async {
    //var idDomain = currentCompany.listDomain.selectedAttr!.info.masterID!;
    var idEnv = currentCompany.listEnv!.selectedAttr?.info.masterID!;
    if (idEnv == null) return;
    var envVar = await loadVarEnv(namespace, idEnv, "variables", true);
    var browseSingle = BrowseSingle(config: BrowserConfig());
    browseSingle.browse(envVar, true);

    for (var element in browseSingle.root) {
      requestVariableValue[element.info.name] =
          element.info.properties?['value'] ?? "";
    }
  }

  int _getNbParam(String type) {
    ModelSchema api = currentAPIRequest!;
    AttributInfo? query = api.mapInfoByJsonPath['root>$type'];
    int i = 0;
    if (query != null) {
      var pos = query.treePosition;
      while (true) {
        AttributInfo? param = api.mapInfoByTreePath['$pos;$i'];
        if (param == null) break;
        i++;
      }
    }
    return i;
  }

  void _addParams(
    String type,
    List<APIParamInfo> params,
    Map<String, APIParamInfo> mapParam,
    Map<String, dynamic>? paramJson,
  ) {
    ModelSchema api = currentAPIRequest!;
    AttributInfo? query = api.mapInfoByJsonPath['root>$type'];
    if (query != null) {
      var jsonParam = paramJson != null ? paramJson[type] : null;
      var pos = query.treePosition;
      int i = 0;
      while (true) {
        AttributInfo? param = api.mapInfoByTreePath['$pos;$i'];
        if (param == null) break;
        String idParam = '$type/${param.name}';
        var mapParam2 = mapParam[idParam];
        if (mapParam2 == null) {
          // param non existant dans l'exemple
          var apiParamInfo = APIParamInfo(
            type: type,
            name: param.name,
            info: param,
            onChange: () {
              onParamConfigChange();
            },
          );
          apiParamInfo.toSend = false;
          params.add(apiParamInfo);
          mapParam[idParam] = apiParamInfo;
          mapParam2 = apiParamInfo;
          apiParamInfo.exist = true;
        } else {
          mapParam2.info = param;
          mapParam2.exist = true;
        }
        if (jsonParam != null) {
          var v = jsonParam[param.name];
          bool isEmpty =
              (v is String && v.isEmpty) ||
              (v is num && v == 0) ||
              (v is bool && !v);
          if (v != null && !isEmpty) {
            mapParam2.value = v;
            mapParam2.toSend = true;
          } else {
            mapParam2.value = null;
            mapParam2.toSend = false;
          }
        }
        i++;
      }
    }
  }

  void initUsedVariables() {
    variablesId.clear();
    variablesId.addAll(extractParameters(url, true));
    variablesId.addAll(extractParameters(url, false));
    for (var element in params) {
      variablesId.addAll(
        extractParameters(element.value?.toString() ?? '', false),
      );
    }
    if (bodyStr.isNotEmpty) {
      variablesId.addAll(extractParameters(bodyStr, false));
    }

    dev.log("variables used $variablesId in $url");
  }

  final regexDoubleQuote = RegExp(r'{{\s*(\w+)\s*}}');
  final regexSimpleQuote = RegExp(r'{\s*(\w+)\s*}');

  List<String> extractParameters(String input, bool simpleQuote) {
    var regex = simpleQuote ? regexSimpleQuote : regexDoubleQuote;

    return regex.allMatches(input).map((match) => match.group(1)!).toList();
  }

  dynamic getVariableValue(String key) {
    var val = requestVariableValue[key];
    if (val == null && parentData != null) {
      val = parentData!.findNearestValueByKey(key);
    }
    return val;
  }

  String replaceVarInRequest(String aUrl) {
    var result = aUrl.replaceAllMapped(RegExp(r'{{(\w+)}}'), (match) {
      final key = match.group(1);
      return getVariableValue(key.toString())?.toString() ??
          match.group(0)!; // garde {{key}} si non trouvé
    });

    result = result.replaceAllMapped(RegExp(r'{(\w+)}'), (match) {
      final key = match.group(1);
      return getVariableValue(key.toString())?.toString() ??
          match.group(0)!; // garde {{key}} si non trouvé
    });

    return result;
  }

  String getURLfromNode(NodeAttribut api, {bool withServer = true}) {
    url = '';

    var nd = api.parent;
    urlParamFromNode.clear();

    while (nd != null) {
      var n = nd.info.name;
      if (nd.info.properties?['\$server'] != null) {
        var urlserv = nd.info.properties?['\$server'];
        if (withServer) {
          url = '$urlserv$url';
        }
        break;
      }
      _addUrlNode(n);

      if (!n.endsWith('/')) {
        url = '/$url';
      }

      nd = nd.parent;
    }

    return url;
  }

  String? getServerFromNode(NodeAttribut api) {
    var nd = api.parent;

    while (nd != null) {
      if (nd.info.properties?['\$server'] != null) {
        var urlserv = nd.info.properties?['\$server'];
        return urlserv;
      }
      nd = nd.parent;
    }

    return null;
  }

  void _addUrlNode(String name) {
    List<String> path = name.split('/');
    StringBuffer urlStr = StringBuffer();
    int i = 0;
    for (var element in path) {
      bool isLast = i == path.length - 1;
      if (element.startsWith('{')) {
        urlStr.write(element);
        if (!isLast) {
          urlStr.write('/');
        }
      } else {
        if (element != '') {
          urlStr.write(element + (!isLast ? '/' : ''));
        }
      }
      i++;
    }
    url = urlStr.toString() + url;
  }

  dynamic toParamJson() {
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
    if (mockStr.isNotEmpty) {
      json['mock'] = {'send': true, 'value': mockStr};
    }
    json['preRequestScript'] = preRequestStr;
    json['postResponseScript'] = postResponseStr;
    print('$json');
    return json;
  }

  void initWithParamJson(Map<String, dynamic> json) {
    List<APIParamInfo> aParams = [];

    for (var element in json.entries) {
      var type = element.key;
      if (type == 'preRequestScript') {
        preRequestStr = element.value;
      } else if (type == 'postResponseScript') {
        postResponseStr = element.value;
      } else if (type == 'body') {
        var v = element.value['value'];
        if (v is String) {
          bodyStr = v;
          try {
            body = jsonDecode(v);
          } catch (e) {
            // TODO
          }
        } else {
          body = v;
          const JsonEncoder encoder = JsonEncoder.withIndent('  ');
          bodyStr = encoder.convert(body);
        }
      } else if (type == 'mock') {
        var v = element.value['value'];
        if (v is String) {
          mockStr = v;
          try {
            mock = jsonDecode(v);
          } catch (e) {
            // TODO
          }
        } else {
          mock = v;
          const JsonEncoder encoder = JsonEncoder.withIndent('  ');
          mockStr = encoder.convert(body);
        }
      } else {
        Map<String, dynamic> listParam = element.value;
        for (var aParam in listParam.entries) {
          var apiParamInfo = APIParamInfo(
            name: aParam.key,
            type: type,
            info: null,
            onChange: () {
              onParamConfigChange();
            },
          );
          apiParamInfo.pos = aParam.value['pos'];
          apiParamInfo.toSend = aParam.value['send'];
          apiParamInfo.value = aParam.value['value'];
          aParams.add(apiParamInfo);
        }
      }
    }

    aParams.sort();
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

  String? getEscapeUrl(dynamic param) {
    if (param == null) return '';
    if (param.toString().startsWith("{{")) return param;
    return Uri.encodeComponent(param.toString());
  }

  void onParamConfigChange() {
    repaintManager.doRepaint(ChangeTag.paramConfigChange);
  }
}

String getFileSizeString({required int bytes, int decimals = 0}) {
  const suffixes = ["b", "kb", "mb", "gb", "tb"];
  if (bytes == 0) return '0 ${suffixes[0]}';
  var i = (log(bytes) / log(1024)).floor();
  return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
}

//---------------------------------------------------------------------------
class APIParamInfo implements Comparable<APIParamInfo> {
  int pos = 0;
  bool toSend = true;
  AttributInfo? info;
  final String type;
  final String name;
  dynamic value;
  bool exist = false;

  final Function? onChange;

  APIParamInfo({
    required this.type,
    required this.name,
    required this.info,
    this.onChange,
  });

  @override
  int compareTo(APIParamInfo other) {
    return pos.compareTo(other.pos);
  }
}
