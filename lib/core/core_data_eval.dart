// ignore_for_file: avoid_double_and_int_checks
import 'package:collection/collection.dart';
import 'package:dart_eval/dart_eval.dart';
import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:dart_eval/stdlib/core.dart';
import 'package:dio/dio.dart';
import 'package:jmespath/jmespath.dart' show search;
import 'package:jsonschema/core/api/caller_api.dart';
import 'package:jsonschema/core/api/call_api_manager.dart';
import 'package:jsonschema/start_core.dart';

class CoreDataEval {
  dynamic self;
  Map<String, dynamic>? variables;

  late String expr;
  late Runtime libRuntime;
  late $Map mapFunction;
  late String _program;

  int lastIdx = 0;

  late List<String> lines;
  int lastLine = 0;

  bool compilOk = false;
  List<String> logger = [];

  dynamic compil(String expression, List<String> logs) {
    logger = logs;
    expr = expression;
    final compiler = Compiler();

    lines = splitIgnoringStringsAndComments(expr);
    compilProgram(lines, -1, compiler);

    Map<$String, $Closure> map = {};
    map[$String('getVar')] = $Closure((runtime, target, args) {
      String attr = args[0]!.$value.toString();
      var vr = variables![attr];
      return getEvalObj(vr);
    });
    map[$String('setVar')] = $Closure((runtime, target, args) {
      String attr = args[0]!.$value.toString();
      var v = args[1]!.$reified;
      variables![attr] = v;
      return null;
    });
    map[$String('print')] = $Closure((runtime, target, args) {
      String log = args[0]!.$reified.toString();
      //print('log eval $log');
      logger.add("[PRINT] $log");
      return null;
    });
    map[$String('debug')] = $Closure((runtime, target, args) {
      lastIdx = args[0]!.$value;
      lastLine = args[1]!.$value;
      //print('debug $lastIdx > $lastLine');
      logger.add("> ${lines[lastLine].trim()}");
      return null;
    });
    map[$String('getApi')] = $Closure((runtime, target, args) {
      String domain = args[0]!.$value.toString().toLowerCase();
      String name = args[1]!.$value.toString().toLowerCase();
      return $Future.wrap(Future.value(_loadApi(domain, name)));
    });

    map[$String('executeApi')] = $Closure((runtime, target, args) {
      Map<dynamic, dynamic> req = args[0]!.$reified;
      return $Future.wrap(Future.value(_executeApi(req)));
    });

    map[$String('search')] = $Closure((runtime, target, args) {
      Map<dynamic, dynamic> data = args[0]!.$reified;
      var d = convertMapRecursively(data);
      String searchString = args[1]!.$value.toString();
      var search2 = search(searchString, d);
      return getEvalObj(search2);
    });

    mapFunction = $Map.wrap(map);
  }

  final regexJmes = RegExp(r'\$\.api\.response\.jmes\[');
  final regexVar = RegExp(r'\$\.var\[');

  ResultCompil compilProgram(List<String> lines, int ligne, Compiler compiler) {
    StringBuffer debug = StringBuffer();
    compilOk = false;

    int i = 1;
    int nb = 0;
    for (var element in lines) {
      var count = countNewlines(element);
      var nbCr = countLeadingLineBreaks(element);
      if (element.trim().isNotEmpty) {
        debug.write(
          '_\$\$debug(${i + nbCr}, $nb );', //\'\'\'${escapeQuotes(element.trim())}\'\'\'
        );
        var analyzeLine = removeDartComments(element).trim();

        var match = regexJmes.firstMatch(analyzeLine);
        analyzeLine = _doMatch(match, analyzeLine, (str, next) {
          return '${analyzeLine.substring(0, match!.start)}search(_response, $str)$next';
        });

        match = regexVar.firstMatch(analyzeLine);
        analyzeLine = _doMatchVar(match, analyzeLine, (str, next, equal) {
          if (equal) {
            return '${analyzeLine.substring(0, match!.start)}setVar($str,$next)';
          } else {
            return '${analyzeLine.substring(0, match!.start)}getVar($str)$next';
          }
        });

        if (analyzeLine.startsWith('\$.api.')) {
          String e = analyzeLine.substring(6);
          if (e.endsWith('.load()')) {
            var eq = e.split('.');
            if (eq.length == 3) {
              analyzeLine = "\n_api = await getApi('${eq[0]}', '${eq[1]}')";
            }
          } else if (e.endsWith('send()')) {
            var eq = e.split('.');
            if (eq.length == 1) {
              analyzeLine = "\n_response = await send(_api)";
            }
          }
        }
        debug.write("\n$analyzeLine;");
      }

      i = i + count;
      if (ligne >= 0 && i > ligne) break;
      nb++;
    }

    _program = '''

    Map<String, Function> _callback = {};
    Map<String, dynamic> _api = {};
    Map<String, dynamic> _response = {};

    dynamic getApi(domain, name)
    {
      var s = _callback['getApi'];
      return s(domain, name);
    }

    dynamic send(req)
    {
      var s = _callback['executeApi'];
      return s(req);
    }    

    dynamic sendApi(String domain, String name) async
    {
       var r = await getApi(domain, name);
       return await send(r);
    }

    dynamic main(dynamic v, Map<String, Function> callback) async {
      _callback = callback;
      var getVar = callback['getVar'];
      var setVar = callback['setVar'];var print = callback['print'];
      var search = callback['search'];
      var _\$\$debug = callback['debug'];
      var self = v;
      $debug
      return 'ok';
    }
    ''';

    //print(_program);

    String error = '';
    try {
      final lib = compiler.compile({
        'my_package': {'main.dart': _program},
      });
      libRuntime = Runtime.ofProgram(lib);
      compilOk = true;
      // ignore: unused_catch_clause
    } catch (e) {
      error = e.toString();
    }

    if (!compilOk && ligne == -1) {
      int j = 0;
      ResultCompil cr;
      while (true) {
        cr = compilProgram(lines, j, compiler);
        if (cr.error != null) {
          break;
        }
        j = cr.idx;
      }
      logger.add(
        "[ERROR] compil error row ${cr.idx} ${cr.line.trim()} ${cr.error}",
      );
      return cr;
    }

    if (!compilOk && ligne >= 0) {
      return ResultCompil(idx: i, line: lines[nb], error: error);
    }

    return ResultCompil(idx: i, line: '');
  }

