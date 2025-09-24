import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/export/export2ui.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/content/pan_setting.dart';
import 'package:jsonschema/feature/content/state_manager.dart';
import 'package:jsonschema/feature/content/widget/widget_content_array.dart';
import 'package:jsonschema/feature/content/widget/widget_content_form.dart';
import 'package:jsonschema/feature/content/widget/widget_content_helper.dart';
import 'package:jsonschema/feature/content/widget/widget_content_input.dart';
import 'package:jsonschema/feature/content/widget/widget_content_object_anyof.dart';
import 'package:jsonschema/widget/widget_tab.dart';

enum WidgetType { root, form, list, input }

class WidgetTyped {
  final String name;
  final Widget widget;
  final WidgetType type;
  final dynamic content;

  String layout = 'Flow';

  WidgetTyped({
    required this.name,
    required this.content,
    required this.type,
    required this.widget,
  });
}

class JsonToUi with WidgetAnyOfHelper {
  JsonToUi({required this.state});

  BuildContext? context;
  final StateManager stateMgr = StateManager();
  final State state;
  bool haveTemplate = false;
  bool modeTemplate = false;
  ModelSchema? model;

  void loadData(dynamic data) {
    stateMgr.data = data;
    stateMgr.statesTreeData.clear();
    loadDataInContainer(data);
  }

  StateContainer? getState(String pathData) {
    var p = pathData.split('/');
    StateContainer? last;
    if (p.length == 1) {
      return stateMgr.statesTreeData[""];
    }
    last = stateMgr.statesTreeData[""];
    for (var i = 1; i < p.length; i++) {
      last = last?.stateChild[p[i]];
    }
    return last;
  }

  void addStateTreeData(String pathData, StateContainer container) {
    //print('==>> addStateTreeData $pathData ${container.hashCode}');
    var p = pathData.split('/');
    StateContainer? last;
    if (p.length == 1) {
      stateMgr.statesTreeData[""] = container;
      return;
    }
    last = stateMgr.statesTreeData[""];
    for (var i = 1; i < p.length - 1; i++) {
      last = last!.stateChild[p[i]];
    }
    last!.stateChild[p[p.length - 1]] = container;
  }

  void loadDataInContainer(dynamic json, {String pathData = ''}) {
    if (json is Map) {
      addStateTreeData(pathData, StateContainerObject()..jsonData = json);
      json.forEach((key, value) {
        final currentPath = '$pathData/$key';
        loadDataInContainer(value, pathData: currentPath);
      });
      doReloadContainer(pathData);
    } else if (json is List) {
      addStateTreeData(pathData, StateContainerArray()..jsonData = json);
      for (int i = 0; i < json.length; i++) {
        final currentPath = '$pathData[$i]';
        loadDataInContainer(json[i], pathData: currentPath);
      }
      doReloadContainer(pathData);
    } else {
      // Valeur primitive
      initInputControleur(pathData, json, 0);
    }
  }

  void doReloadContainer(String pathData) {
    var containerState = stateMgr.listContainer[pathData];
    if (containerState?.mounted ?? false) {
      // ignore: invalid_use_of_protected_member
      containerState!.setState(() {});
    }
  }

