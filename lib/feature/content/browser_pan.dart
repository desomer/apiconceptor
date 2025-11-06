import 'package:jsonschema/core/export/export2ui.dart';
import 'package:jsonschema/core/json_browser.dart';


class BrowserPan {
  Map<String, PanInfoObject> mapPanByPath = {};

  bool browseAttr(PanContext ctx, String key) {
    var data = ctx.data;

    if (data is Map && data[cstType] != null && data[cstContent] != null) {
      // gestion des type array ou input ou any positionné par le Export2UI
      data = data[cstContent];
    }

    if (data is Map) {
      var ctxObj = PanContext(
        name: ctx.nameChild ?? ctx.name,
        level: ctx.level + 1,
        path: "${ctx.path}${key != '' ? '/$key' : ''}",
      )..data = data;

      var newPan = PanInfoObject(
        attrName: ctx.nameChild ?? ctx.name,
        type: 'Panel',
        level: ctx.level,
        pathDataInTemplate: ctx.path,
        dataJsonSchema: data,
      );
      mapPanByPath['${newPan.pathDataInTemplate}@${newPan.attrName}'] = newPan;
      ctx.listPanOfJson.add(newPan);

      _doObjectMap(ctxObj);
      newPan.children.addAll(ctxObj.listPanOfJson);

      if (ctx.currentForm != null) {
        // passe au form suivant car coupé par un object
        ctx.currentForm = null;
        return true;
      }
    } else if (data is List) {
      var ctxObj = PanContext(
        name: ctx.nameChild ?? ctx.name,
        level: ctx.level + 1,
        path: "${ctx.path}${key != '' ? '/$key' : ''}",
      )..data = data;

      var type = 'Array';
      if (data.length == 1 && data.first[cstProp] is AttributInfo) {
        type = 'PrimitiveArray';
        data = data.first;
      }

      var newPan = PanInfoObject(
        attrName: ctx.nameChild ?? ctx.name,
        type: type,
        level: ctx.level,
        pathDataInTemplate: ctx.path,
        dataJsonSchema: data,
      );

      ctx.listPanOfJson.add(newPan);
      mapPanByPath['${newPan.pathDataInTemplate}@${newPan.attrName}'] = newPan;

      _doObjectArray(ctxObj);
      //ctx.currentForm!.children.add(newPan);
      newPan.children.addAll(ctxObj.listPanOfJson);

      if (ctx.currentForm != null) {
        // passe au form suivant car coupé par un object
        ctx.currentForm = null;
        return true;
      }
    } else {
      addBlocIfNeeded(ctx);
      _doObjectInput(ctx);
      var newPan = PanInfoInput(
        attrName: ctx.nameChild ?? ctx.name,
        type: 'Input',
        level: ctx.level,
        pathDataInTemplate: ctx.path,
        dataJsonSchema: ctx.data,
      );
      ctx.currentForm!.children.add(newPan);
    }

    return false;
  }

  void _doObjectMap(PanContext ctx) {
    (ctx.data as Map).forEach((key, value) {
      if (key != cstProp) {
        ctx.nameChild = key;
        ctx.data = value;
        browseAttr(ctx, key);
      }
    });
  }

  void _doObjectArray(PanContext ctx) {
    int i = 0;
    for (var element in (ctx.data as List)) {
      // ajouter les lignes
      var ctxRow = PanContext(
        name: '${ctx.name}_row_$i',
        level: ctx.level,
        path: "${ctx.path}[$i]",
      )..data = element;
      i++;
      addRowIfNeeded(ctx);
      browseAttr(ctxRow, '');
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
        level: ctx.level,
        pathDataInTemplate: ctx.path,
        dataJsonSchema: ctx.data,
      );
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
        level: ctx.level,
        pathDataInTemplate: ctx.path,
        dataJsonSchema: ctx.data,
      );
      ctx.idxForm++;
      ctx.listPanOfJson.add(ctx.currentForm!);
      mapPanByPath['${ctx.currentForm!.pathDataInTemplate}@${ctx.currentForm!.attrName}'] =
          ctx.currentForm!;
    }
  }
}


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
}

class PanInfo {
  String pathDataInTemplate;
  String attrName;
  String type;
  int level;
  dynamic dataJsonSchema;
  PanInfo({
    required this.attrName,
    required this.type,
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
  });
}

class PanInfoObject extends PanInfo {
  PanInfoObject({
    required super.attrName,
    required super.type,
    required super.level,
    required super.pathDataInTemplate,
    required super.dataJsonSchema,
  });
  int nbInput = 0;
  List<PanInfo> children = [];

  // @override
  // String toString() {
  //   String levelStr = '';
  //   for (int i = 0; i < level; i++) {
  //     levelStr += '  ';
  //   }
  //   var ret = '$levelStr{name: $attrName, type: $type, nbInput: $nbInput}';

  //   for (var child in children) {
  //     if (child is PanInfoObject) {
  //       ret += '\n${child.toString()}';
  //     }
  //   }

  //   return ret;
  // }
}