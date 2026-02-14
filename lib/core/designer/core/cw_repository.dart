import 'package:flutter/material.dart';
import 'package:jsonschema/core/api/call_ds_manager.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_table_row.dart';
import 'package:jsonschema/core/export/export2json_fake.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/content/state_manager.dart';
import 'package:jsonschema/start_core.dart';

class CwRepository {
  final WidgetFactory aFactory;
  final Map<String, dynamic> config;
  CallerDatasource ds = CallerDatasource();
  CwRepositorysitoryState designState = CwRepositorysitoryState();
  CwRepositorysitoryState viewerState = CwRepositorysitoryState();

  StateRepository get criteriaState =>
      aFactory.isModeDesigner()
          ? designState.criteriaState
          : viewerState.criteriaState;

  StateRepository get dataState =>
      aFactory.isModeDesigner() ? designState.dataState : viewerState.dataState;

  CwRepository({required this.config, required this.aFactory}) {
    designState.criteriaState = StateRepository(repository: this);
    designState.dataState = StateRepository(repository: this);
    viewerState.criteriaState = StateRepository(repository: this);
    viewerState.dataState = StateRepository(repository: this);
  }
}

class CwRepositorysitoryState {
  late StateRepository criteriaState;
  late StateRepository dataState;
}

class StateRepository extends StateManager {
  final CwRepository repository;
  bool isLoading = false;
  ModelSchema? schema;

  StateRepository({required this.repository});

  Future<void> init(ModelSchema schema, bool withData) async {
    this.schema = schema;
    var browserEmpty = Export2FakeJson(
      modeArray: ModeArrayEnum.anyInstance,
      mode: ModeEnum.empty,
      propMode: PropertyRequiredEnum.all
    );
    await browserEmpty.browseSync(schema, false, 0);
    dataEmpty = browserEmpty.json;

    if (withData) {
      var browserData = Export2FakeJson(
        modeArray: ModeArrayEnum.anyInstance,
        mode: ModeEnum.empty,
        propMode: PropertyRequiredEnum.all
      );
      await browserData.browseSync(schema, false, 0);
      data = browserData.json;
    }
  }

  (String, String) getPathInfo(String pathData) {
    var p = pathData.lastIndexOf('/');
    String pathContainer = pathData.substring(0, p);
    String attrName = pathData.substring(p + 1);

    if (attrName.endsWith(']')) {
      pathContainer = '$pathContainer/$attrName';
      attrName = '';
    }

    return (pathContainer, attrName);
  }

  CWInheritedRow? getRowState(BuildContext context) {
    CWInheritedRow? row =
        context.getInheritedWidgetOfExactType<CWInheritedRow>();
    return row;
  }

  (StateContainer?, String) getStateContainer(
    String pathData, {
    required BuildContext? context,
    required String? pathWidgetRepos,
    Function? onIndexChange,
  }) {
    StringBuffer curPath = StringBuffer("");
    var p = pathData.split('/');
    StateContainer? last;
    if (p.length == 1) {
      return (statesTreeData[""], "/");
    }
    last = statesTreeData[""];
    for (var i = 1; i < p.length; i++) {
      var path = p[i];
      if (path.endsWith('[]')) {
        String arrayName = path.substring(0, path.length - 2);
        var lastArray = last?.stateChild[arrayName];
        if (lastArray is StateContainerArray) {
          var last2 = lastArray.stateChild['[${lastArray.currentIndex}]'];
          if (last2 != null) {
            last = last2;
          } else {
            last = last!.stateChild['$arrayName[${lastArray.currentIndex}]'];
            curPath.write('/$arrayName[${lastArray.currentIndex}]');
          }
        } else {
          last = null;
        }
      } else {
        if (onIndexChange != null && path.endsWith(']')) {
          var startIdx = path.indexOf('[');
          String arrayName = path.substring(0, startIdx);
          var indexStr = path.substring(startIdx + 1, path.length - 1);
          var lastArray = last?.stateChild[arrayName];
          if (lastArray is StateContainerArray) {
            int idx = int.parse(indexStr);
            int oldIdx = lastArray.currentIndex;
            lastArray.currentIndex = idx;
            if (oldIdx != idx) {
              onIndexChange(idx);
              if (context != null && pathWidgetRepos != null) {
                var r = getRowState(context);
                lastArray.setIndexChanged(
                  repository,
                  idx,
                  pathWidgetRepos,
                  "$curPath/$arrayName",
                  r!.rowkey.currentState,
                );
              }
            }
          }
        }
        curPath.write('/$path');
        last = last?.stateChild[p[i]];
      }
      if (last == null) {
        break;
      }
    }
    return (last, curPath.toString());
  }