  String _doMatch(RegExpMatch? match, String analyzeLine, Function fct) {
    if (match != null) {
      var str = analyzeLine.substring(match.end);
      int i = 0;
      int idxParentese = 0;
      for (; i < str.length; i++) {
        if (str[i] == '[') idxParentese++;
        if (str[i] == ']') idxParentese--;
        if (idxParentese < 0) break;
      }
      var strin = str.substring(0, i);
      var next = str.substring(i + 1);

      analyzeLine = fct(strin, next);
    }
    return analyzeLine;
  }

  String _doMatchVar(RegExpMatch? match, String analyzeLine, Function fct) {
    if (match != null) {
      var str = analyzeLine.substring(match.end);
      int i = 0;
      int idxParentese = 0;
      for (; i < str.length; i++) {
        if (str[i] == '[') idxParentese++;
        if (str[i] == ']') idxParentese--;
        if (idxParentese < 0) break;
      }
      var strin = str.substring(0, i);
      var next = str.substring(i + 1);
      i = 0;
      bool lastequl = false;
      for (; i < next.length; i++) {
        var c = next[i];
        if (c == ' ' || c == '\t') continue;
        if (c == '=') {
          if (lastequl) {
            // cas ==
            lastequl = false;
            break;
          }
          lastequl = true;
          continue;
        }
        if (lastequl) {
          next = next.substring(i);
          break;
        }
      }

      analyzeLine = fct(strin, next, lastequl);
    }
    return analyzeLine;
  }

  Future _executeApi(Map<dynamic, dynamic> req) async {
    final cancelToken = CancelToken();
    var ret = await CallerApi().sendApi(
      req['method'],
      req['url'],
      req['body'],
      cancelToken,
    );

    dynamic response;
    if (ret.toDisplayError == null && ret.reponse?.data is String) {
      response = ret.reponse!.data.toString();
    } else {
      response = ret.toDisplayError ?? ret.reponse?.data ?? {};
    }

    return getEvalObj(response);
  }

  Future _loadApi(String domain, String name) async {
    dynamic req;

    var v = currentCompany.listDomain;
    var r = v.allAttributInfo.values.firstWhereOrNull((element) {
      return element.name.toLowerCase() == domain;
    });
    if (r != null) {
      var allApi = await loadAllAPI(namespace: r.masterID);
      var api = allApi.allAttributInfo.values.firstWhereOrNull((element) {
        return element.properties?['short name']?.toString().toLowerCase() ==
            name;
      });

      if (api != null) {
        String httpOpe = api.name.toLowerCase();
        var apiCallInfo = APICallManager(namespace: domain, attrApi: api, httpOperation: httpOpe);
        apiCallInfo.getURLfromNode(allApi.nodeByMasterId[api.masterID!]!);

        var def = await loadAPI(id: api.masterID!, namespace: r.masterID);
        print("api $def");
        req = {"method": httpOpe, "url": apiCallInfo.url};
      }
    }
    if (req == null) {
      throw 'api $domain.$name not found';
    }

    return getEvalObj(req);
  }

  Map<String, dynamic> convertMapRecursively(Map<dynamic, dynamic> input) {
    return input.map((key, value) {
      final newKey = key.toString();
      dynamic newValue;

      if (value is Map) {
        newValue = convertMapRecursively(value);
      } else if (value is List) {
        newValue =
            value.map((item) {
              if (item is Map) {
                return convertMapRecursively(item);
              }
              return item;
            }).toList();
      } else {
        newValue = value;
      }

      return MapEntry(newKey, newValue);
    });
  }

