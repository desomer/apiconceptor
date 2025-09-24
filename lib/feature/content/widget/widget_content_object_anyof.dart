import 'package:flutter/material.dart';
import 'package:jsonschema/core/export/export2ui.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/feature/content/state_manager.dart';
import 'package:jsonschema/feature/content/widget/widget_content_helper.dart';
import 'package:jsonschema/widget/widget_expansive.dart';

typedef GetChild = List<Widget> Function(String pathData, dynamic data);

class WidgetContentObjectAnyOf extends StatefulWidget {
  const WidgetContentObjectAnyOf({
    super.key,
    required this.children,
    required this.info,
  });
  final GetChild children;
  final WidgetConfigInfo info;

  @override
  State<WidgetContentObjectAnyOf> createState() =>
      _WidgetContentObjectAnyOfState();
}

class _WidgetContentObjectAnyOfState extends State<WidgetContentObjectAnyOf>
    with WidgetAnyOfHelper {
  String getPathValue() {
    var pathValue = widget.info.pathValue!.replaceAll("/##__choise__##", '');
    return pathValue;
  }

  @override
  void initState() {
    if (widget.info.inArrayValue == null) {
      //deja ajouter par l'array
      widget.info.json2ui.stateMgr.addContainer(getPathValue(), this);
    } else {
      widget.info.json2ui.stateMgr.addContainer(widget.info.pathData!, this);
    }
    super.initState();
  }

  @override
  void dispose() {
    if (widget.info.inArrayValue == null) {
      //deja ajouter par l'array
      widget.info.json2ui.stateMgr.removeContainer(getPathValue());
    } else {
      widget.info.json2ui.stateMgr.removeContainer(widget.info.pathData!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [];
    var pathValue = getPathValue();
    var dataContainer = widget.info.json2ui.getState(widget.info.pathData!);
    if (widget.info.inArrayValue == null) {
      if (dataContainer != null) {
        items = widget.children(pathValue, dataContainer.jsonData);
      } else {
        items = widget.children(pathValue, null);
        // affiche pas les template
        items.clear();
      }
    } else {
      items = widget.children(pathValue, widget.info.inArrayValue);
      //dataContainer = widget.info.json2ui.getState(widget.info.pathData!);
    }

    var name = widget.info.name;
    if (name == '##__choise__##') {
      name = 'choise object';
    }

    var pathTemplate = calcPathTemplate(widget.info, widget.info.pathData!);
    String choiseName = pathTemplate.path;
    Widget? choiseWidget;

    if (dataContainer != null) {
      // recherche le nom d'un template
      dataContainer.currentTemplate = pathTemplate.path;
      widget.info.pathTemplate = pathTemplate.path;
      var template = widget.info.json2ui.stateMgr.stateTemplate[pathTemplate.path];
      AttributInfo? attributInfo = template?.jsonTemplate[cstProp];
      if (attributInfo != null) {
        choiseName = attributInfo.name;
      }
      // recherche des listes des template possible
      List<AttributInfo> listTemplate = [];

      var pathChoise = pathTemplate.path;
      var i = pathChoise.lastIndexOf('[');
      pathChoise = pathChoise.substring(0, i);
      var stateTemplate = widget.info.json2ui.stateMgr.stateTemplate;
      int idxT = 0;
      while (true) {
        StateContainer? t = stateTemplate['$pathChoise[$idxT]'];
        if (t == null) break;
        AttributInfo? attributInfo = t.jsonTemplate[cstProp];
        if (attributInfo != null) {
          listTemplate.add(attributInfo);
        }
        idxT++;
      }

      List<ButtonSegment<String>> fruits = [];

      for (var element in listTemplate) {
        var name = element.name;
        fruits.add(ButtonSegment(value: name, label: Text(name)));
      }

      Set<String> selected = {choiseName};

      choiseWidget = SizedBox(
        height: 30,
        child: SegmentedButton<String>(
          segments: fruits,
          selected: selected,
          onSelectionChanged: (newSelection) {
            setState(() {
              selected = newSelection;
            });
          },
          multiSelectionEnabled: false,
          showSelectedIcon: true,
          style: ButtonStyle(
            alignment: Alignment.topCenter,
            padding: WidgetStateProperty.all(
              EdgeInsets.fromLTRB(10, 12, 10, 0)
            ),
            backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white; // Couleur quand sélectionné
              }
              return Colors.orangeAccent; // Couleur par défaut
            }),
            foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.orange; // Texte quand sélectionné
              }
              return Colors.white; // Texte par défaut
            }),
          ),
        ),
      );
    }

    return WidgetExpansive(
      color: Colors.orange,
      headers: [
        Text(name),
        const SizedBox(width: 20),
        choiseWidget ?? const Text(""),
        const Spacer(),
        InkWell(
          onTap: () async {
            if (widget.info.onTapSetting != null) {
              widget.info.onTapSetting!();
            }
          },
          child: const Icon(Icons.tune), //settings
        ),
      ],

      child: Column(
        // change en fonction du path du template (type de template)
        key: ValueKey(pathTemplate),
        spacing: 5,
        mainAxisSize: MainAxisSize.max,
        children: [...items, const SizedBox(height: 1)],
      ),
    );
  }
}
