import 'package:jsonschema/core/export/export2ui.dart';
import 'package:jsonschema/core/json_browser.dart';

class BrowserPan {
  PanContext? rootContext;
  Map<String, PanInfoObject> mapPanByPath = {};
  List<PanInfoObject> fifoPanInfo = [];
  List<String> listPathPan = []; // ['/meta/pagination', '/data[0]/attributes'];

  bool browseAttr(PanContext ctx, String key, String? subtype) {
    rootContext ??= ctx;
    var data = ctx.data;

    if (data is Map && data[cstType] != null && data[cstContent] != null) {
      // gestion des type array ou input ou any positionné par le Export2UI
      data = data[cstContent];
    }

    if (data is Map) {
      //  les objects
      var ctxObj = PanContext(
        name: ctx.nameChild ?? ctx.name,
        level: ctx.level + 1,
        path: "${ctx.path}${key != '' ? '/$key' : ''}",
      )..data = data;

      var newPan = PanInfoObject(
        attrName: ctx.nameChild ?? ctx.name,
        type: 'Panel',
        subtype: subtype ?? ctx.subtype ?? 'Panel',
        level: ctx.level,
        pathDataInTemplate: ctx.path,
        dataJsonSchema: data,
      );
      setVisibility(newPan, ctxObj.path);
      // recopie l'attribut pour le tooltip de message
      if (ctx.data[cstProp]!=null) {
        data[cstPropLabel] = ctx.data[cstProp];
      }

      mapPanByPath['${newPan.pathDataInTemplate}@${newPan.attrName}'] = newPan;
      ctx.listPanOfJson.add(newPan);

      fifoPanInfo.add(newPan);
      _doObjectMap(ctxObj);
      fifoPanInfo.removeLast();

      newPan.children.addAll(ctxObj.listPanOfJson);

      if (ctx.currentForm != null) {
        // passe au form suivant car coupé par un object
        ctx.currentForm = null;
        return true;
      }
    } else if (data is List) {
      // les listes
      var ctxObj = PanContext(
        name: ctx.nameChild ?? ctx.name,
        level: ctx.level + 1,
        path: "${ctx.path}${key != '' ? '/$key' : ''}",
      )..data = data;

      var type = 'Array';
      if (data.length == 1 && data.first[cstProp] is AttributInfo) {
        type = 'PrimitiveArray';
        data = data.first;
      } else {
        // recopie l'attribut pour le tooltip de message
        var data2 = (ctx.data as Map)[cstProp];
        if (data2!=null) {
          data.first[cstPropLabel] = data2;
        }
      }

      var newPan = PanInfoObject(
        attrName: ctx.nameChild ?? ctx.name,
        type: type,
        subtype: subtype ?? "",
        level: ctx.level,
        pathDataInTemplate: ctx.path,
        dataJsonSchema: data,
      );
      setVisibility(newPan, ctxObj.path);

      ctx.listPanOfJson.add(newPan);
      mapPanByPath['${newPan.pathDataInTemplate}@${newPan.attrName}'] = newPan;

      fifoPanInfo.add(newPan);
      _doObjectArray(newPan, ctxObj);
      fifoPanInfo.removeLast();
      newPan.children.addAll(ctxObj.listPanOfJson);

      if (ctx.currentForm != null) {
        // passe au form suivant car coupé par un object
        ctx.currentForm = null;
        return true;
      }
    } else {
      // les attributs simples
      addBlocIfNeeded(ctx);
      _doObjectInput(ctx);
      var newPan = PanInfoInput(
        attrName: ctx.nameChild ?? ctx.name,
        type: 'Input',
        subtype: '?',
        level: ctx.level,
        pathDataInTemplate: ctx.path,
        dataJsonSchema: ctx.data,
      );
      setVisibility(newPan, ctx.path);
      ctx.currentForm!.children.add(newPan);
    }

    return false;
  }

  void setVisibility(PanInfo panInfo, String path) {
    if (panInfo.subtype == 'root') {
      panInfo.pathPanVisible = 'root';
    }

    var pathAsterix = replaceAllIndexes(path);

    if (listPathPan.isNotEmpty) {
      for (var aPathEnable in listPathPan) {
        if (pathAsterix.startsWith(replaceAllIndexes(aPathEnable))) {
          panInfo.pathPanVisible = aPathEnable;
          break;
        }

        if (panInfo.type == 'Array' &&
            aPathEnable.startsWith('$pathAsterix[*]')) {
          panInfo.pathPanVisible = aPathEnable;
          break;
        }
      }
      panInfo.hasChildVisible = false;
      for (var aPathEnable in listPathPan) {
        aPathEnable = replaceAllIndexes(aPathEnable);
        if (aPathEnable.startsWith(pathAsterix)) {
          panInfo.hasChildVisible = true;
          break;
        }
      }
    } else {
      panInfo.pathPanVisible = '*';
    }
    // print(
    //   'visibility object $path ${panInfo.pathPanVisible} ${panInfo.hasChildVisible}',
    // );
  }

  void _doObjectMap(PanContext ctx) {
    (ctx.data as Map).forEach((key, value) {
      if (key != cstProp && key != cstPropLabel) {
        ctx.nameChild = key;
        ctx.data = value;
        browseAttr(ctx, key, null);
      }
    });
  }

