import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/yaml_browser.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/login/background_screen_login.dart';
import 'package:jsonschema/widget/login/heading_text.dart';
import 'package:jsonschema/widget/tree_editor/pan_yaml_tree.dart';
import 'package:jsonschema/widget/widget_tooltip.dart';
import 'package:jsonschema/widget/widget_dialog_card.dart';
import 'package:yaml/yaml.dart';

mixin class WidgetHelper {

Future<bool> askUser(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Question'),
        content: Text('Can you remove this item ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes'),
          ),
        ],
      );
    },
  );

  return result ?? false; // Return false if the user dismisses the dialog }
}

  void openTypeSelector(
    PanYamlTree editor,
    BuildContext context,
    List<OptionSelect> listOptions,
    NodeAttribut attr,
    GlobalKey<State<StatefulWidget>> k,
  ) {
    BuildContext? bCtx;

    dialogBuilderBelow(
      context,
      SizedBox(
        width: 110,
        height: 220,
        child: ListView(
          children:
              listOptions.map<Widget>((option) {
                return ListTile(
                  dense: true,
                  leading: Icon(option.icon, color: option.color),
                  title: Text(option.label),
                  onTap: () {
                    var aYaml = editor.getSchema().modelYaml;

                    YamlDocument doc = loadYamlDocument(aYaml);
                    YamlDoc docYaml = YamlDoc();
                    docYaml.doAnalyse(doc, aYaml);

                    for (var line in docYaml.listYamlLine) {
                      YamlLine? l = line;
                      String path = '';
                      while (l != null) {
                        if (path.isNotEmpty) {
                          path = '>$path';
                        }
                        path = '${l.name}$path';
                        l = l.parent;
                      }
                      path = 'root>$path';
                      if (attr.info.path == path) {
                        var from = RegExp(
                          attr.info.getRefName() != null
                              ? '\\\$${attr.info.getRefName()}'
                              : attr.info.type,
                        );
                        aYaml = aYaml.replaceFirst(
                          from,
                          option.label,
                          line.idxCharStart,
                        );
                        editor.updateYaml(aYaml);
                        break;
                      }
                    }
                    bCtx?.pop();
                  },
                );
              }).toList(),
        ),
      ),
      k,
      Offset(-40, -20),
      (BuildContext ctx) {
        bCtx = ctx;
      },
    );
  }

  Future<void> dialogBuilderBelow(
    BuildContext context,
    Widget child,
    GlobalKey targetKey,
    Offset? offset,
    Function getCtx,
  ) {
    return showDialog(
      context: context,
      //barrierColor: Colors.transparent, // Pour éviter le fond sombre
      builder: (context) {
        getCtx(context);
        return Stack(
          children: [
            PositionedDialogBelow(
              pos: offset ?? Offset(0, 0),
              targetKey: targetKey,
              child: AlertDialog(
                contentPadding: EdgeInsets.all(5),
                content: child,
                actions: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> dialogBuilder(BuildContext context, Widget child) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: EdgeInsets.all(5),
          content: child,
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> messageBuilder(BuildContext context, Widget child) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: EdgeInsets.all(0),
          content: SizedBox(
            height: 450,
            width: 500,
            child: Stack(
              children: [
                const BackgroundScreenLogin(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 30,
                        ),
                        child: MainHeading(title: "Information"),
                      ),
                      DialogCard(message: child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget? getHttpOpe(String name) {
    if (name == 'get') {
      return getChip(Text('GET'), color: Colors.green, height: 27);
    } else if (name == 'post') {
      return getChip(
        Text('POST', style: TextStyle(color: Colors.black)),
        color: Colors.yellow,
        height: 27,
      );
    } else if (name == 'put') {
      return getChip(Text('PUT'), color: Colors.blue, height: 27);
    } else if (name == 'patch') {
      return getChip(Text('PATCH'), color: Colors.indigoAccent, height: 27);
    } else if (name == 'delete') {
      return getChip(
        Text('DELETE', style: TextStyle(color: Colors.black)),
        color: Colors.redAccent.shade100,
        height: 27,
      );
    }
    return null;
  }

  Color? getColor(String name) {
    if (name == 'get') {
      return Colors.green;
    } else if (name == 'post') {
      return Colors.yellow;
    } else if (name == 'put') {
      return Colors.blue;
    } else if (name == 'patch') {
      return Colors.indigoAccent;
    } else if (name == 'delete') {
      return Colors.redAccent.shade100;
    }
    return null;
  }

  Widget getChip(Widget content, {required Color? color, double? height}) {
    var w = Chip(
      labelPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 5),
      color: WidgetStatePropertyAll(color),
      padding: EdgeInsets.all(0),
      label: content, // SelectionArea(child: content),
    );
    if (height != null) {
      return SizedBox(height: height, child: w);
    }
    return w;
  }

  List<Widget> getHeaderPath(String name, TextStyle? style) {
    List<String> path = name.split('/');
    List<Widget> wpath = [];
    int i = 0;
    for (var element in path) {
      bool isLast = i == path.length - 1;
      if (element.startsWith('{')) {
        String v = element.substring(1, element.length - 1);
        wpath.add(getChip(Text(v, style: style), color: null));
        if (!isLast) {
          wpath.add(Text('/', style: style));
        }
      } else {
        wpath.add(Text(element + (!isLast ? '/' : ''), style: style));
      }
      i++;
    }
    return wpath;
  }

  List<Widget> getTooltipFromAttr(AttributInfo? info) {
    List<Widget> tooltip = [];
    if (info?.properties != null) {
      for (var element in info!.properties!.entries) {
        if (!element.key.startsWith('\$\$') && !element.key.startsWith('#')) {
          tooltip.add(
            Text(
              '${element.key} = ${element.value}',
              style: TextStyle(fontSize: 15),
            ),
          );
        } else if (element.key == constMasterID) {
          // cas du master id
          tooltip.insert(
            0,
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 1),
              decoration: BoxDecoration(
                border: BoxBorder.all(color: Colors.grey, width: 1),
              ),
              child: Text(
                'id = ${element.value}',
                style: TextStyle(fontSize: 11),
              ),
            ),
          );
        }
      }
    }

    if (tooltip.isEmpty) {
      tooltip.add(Text('No information'));
    }
    return tooltip;
  }

  Widget getToolTip({
    required List<Widget> toolContent,
    required Widget child,
  }) {
    // if (true) return child;

    return AnimatedTooltip(
      content: Column(children: toolContent),
      child: child,
    );

    // return Tooltip(
    //   verticalOffset: 4,
    //   //triggerMode: TooltipTriggerMode.manual,
    //   showDuration: const Duration(milliseconds: 2500),
    //   waitDuration: const Duration(milliseconds: 500),

    //   richMessage: WidgetSpan(
    //     alignment: PlaceholderAlignment.baseline,
    //     baseline: TextBaseline.alphabetic,
    //     child: Container(
    //       padding: const EdgeInsets.all(10),
    //       constraints: const BoxConstraints(maxWidth: 500),
    //       child: Column(children: toolContent),
    //     ),
    //   ),
    //   child: child,
    // );
  }

  void addWidgetMasterId(NodeAttribut attr, List<Widget> row) {
    dynamic master = attr.info.properties?[constMasterID];
    if (master is Future) {
      row.add(
        getChip(
          FutureBuilder(
            future: attr.info.properties?[constMasterID],
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                attr.info.properties?[constMasterID] = snapshot.data.toString();
                return Text(snapshot.data.toString());
              } else {
                return Text('-');
              }
            },
          ),
          color: null,
        ),
      );
    } else {
      row.add(getChip(Text(master.toString()), color: null));
    }
  }
}

class OptionSelect {
  final String label;
  final String name;
  final IconData icon;
  final Color color;

  OptionSelect({
    required this.label,
    required this.name,
    required this.icon,
    required this.color,
  });
}

class PositionedDialogBelow extends StatelessWidget {
  final GlobalKey targetKey;
  final Widget child;
  final Offset pos;

  const PositionedDialogBelow({
    super.key,
    required this.targetKey,
    required this.child,
    required this.pos,
  });

  @override
  Widget build(BuildContext context) {
    if (targetKey.currentContext?.mounted == true) {
      final renderBox =
          targetKey.currentContext?.findRenderObject() as RenderBox?;

      if (renderBox == null) return Container();
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      return Positioned(
        left: position.dx + pos.dx,
        top: position.dy + size.height + pos.dy,
        child: child,
      );
    }
    return Container();
  }
}