  String getDataPath(
    BuildContext context,
    String path2Json, {
    required String widgetPath,
    required bool typeListContainer,
    required bool inArray,
    required CwWidgetStateBindJson state,
  }) {
    StringBuffer pathData = StringBuffer("");
    List<String> pathJson = path2Json.split(">");
    bool nextIsTypeOf = false;
    var lastContainer = statesTreeData[""];
    Map<String, CWInheritedRow> listRowState = {};
    var r = getRowState(context);
    r != null ? listRowState[r.path] = r : null;
    r?.getAll(listRowState);

    for (var i = 1; i < pathJson.length; i++) {
      var p = pathJson[i];
      if (p == constRefOn) continue;

      if (p == constTypeAnyof) {
        nextIsTypeOf = true;
        continue;
      } else if (nextIsTypeOf) {
        nextIsTypeOf = false;
        // l'objet est uniquement le type
        continue;
      }

      if (p.endsWith('[]')) {
        if (typeListContainer && i == pathJson.length - 1) {
          // si tableau et derniere boucle on ne met pas d'index
          // on recupere le container tableau gloablement
          p = p.substring(0, p.length - 2);
        } else {
          // cas des elements Input se référant à un tableau
          String arrayName = p.substring(0, p.length - 2);
          StateContainerArray? lastArray =
              lastContainer?.stateChild[arrayName] as StateContainerArray?;
          if (lastArray != null) {
            var rowidx = lastArray.currentIndex;
            var path = "$pathData/$arrayName";
            var rowState = listRowState[path];
            if (rowState != null) {
              rowidx = rowState.rowIdx;
            } else if (repository.aFactory.isModeViewer() && !inArray) {
              // print("No row state for ${info.path} at $path");
              registerRepaintOnSelect(widgetPath, path, state);
            }
            //lastContainer = lastContainer?.stateChild['$arrayName[$rowidx]'];
            p = '$arrayName[$rowidx]';
          } else {
            // pas encore d'element dans le tableau
            //print("No StateContainerArray ${info.path} for $arrayName");
            if (repository.aFactory.isModeDesigner()) {
              // cas ou on n'a pas encore de data = 0 par defaut
              p = '$arrayName[0]';
            } else {
              var path = "$pathData/$arrayName";
              var rowState = listRowState[path];
              if (rowState == null && !inArray) {
                // print("No row state for ${info.path} at $path");
                registerRepaintOnSelect(widgetPath, path, state);
              }
              // mode viewer on met -1 pour indiquer pas d'element
              p = '$arrayName[0]';
            }
          }
        }
      }
      pathData.write('/$p');
      lastContainer = lastContainer?.stateChild[p];
    }
    return pathData.toString();
  }

  void registerRepaintOnSelect(
    String pathWidget,
    String pathData,
    CwWidgetStateBindJson state,
  ) {
    //remove all idx
    pathData = pathData.replaceAll(RegExp(r'\[\d+\]'), '[]');
    var pathDeps = listDepsContainerByPath.putIfAbsent(pathData, () => {});
    //print(' register repaint on select for $pathData on $state $pathWidget id= ${repository.hashCode}');
    pathDeps[pathWidget] = state;
  }

  void reloadDependentContainers(String pathData) {
    var p = pathData.split('/');
    var pathContainer = '';
    for (var i = 1; i < p.length; i++) {
      var path = p[i];
      if (path.endsWith(']')) {
        var startIdx = path.indexOf('[');
        String arrayName = path.substring(0, startIdx);
        var pc = '$pathContainer/$arrayName'.replaceAll(
          RegExp(r'\[\d+\]'),
          '[]',
        );

        //print(" reload dependent containers for $pc id= ${repository.hashCode}");
        List<String> listDepsToRemove = [];
        listDepsContainerByPath[pc]?.forEach((key, element) {
          //print("repaint container $key for element $element ${element.pathData} ");
          if (element.mounted) {
            element.widget.ctx.repaint();
          } else {
            listDepsToRemove.add(key);
          }
        });
        for (var key in listDepsToRemove) {
          listDepsContainerByPath[pc]?.remove(key);
        }
      }
      pathContainer += '/$path';
    }
  }
}