  void _doObjectArray(PanInfoObject panArray, PanContext ctx) {
    int i = 0;
    for (var element in (ctx.data as List)) {
      // ajouter les lignes
      var ctxRow =
          PanContext(
              name:
                  (panArray.type == 'PrimitiveArray')
                      ? ctx.name
                      : '${ctx.name}_row_$i',
              level: ctx.level,
              path: "${ctx.path}[$i]",
            )
            ..data = element
            ..subtype = 'RowDetail';

      // print('path row ${ctxRow.path}');

      i++;
      addRowIfNeeded(ctx);
      browseAttr(ctxRow, '', null);
      ctx.currentForm!.children.addAll(ctxRow.listPanOfJson);
    }
  }

  void _doObjectInput(PanContext ctx) {
    ctx.currentForm!.nbInput++;
  }

  void addBlocIfNeeded(PanContext ctx) {
    if (ctx.currentForm == null) {
      ctx.currentForm = PanInfoObject(
        attrName: '${ctx.name}_${ctx.idxForm}',
        type: 'Bloc',
        subtype: '',
        level: ctx.level,
        pathDataInTemplate: ctx.path,
        dataJsonSchema: ctx.data,
      );
      setVisibility(ctx.currentForm!, ctx.path);
      ctx.idxForm++;
      ctx.listPanOfJson.add(ctx.currentForm!);
      mapPanByPath['${ctx.currentForm!.pathDataInTemplate}@${ctx.currentForm!.attrName}'] =
          ctx.currentForm!;
    }
  }

  void addRowIfNeeded(PanContext ctx) {
    if (ctx.currentForm == null) {
      ctx.currentForm = PanInfoObject(
        attrName: '${ctx.name}_${ctx.idxForm}',
        type: 'Row',
        subtype: '',
        level: ctx.level,
        pathDataInTemplate: ctx.path,
        dataJsonSchema: ctx.data,
      );
      setVisibility(ctx.currentForm!, ctx.path);
      ctx.idxForm++;
      ctx.listPanOfJson.add(ctx.currentForm!);
      mapPanByPath['${ctx.currentForm!.pathDataInTemplate}@${ctx.currentForm!.attrName}'] =
          ctx.currentForm!;
    }
  }

  String replaceAllIndexes(String input) {
    return input.replaceAllMapped(RegExp(r'\[\d+\]'), (match) => '[*]');
  }

  // String normalizePathIndices(
  //   String path, {
  //   bool replaceAll = true,
  //   String? replaceIndicesPath,
  // }) {
  //   final regex = RegExp(r'([^\.\[\]]+)(\[(\d+|\*)\])?');
  //   final buffer = StringBuffer();
  //   String currentPath = '';
  //   String currentPathWildcard = '';

  //   for (final match in regex.allMatches(path)) {
  //     final key = match.group(1)!;
  //     final hasIndex = match.group(2) != null;
  //     final index = match.group(3);

  //     if (buffer.isNotEmpty && buffer.toString()[buffer.length - 1] != ']')
  //       buffer.write('.');
  //     buffer.write(key);

  //     currentPath = currentPath.isEmpty ? key : '$currentPath.$key';
  //     currentPathWildcard =
  //         currentPathWildcard.isEmpty ? key : '$currentPathWildcard.$key';

  //     if (hasIndex) {
  //       currentPath += '[$index]';
  //       currentPathWildcard += '[*]';

  //       final shouldReplace =
  //           replaceAll ||
  //           (replaceIndicesPath != null &&
  //               (_normalizePath(
  //                 replaceIndicesPath,
  //               ).startsWith(currentPathWildcard)));

  //       buffer.write(shouldReplace ? '[*]' : '[$index]');
  //     }
  //   }

  //   return buffer.toString();
  // }

  // String _normalizePath(String path) {
  //   final regex = RegExp(r'\[(\d+)\]');
  //   return path.replaceAllMapped(regex, (_) => '[*]');
  // }
}

//-----------------------------------------------------------------
class PanContext {
  PanContext({required this.name, required this.level, required this.path});

  List<PanInfoObject> listPanOfJson = [];
  int idxForm = 0;
  PanInfoObject? currentForm;
  int level;
  String name;
  String? nameChild;
  dynamic data;
  String path;
  String? subtype;
}

class PanInfo {
  String pathDataInTemplate;
  String attrName;
  String? panName;
  String type;
  String subtype;
  bool anyChoise = false;
  int level;
  dynamic dataJsonSchema;
  String? pathPanVisible;
  bool hasChildVisible = true;

  bool get isInvisible {
    return pathPanVisible == null && !hasChildVisible;
  }

  String getPathAttrInTemplate() {
    return "$pathDataInTemplate/$attrName";
  }

  PanInfo({
    required this.attrName,
    required this.type,
    required this.subtype,
    required this.level,
    required this.pathDataInTemplate,
    required this.dataJsonSchema,
  });
}

class PanInfoInput extends PanInfo {
  PanInfoInput({
    required super.attrName,
    required super.type,
    required super.level,
    required super.pathDataInTemplate,
    required super.dataJsonSchema,
    required super.subtype,
  });
}

class PanInfoObject extends PanInfo {
  PanInfoObject({
    required super.attrName,
    required super.type,
    required super.level,
    required super.pathDataInTemplate,
    required super.dataJsonSchema,
    required super.subtype,
  });
  int nbInput = 0;
  List<PanInfo> children = [];
}
