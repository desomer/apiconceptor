import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/core/util.dart';

dynamic getDataFromPage(
  String key,
  Map<String, dynamic>? variables,
  //Map<String, AttributBindInfo> listBindInfo,
) {
  String attr = key.toString();
  CwWidgetCtx ctx = variables!['\$\$__ctx__\$\$'];
  BuildContext? context = variables['\$\$__buildctx__\$\$'];
  if (context == null) {
    // special case for export data
    Map row = variables['\$\$__row__\$\$'];
    String rowPath = variables['\$\$__rowPath__\$\$'];
    String path = attr.substring(rowPath.length + 1);
    path = path.replaceAll('.', '/');
    var valueFromPath = getValueFromPath(row, path);
    return valueFromPath;
  } else {
    CwWidgetStateBindJson? state = variables['\$\$__state__\$\$'];
    var ret = ctx.getDataValueForEval(
      jsonPath: attr,
      context: context,
      //listBindInfo: listBindInfo,
      state: state,
    );
    return ret;
  }
}

mixin HelperCoreExpression {
  final regexVar = RegExp(r'\$\.var\[');
  final regexVarData = RegExp(r'\$\.data\[');
  bool compilOk = false;
  int ligne = -1;

  String transformExpr(List<String> lines, String contextKey) {
    StringBuffer debug = StringBuffer();
    compilOk = false;

    int i = 1;
    int nb = 0;
    for (var element in lines) {
      var count = countNewlines(element);
      var nbCr = countLeadingLineBreaks(element);
      if (element.trim().isNotEmpty) {
        debug.write('ap_debug(${i + nbCr}, $nb );');
        var analyzeLine = removeDartComments(element).trim();

        // var match = regexJmes.firstMatch(analyzeLine);
        // analyzeLine = _doMatch(match, analyzeLine, (str, next) {
        //   return '${analyzeLine.substring(0, match!.start)}search(_response, $str)$next';
        // });

        var match = regexVarData.firstMatch(analyzeLine);
        while (match != null) {
          analyzeLine = doMatchVar(match, analyzeLine, (str, next, equal) {
            if (equal) {
              return '${analyzeLine.substring(0, match!.start)}ap_setData($str,$next)';
            } else {
              return '${analyzeLine.substring(0, match!.start)}ap_getData($str$contextKey)$next';
            }
          });
          match = regexVarData.firstMatch(analyzeLine);
        }

        // analyzeLine = _doMatchVar(match, analyzeLine, (str, next, equal) {
        //   if (equal) {
        //     return '${analyzeLine.substring(0, match!.start)}setData($str,$next)';
        //   } else {
        //     return '${analyzeLine.substring(0, match!.start)}getData($str)$next';
        //   }
        // });

        // match = regexVar.firstMatch(analyzeLine);
        // analyzeLine = _doMatchVar(match, analyzeLine, (str, next, equal) {
        //   if (equal) {
        //     return '${analyzeLine.substring(0, match!.start)}setVar($str,$next)';
        //   } else {
        //     return '${analyzeLine.substring(0, match!.start)}getVar($str)$next';
        //   }
        // });
        // match = regexVar.firstMatch(analyzeLine);
        // analyzeLine = _doMatchVar(match, analyzeLine, (str, next, equal) {
        //   if (equal) {
        //     return '${analyzeLine.substring(0, match!.start)}setVar($str,$next)';
        //   } else {
        //     return '${analyzeLine.substring(0, match!.start)}getVar($str)$next';
        //   }
        // });
        match = regexVar.firstMatch(analyzeLine);
        while (match != null) {
          analyzeLine = doMatchVar(match, analyzeLine, (str, next, equal) {
            if (equal) {
              return '${analyzeLine.substring(0, match!.start)}setVar($str,$next)';
            } else {
              return '${analyzeLine.substring(0, match!.start)}getVar($str)$next';
            }
          });
          match = regexVar.firstMatch(analyzeLine);
        }

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
    return debug.toString();
  }

  // String _doMatch(RegExpMatch? match, String analyzeLine, Function fct) {
  //   if (match != null) {
  //     var str = analyzeLine.substring(match.end);
  //     int i = 0;
  //     int idxParentese = 0;
  //     for (; i < str.length; i++) {
  //       if (str[i] == '[') idxParentese++;
  //       if (str[i] == ']') idxParentese--;
  //       if (idxParentese < 0) break;
  //     }
  //     var strin = str.substring(0, i);
  //     var next = str.substring(i + 1);

  //     analyzeLine = fct(strin, next);
  //   }
  //   return analyzeLine;
  // }

  String doMatchVar(RegExpMatch? match, String analyzeLine, Function fct) {
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

  String removeDartComments(String code) {
    final singleLine = RegExp(r'//.*?$|///.*?$', multiLine: true);
    final multiLine = RegExp(r'/\*[\s\S]*?\*/');
    return code.replaceAll(singleLine, '').replaceAll(multiLine, '');
  }

  // String _escapeQuotes(String input) {
  //   return input
  //       .replaceAll('\\', '\\\\')
  //       .replaceAll('\$', '\\\$') // échappe les antislashs d'abord
  //       .replaceAll("'", "\\'") // échappe les guillemets simples
  //       .replaceAll('"', '\\"'); // échappe les guillemets doubles
  // }

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
}
