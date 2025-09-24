import 'package:jsonschema/core/export/export2ui.dart';
import 'package:jsonschema/feature/content/json_to_ui.dart';
import 'package:jsonschema/feature/content/state_manager.dart';

class WidgetConfigInfo {
  final String name;
  final JsonToUi json2ui;
  Function? onTapSetting;

  String? pathValue;
  String? pathData;
  String? pathTemplate;

  dynamic inArrayValue;

  WidgetConfigInfo({required this.json2ui, required this.name});

  void setPathData(String path) {
    pathData = path;
  }

  void setPathValue(String path) {
    pathValue = path;
  }
}

class InfoTemplate {
  String path;
  bool anyOf = false;
  bool isArray = false;

  InfoTemplate({required this.path});
}

mixin WidgetAnyOfHelper {
  InfoTemplate calcPathTemplate(WidgetConfigInfo info, String pathData) {
    var s = pathData.split('/');
    pathData = '';
    InfoTemplate infoTemplate = InfoTemplate(path: '');
    var stateTemplate = info.json2ui.stateMgr.stateTemplate;
    for (var i = 0; i < s.length; i++) {
      String p = s[i];
      int idx = -1;
      if (p.endsWith(']')) {
        p = p.substring(0, s[i].length - 1);
        int end = p.lastIndexOf('[');
        String idxTxt = p.substring(end + 1);
        p = p.substring(0, end);
        idx = int.parse(idxTxt);
      }
      if (p != "") {
        infoTemplate.path = '${infoTemplate.path}/$p';
        if (idx >= 0) {
          pathData = '$pathData/$p[$idx]';
        } else {
          pathData = '$pathData/$p';
        }
      }
      var stateContainer = info.json2ui.getState(pathData);
      var data = stateContainer?.jsonData;

      if (idx == -1 && data != null) {
        StateContainer? t = stateTemplate[infoTemplate.path];
        // y a t'il plusieur possibilite
        if (t is StateContainerObjectAny) {
          infoTemplate.path = _getTemplateCompliant(
            info,
            stateContainer,
            infoTemplate.path,
            data,
          );
          infoTemplate.isArray = true;
        } else {
          StateContainer? t = stateTemplate['${infoTemplate.path}[1]'];
          if (t != null) {
            infoTemplate.anyOf = true;
          }
        }
      } else if (idx >= 0 && data != null) {
        // y a t'il plusieur possibilite
        StateContainer? t = stateTemplate['${infoTemplate.path}[1]'];
        if (t != null) {
          //plusieur choix possible dans le tableau
          infoTemplate.path = _getTemplateCompliant(
            info,
            stateContainer,
            infoTemplate.path,
            data,
          );
          infoTemplate.anyOf = true;
        } else {
          infoTemplate.path = '${infoTemplate.path}[0]';
        }
      } else if (idx >= 0) {
        infoTemplate.path = '${infoTemplate.path}[0]';
      }
    }

    return infoTemplate;
  }

  void setContainerTemplate(StateContainer t, String pathTemplate) {
    //print("set on ${t.hashCode}");
    // SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
    t.currentTemplate = pathTemplate;
    // });
  }

  String _getTemplateCompliant(
    WidgetConfigInfo info,
    StateContainer? stateWidget,
    String pathTemplate,
    dynamic data,
  ) {
    var stateTemplate = info.json2ui.stateMgr.stateTemplate;
    var idxT = 0;
    while (true) {
      StateContainer? t = stateTemplate['$pathTemplate[$idxT]'];
      var jsonTemplate = t!.jsonTemplate;
      if (jsonTemplate is Map && data is Map) {
        bool ok = true;
        for (var k in data.keys) {
          if (k == cstProp) continue;
          var kt = jsonTemplate[k];
          if (kt == null) {
            ok = false;
            break;
          }
        }
        if (ok) {
          //print('found $idxT');
          pathTemplate = '$pathTemplate[$idxT]';
          if (stateWidget != null) {
            setContainerTemplate(stateWidget, pathTemplate);
          }
          break;
        }
      }

      idxT++;
    }
    return pathTemplate;
  }
}
