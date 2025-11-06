import 'dart:convert';
import 'dart:math';
import 'package:jsonschema/core/api/caller_api.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/start_core.dart';

class APICallManager {
  APICallManager({required this.api, required this.httpOperation});

  AttributInfo api;
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
cookies:        
body :
''';
      currentAPIResquest.doChangeAndRepaintYaml(null, true, 'init');
    }
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
    var idDomain = currentCompany.listDomain.selectedAttr!.info.masterID!;
    var idEnv = currentCompany.listEnv.selectedAttr!.info.masterID!;

    var envVar = await loadVarEnv(idDomain, idEnv, "variables", true);
    var browseSingle = BrowseSingle();
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

    print("var $variablesId");
  }

  final regexDoubleQuote = RegExp(r'{{\s*(\w+)\s*}}');
  final regexSimpleQuote = RegExp(r'{\s*(\w+)\s*}');

  List<String> extractParameters(String input, bool simpleQuote) {
    var regex = simpleQuote ? regexSimpleQuote : regexDoubleQuote;

    return regex.allMatches(input).map((match) => match.group(1)!).toList();
  }

  String replaceVarInRequest(String aUrl) {
    var result = aUrl.replaceAllMapped(RegExp(r'{{(\w+)}}'), (match) {
      final key = match.group(1);
      return requestVariableValue[key]?.toString() ??
          match.group(0)!; // garde {{key}} si non trouvé
    });

    result = result.replaceAllMapped(RegExp(r'{(\w+)}'), (match) {
      final key = match.group(1);
      return requestVariableValue[key]?.toString() ??
          match.group(0)!; // garde {{key}} si non trouvé
    });

    return result;
  }

  String getURLfromNode(NodeAttribut api) {
    url = '';

    var nd = api.parent;
    urlParamFromNode.clear();

    while (nd != null) {
      var n = nd.info.name;
      if (nd.info.properties?['\$server'] != null) {
        var urlserv = nd.info.properties?['\$server'];
        url = '$urlserv$url';
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

  APIParamInfo({required this.type, required this.name, required this.info});

  @override
  int compareTo(APIParamInfo other) {
    return pos.compareTo(other.pos);
  }
}