  String removeDartComments(String code) {
    final singleLine = RegExp(r'//.*?$|///.*?$', multiLine: true);
    final multiLine = RegExp(r'/\*[\s\S]*?\*/');
    return code.replaceAll(singleLine, '').replaceAll(multiLine, '');
  }

  String escapeQuotes(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('\$', '\\\$') // échappe les antislashs d'abord
        .replaceAll("'", "\\'") // échappe les guillemets simples
        .replaceAll('"', '\\"'); // échappe les guillemets doubles
  }

  int countNewlines(String input) {
    return RegExp('\n').allMatches(input).length;
  }

  int countLeadingLineBreaks(String input) {
    int k = 0;
    for (var i = 0; i < input.length; i++) {
      var c = input[i];
      if (c == ' ' || c == '\n' || c == '\t') {
        if (c == '\n') k++;
      } else {
        break;
      }
    }
    return k;
  }

  List<String> splitIgnoringStringsAndComments(String input) {
    List<String> result = [];
    StringBuffer buffer = StringBuffer();
    bool inSingleQuote = false;
    bool inDoubleQuote = false;
    bool inTripleQuote = false;
    bool inLineComment = false;
    bool inBlockComment = false;

    for (int i = 0; i < input.length; i++) {
      String char = input[i];
      String? next = i + 1 < input.length ? input[i + 1] : null;
      String? next2 = i + 2 < input.length ? input[i + 2] : null;

      // Détection des commentaires
      if (!inSingleQuote && !inDoubleQuote && !inTripleQuote) {
        if (!inLineComment && !inBlockComment && char == '/' && next == '/') {
          inLineComment = true;
          buffer.write(char);
          continue;
        } else if (!inLineComment &&
            !inBlockComment &&
            char == '/' &&
            next == '*') {
          inBlockComment = true;
          buffer.write(char);
          continue;
        } else if (inLineComment && char == '\n') {
          inLineComment = false;
        } else if (inBlockComment && char == '*' && next == '/') {
          inBlockComment = false;
          i++; // skip '/'
          continue;
        }
      }

      // Détection des chaînes
      if (!inLineComment && !inBlockComment) {
        if (!inSingleQuote && !inDoubleQuote && !inTripleQuote) {
          if (char == "'" && next == "'" && next2 == "'") {
            inTripleQuote = true;
            buffer.write("'''");
            i += 2;
            continue;
          } else if (char == "'") {
            inSingleQuote = true;
          } else if (char == '"') {
            inDoubleQuote = true;
          }
        } else {
          if (inTripleQuote && char == "'" && next == "'" && next2 == "'") {
            inTripleQuote = false;
            buffer.write("'''");
            i += 2;
            continue;
          } else if (inSingleQuote && char == "'") {
            inSingleQuote = false;
          } else if (inDoubleQuote && char == '"') {
            inDoubleQuote = false;
          }
        }
      }

      // Séparation par ;
      if (!inSingleQuote &&
          !inDoubleQuote &&
          !inTripleQuote &&
          !inLineComment &&
          !inBlockComment &&
          char == ';') {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      result.add(buffer.toString().trim());
    }

    return result;
  }

  $Value getEvalObj(dynamic vr) {
    if (vr == null) {
      return $null();
    } else if (vr is double) {
      return $double(vr);
    } else if (vr is int) {
      return $int(vr);
    } else if (vr is Map) {
      Map<$String, dynamic> ret = {};
      for (var element in vr.entries) {
        ret[$String(element.key)] = getEvalObj(element.value);
      }
      return $Map.wrap(ret);
    } else if (vr is List) {
      var ret = [];
      for (var element in vr) {
        ret.add(getEvalObj(element));
      }
      return $List.wrap(ret);
    } else {
      return $String(vr.toString());
    }
  }

  ResultExec execute({required List<String> logs}) {
    logger = logs;
    dynamic ret;
    try {
      if (compilOk) {
        ret = libRuntime.executeLib('package:my_package/main.dart', 'main', [
          self != null ? $double(self) : $null(),
          mapFunction,
        ]);
      }
    } catch (e) {
      var msg = e.toString();
      logger.add("[ERROR] $msg");
      ret = ResultExec(idx: lastIdx, line: lines[lastLine].trim(), error: msg);
    }

    return ResultExec(
      idx: lastIdx,
      line: lines[lastLine].trim(),
      value: ret is $Value ? ret.$reified : null,
    );
  }
}

class ResultCompil {
  final String? error;
  final int idx;
  final String line;

  ResultCompil({required this.idx, required this.line, this.error});
}

class ResultExec {
  final String? error;
  final int idx;
  final String line;
  final dynamic value;

  ResultExec({required this.idx, required this.line, this.error, this.value});
}