  void initInputControleur(String pathData, var json, int antiLoop) {
    if (antiLoop > 3) {
      //print("********** no visible pathData: $pathData $antiLoop");
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      try {
        var stateInput = stateMgr.listInput[pathData];
        if (stateInput?.mounted ?? false) {
          stateInput!.ctrl.text = json.toString();
          if (antiLoop > 0) {
            // print("load pathData: $pathData $antiLoop > $json");
          }
        } else {
          // print("no visible pathData: $pathData $antiLoop > $json");
          antiLoop++;

          initInputControleur(pathData, json, antiLoop);
        }
      } catch (e) {
        print("erreur pathData: $pathData => $e");
      }
    });
  }

  String replaceAllIndexes(String input) {
    return input.replaceAllMapped(RegExp(r'\[\d+\]'), (match) => '[*]');
  }

  WidgetTyped? browseJsonToWidget(
    String attrName,
    dynamic data, {
    required String path,
    required String pathData,
    required WidgetType parentType,
  }) {
    List<ConfigContainer>? layoutConfiguration =
        stateMgr.configLayout[replaceAllIndexes(path)];
    var rowTab = <WidgetTyped>[];

    if (data is Map) {
      return doObjectMap(
        data,
        path,
        pathData,
        attrName,
        parentType,
        layoutConfiguration,
        rowTab,
      );
    } else if (data is List) {
      return getObjectArray(
        data,
        path,
        pathData,
        attrName,
        layoutConfiguration,
        rowTab,
      );
    } else {
      return getObjectInput(data, path, pathData, attrName, parentType);
    }
  }

  WidgetTyped getObjectInput(
    dynamic data,
    String path,
    String pathData,
    String attrName,
    WidgetType parentType,
  ) {
    // if (parentType == WidgetType.list) {
    //   return WidgetTyped(
    //     name: attrName,
    //     content: data,
    //     type: WidgetType.input,
    //     widget: Container(
    //       decoration: BoxDecoration(
    //         border: Border.all(color: Colors.grey, width: 1),
    //       ),
    //       child: Text('$data'),
    //     ),
    //   );
    // } else {
    return WidgetTyped(
      name: attrName,
      content: data,
      type: WidgetType.input,
      widget: WidgetContentInput(
        key: ObjectKey(data), // obligatoire pour les onglets
        info:
            WidgetConfigInfo(json2ui: this, name: attrName)
              ..inArrayValue = (parentType == WidgetType.list)
              ..setPathValue(path)
              ..setPathData(pathData),
      ),
    );
    //   }
  }

  WidgetTyped? getObjectArray(
    List<dynamic> data,
    String path,
    String pathData,
    String attrName,
    List<ConfigContainer>? layoutConfiguration,
    List<WidgetTyped> rowTab,
  ) {
    var lw = <Widget>[];

    WidgetContentArray wid = WidgetContentArray(
      info:
          WidgetConfigInfo(name: attrName, json2ui: this)
            ..setPathValue(path)
            ..setPathData(pathData)
            ..onTapSetting = () async {
              // await showSettingDialog(context!, path, listContentBloc);
              // // ignore: invalid_use_of_protected_member
              // state.setState(() {
              //   // change config
              // });
            },
      children: (pathData) {
        lw.clear();
        var lwt = <WidgetTyped>[];
        for (int i = 0; i < data.length; i++) {
          var row = browseJsonToWidget(
            'row $i',
            data[i],
            path: '$path[$i]',
            pathData: pathData,
            parentType: WidgetType.list,
          );
          if (row != null) {
            lwt.add(row);
          }
        }

        for (int i = 0; i < lwt.length; i++) {
          lw.add(getArrayItem(i, lwt[i].widget, data[i], null, () {}));
        }

        return lw;
      },
      getRow: (pathData2, rowData, i, k, onDelete) {
        Widget wid;
        var pathTemplate = calcPathTemplate(
          WidgetConfigInfo(json2ui: this, name: attrName),
          pathData2,
        );
        bool anyOfItem = pathTemplate.anyOf;
        if (anyOfItem) {
          wid = WidgetContentObjectAnyOf(
            children: (pathData, data2) {
              List<WidgetTyped> listContentBloc = [];
              var wid = getTemplateObject(
                rowData,
                '$path[$i]',
                pathData,
                layoutConfiguration,
                rowTab,
                listContentBloc,
              );
              return wid;
            },
            info:
                WidgetConfigInfo(json2ui: this, name: "choise items")
                  ..inArrayValue = rowData
                  ..setPathValue('$path[$i]')
                  ..setPathData('$path[$i]'),
          );
        } else {
          var row = browseJsonToWidget(
            '$i',
            rowData,
            path: '$path[$i]',
            pathData: pathData2,
            parentType: WidgetType.list,
          );
          if (row == null) return SizedBox();
          wid = row.widget;
        }

        return getArrayItem(i, wid, rowData, k, onDelete);
      },
    );

    if (modeTemplate) {
      // charge les templates mais ne les affiche pas
      wid.children(pathData);
      lw.clear();
    }

    var widgetTyped = WidgetTyped(
      name: attrName,
      content: data,
      type: WidgetType.list,
      widget: Container(
        //key: ObjectKey(data),
        margin: EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue, width: 1),
        ),
        child: Column(children: lw),
      ),
    );

    var confLayout = layoutConfiguration?.firstWhereOrNull((element) {
      return element.name == attrName;
    });

    String layout = 'Flow';
    if (confLayout != null) {
      layout = confLayout.layout;
    }
    widgetTyped.layout = layout;
    if (layout == 'Flow') {
      addTabIn(rowTab, lw);
    } else if (layout == 'Tab') {
      rowTab.add(widgetTyped);
      return null;
    } else if (layout == 'OtherTab') {
      addTabIn(rowTab, lw);
      rowTab.add(widgetTyped);
      return null;
    }
    lw.add(wid);

    return widgetTyped;
  }

  Widget getArrayItem(
    int i,
    Widget w,
    dynamic rowData,
    Key? k,
    Function onDelete,
  ) {
    return IntrinsicHeight(
      child: Row(
        key: k,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            width: 50,
            color: Colors.blue,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    onDelete();
                  },
                  child: Icon(Icons.delete),
                ),
                Expanded(child: Center(child: Text('$i'))),
              ],
            ),
          ),
          Expanded(child: w),
        ],
      ),
    );
  }

  String cleanPath(String path) {
    var path2 = path.replaceAll('\$\$__ref__>', '');
    path2 = path2.replaceAll('\$\$__anyof__>', '');
    return path2;
  }

  WidgetTyped? doObjectMap(
    Map<dynamic, dynamic> data,
    String path,
    String pathData,
    String attrName,
    WidgetType parentType,
    List<ConfigContainer>? layoutConfiguration,
    List<WidgetTyped> rowTab,
  ) {
    if (data[cstType] != null && data[cstContent] != null) {
      // gestion des type array ou input ou any
      var listData = data[cstContent];

      if (data[cstType] == 'array' && modeTemplate) {
        stateMgr.stateTemplate[path] ??=
            StateContainerArray()..jsonTemplate = listData;
      } else if (data[cstType] == 'arrayAnyOf') {
        print("arrayAnyOf");
      } else if (data[cstType] == 'objectAnyOf') {
        return doObjectAnyOf(
          path,
          listData,
          attrName,
          pathData,
          layoutConfiguration,
          rowTab,
          data,
        );
      }

      WidgetTyped? wid = browseJsonToWidget(
        path: path,
        pathData: pathData,
        attrName,
        listData,
        parentType: parentType,
      );

      return wid;
    }

    Widget wid = getContentMap(
      attrName,
      path,
      pathData,
      data,
      layoutConfiguration,
      rowTab,
    );

    return WidgetTyped(
      name: attrName,
      content: data,
      type: WidgetType.form,
      widget: Container(
        //key: ObjectKey(data),
        margin: EdgeInsets.all(5),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade700, width: 1),
        ),
        child: wid,
      ),
    );
  }

  WidgetContentForm getContentMap(
    String attrName,
    String path,
    String pathData,
    Map<dynamic, dynamic> data,
    List<ConfigContainer>? conf,
    List<WidgetTyped> rowTab,
  ) {
    List<WidgetTyped> listContentBloc = [];
    WidgetContentForm wid = WidgetContentForm(
      info:
          WidgetConfigInfo(name: attrName, json2ui: this)
            ..setPathValue(path)
            ..setPathData(pathData)
            ..onTapSetting = () async {
              await showSettingDialog(context!, path, listContentBloc);
              // ignore: invalid_use_of_protected_member
              state.setState(() {
                // change config
              });
            },
      children: (pathDataComp) {
        listContentBloc.clear();
        return getTemplateObject(
          data,
          path,
          pathDataComp,
          conf,
          rowTab,
          listContentBloc,
        );
      },
    );

    if (modeTemplate) {
      wid.children(pathData);
    }
    return wid;
  }

  WidgetTyped doObjectAnyOf(
    String path,
    listData,
    String attrName,
    String pathData,
    List<ConfigContainer>? conf,
    List<WidgetTyped> rowTab,
    Map<dynamic, dynamic> data,
  ) {
    if (modeTemplate) {
      var replaceAll = path.replaceAll("/##__choise__##", '');
      stateMgr.stateTemplate[replaceAll] =
          StateContainerObjectAny()..jsonTemplate = listData;
    }

    WidgetContentObjectAnyOf wid = _getWidgetObjectAnyOf(
      attrName,
      path,
      pathData,
      listData,
      conf,
      rowTab,
    );

    if (modeTemplate) {
      wid.children(pathData, null);
    }

    return WidgetTyped(
      name: attrName,
      content: data,
      type: WidgetType.form,
      widget: wid,
    );
  }

  WidgetContentObjectAnyOf _getWidgetObjectAnyOf(
    String attrName,
    String path,
    String pathData,
    listData,
    List<ConfigContainer>? conf,
    List<WidgetTyped> rowTab,
  ) {
    var wid = WidgetContentObjectAnyOf(
      //key: ObjectKey(listData),
      info:
          WidgetConfigInfo(name: attrName, json2ui: this)
            ..setPathValue(path.replaceAll("/##__choise__##", ''))
            ..setPathData(pathData),
      children: (pathDataComp, data) {
        List<WidgetTyped> listContentBloc = [];
        if (data == null && modeTemplate) {
          //charge les templates
          List<Widget> ret = [];
          List listTemplate = (listData as Map).values.toList();
          var replaceAll = path.replaceAll("/##__choise__##", '');
          for (var i = 0; i < listTemplate.length; i++) {
            var r = getTemplateObject(
              listTemplate[i],
              '$replaceAll[$i]',
              pathDataComp,
              conf,
              rowTab,
              listContentBloc,
            );
            ret.addAll(r);
          }
          return ret;
        } else if (data != null) {
          return getTemplateObject(
            data,
            path,
            pathDataComp,
            conf,
            rowTab,
            listContentBloc,
          );
        } else {
          return [Text('Empty')];
        }
      },
    );
    return wid;
  }

  List<Widget> getTemplateObject(
    Map<dynamic, dynamic> data,
    String path,
    String pathData,
    List<ConfigContainer>? conf,
    List<WidgetTyped> rowTab,
    List<WidgetTyped> listContentBloc,
  ) {
    var lwt = <WidgetTyped>[];

    if (modeTemplate) {
      stateMgr.stateTemplate[path] ??=
          StateContainerObject()..jsonTemplate = data;
    }

    data.forEach((key, value) {
      //print('$tabSpace$key:');
      if (key == cstProp) {
        // gestion prop du formulaire
      } else {
        var w = browseJsonToWidget(
          key,
          value,
          path: '$path/$key',
          pathData: pathData,
          parentType: WidgetType.form,
        );
        if (w != null) {
          lwt.add(w);
        }
      }
    });

    var lw = <Widget>[];
    var rowInput = <Widget>[];
    const margeHoriz = 20.0;
    bool prevIsContainerTab = false;

    for (var i = 0; i < lwt.length; i++) {
      if (lwt[i].type != WidgetType.input) {
        // type list ou form
        var confLayout = conf?.firstWhereOrNull((element) {
          return element.name == lwt[i].name;
        });

        bool nextIsContainer = false;
        if (i < lwt.length - 1) {
          if (lwt[i + 1].type != WidgetType.input) {
            nextIsContainer = true;
          }
        }

        String layout =
            (((pathData == '' && i == 0) || !nextIsContainer) &&
                    !prevIsContainerTab)
                ? 'Flow'
                : 'Tab';
        //String layout = 'Flow';

        if (confLayout != null) {
          layout = confLayout.layout;
        }

        if (rowInput.isNotEmpty) {
          // ajouter les inputs
          lw.add(Row(spacing: margeHoriz, children: rowInput));
          rowInput = [];
        }

        lwt[i].layout = layout;
        if (layout == 'Flow') {
          addTabIn(rowTab, lw);
          lw.add(lwt[i].widget);
        } else if (layout == 'Tab') {
          rowTab.add(lwt[i]);
        } else if (layout == 'OtherTab') {
          addTabIn(rowTab, lw);
          rowTab.add(lwt[i]);
        }

        listContentBloc.add(lwt[i]);
        prevIsContainerTab = layout == 'Tab';
      } else {
        // gestion des input par 3
        prevIsContainerTab = false;
        addTabIn(rowTab, lw);
        if (rowInput.length < 4) {
          addInput(rowInput, lwt, i);
        } else {
          lw.add(Row(spacing: margeHoriz, children: rowInput));
          rowInput = [];
          addInput(rowInput, lwt, i);
        }
      }
    }
    addTabIn(rowTab, lw);
    if (rowInput.isNotEmpty) {
      // ajout la derniére ligne d'input 
      lw.add(Row(spacing: margeHoriz, children: rowInput));
      rowInput = [];
    }
    return lw;
  }

  void addInput(List<Widget> rowInput, List<WidgetTyped> lwt, int i) {
    if (rowInput.isEmpty) rowInput.add(SizedBox(height: 1));
    var widget2 = Flexible(child: lwt[i].widget);
    rowInput.add(widget2);
  }

  void addTabIn(List<WidgetTyped> rowTab, List<Widget> dest) {
    if (rowTab.isNotEmpty) {
      List<Widget> tabs = [];
      List<Widget> contents = [];

      for (var element in rowTab) {
        tabs.add(Tab(text: element.name));
        contents.add(element.widget);
      }
      dest.add(
        WidgetTab(
          //key: GlobalKey(),
          listTab: tabs,
          listTabCont: contents,
          heightTab: 30,
          heightContent: true,
        ),
      );
      rowTab.clear();
    }
  }

  // Widget getExpansible(
  //   List<Widget> headers,
  //   Widget child, {
  //   required Color color,
  // }) {
  //   final controller = ExpansibleController();
  //   controller.expand();

  //   return Expansible(
  //     //key: GlobalKey(),
  //     controller: controller,
  //     headerBuilder:
  //         (_, animation) => GestureDetector(
  //           onTap: () {
  //             controller.isExpanded
  //                 ? controller.collapse()
  //                 : controller.expand();
  //           },
  //           child: Container(
  //             //padding: EdgeInsets.symmetric(horizontal: 10),
  //             //width: double.infinity,
  //             decoration: BoxDecoration(
  //               color: color,
  //               //border: Border.all(color: Colors.white54, width: 1),
  //             ),
  //             child: Row(
  //               spacing: 10,
  //               children: [
  //                 Icon(Icons.arrow_circle_down_sharp),
  //                 ...headers,
  //                 //Spacer(),
  //               ],
  //             ),
  //           ),
  //         ),
  //     bodyBuilder:
  //         (_, animation) => FadeTransition(opacity: animation, child: child),
  //     expansibleBuilder:
  //         (_, header, body, _) => Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           mainAxisAlignment: MainAxisAlignment.start,
  //           children: [header, body],
  //         ),
  //   );
  // }

  Future<void> showSettingDialog(
    BuildContext ctx,
    String path,
    List<WidgetTyped> data,
  ) async {
    var setting = PanSetting(data: data);

    return showDialog<void>(
      context: ctx,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) {
        Size size = MediaQuery.of(ctx).size;
        double width = size.width * 0.9;
        double height = size.height * 0.8;
        return AlertDialog(
          content: SizedBox(width: width, height: height, child: setting),
          actions: [
            TextButton(
              child: const Text('change layout'),
              onPressed: () {
                Navigator.of(context).pop();
                List<ConfigContainer> confs = [];
                for (var i = 0; i < data.length; i++) {
                  confs.add(
                    ConfigContainer(
                      pos: i,
                      name: data[i].name,
                      layout: data[i].layout,
                    ),
                  );
                }
                stateMgr.configLayout[replaceAllIndexes(path)] = confs;
              },
            ),
          ],
        );
      },
    );
  }
}
