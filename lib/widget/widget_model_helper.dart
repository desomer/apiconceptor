import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:jsonschema/core/ia/call_gemini_proxy.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/yaml_browser.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/editor/mark_down_editor.dart';
import 'package:jsonschema/widget/login/background_screen_login.dart';
import 'package:jsonschema/widget/login/heading_text.dart';
import 'package:jsonschema/widget/tree_editor/pan_yaml_tree.dart';
import 'package:jsonschema/widget/widget_tooltip.dart';
import 'package:jsonschema/widget/widget_dialog_card.dart';

mixin class WidgetHelper {

  Future<bool> askUser(
    BuildContext context,
    String title,
    String message,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    return result ?? false; // Return false if the user dismisses the dialog }
  }

  String replaceLast(String source, String from, String to) {
    final index = source.lastIndexOf(from);
    if (index == -1) return source;

    return source.substring(0, index) +
        to +
        source.substring(index + from.length);
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
          children: listOptions.map<Widget>((option) {
            return ListTile(
              dense: true,
              leading: Icon(option.icon, color: option.color),
              title: Text(option.label),
              onTap: () {
                var path2 = attr.info.path;
                path2 = path2.replaceAll("$constTypeAnyof>", "");

                var aYaml = editor.getSchema().modelYaml;

                YamlDoc docYaml = YamlDoc();
                docYaml.load(aYaml);
                docYaml.doAnalyse();

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
                  if (path2 == path) {
                    var from = RegExp(
                      attr.info.getRefName() != null
                          ? '\\\$${attr.info.getRefName()}'
                          : attr.info.type,
                    );
                    aYaml = aYaml.replaceFirst(
                      from,
                      option.label,
                      aYaml.indexOf(":", line.idxCharStart),
                    );
                    editor.updateYaml(aYaml);
                    break;
                  }
                }
                bCtx?.pop();

                // raffraichir l'éditeur d'attribut
                SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
                  // ignore: invalid_use_of_protected_member
                  editor.keyAttrEditor.currentState?.setState(() {});
                });
              },
            );
          }).toList(),
        ),
      ),
      k,
      const Offset(-40, -20),
      (BuildContext ctx) {
        bCtx = ctx;
      },
    );
  }

  Widget readOnlyCapable(bool isReadOnly, Widget child) {
    if (isReadOnly) {
      return Banner(
        message: 'Read only',
        location: BannerLocation.topEnd,
        color: Colors.deepOrangeAccent,
        child: child,
      );
    } else {
      return child;
    }
  }

  Future<void> dialogBuilderBelow(
    BuildContext context,
    Widget child,
    GlobalKey targetKey,
    Offset? offset,
    Function getCtx, {
    double hpopup = 250,
  }) {
    return showDialog(
      context: context,
      //barrierColor: Colors.transparent, // Pour éviter le fond sombre
      builder: (context) {
        getCtx(context);
        return Stack(
          children: [
            PositionedDialogBelow(
              hpopup: hpopup,
              pos: offset ?? const Offset(0, 0),
              targetKey: targetKey,
              child: AlertDialog(
                contentPadding: const EdgeInsets.all(5),
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
          contentPadding: const EdgeInsets.all(5),
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
          contentPadding: const EdgeInsets.all(0),
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
    const fontSize = 13.0;

    if (name == 'get') {
      return getChip(
        Text('GET', style: const TextStyle(fontSize: fontSize)),
        color: Colors.green.withAlpha(200),
        height: 27,
      );
    } else if (name == 'post') {
      return getChip(
        Text(
          'POST',
          style: const TextStyle(color: Colors.black, fontSize: fontSize),
        ),
        color: Colors.yellow.withAlpha(200),
        height: 27,
      );
    } else if (name == 'put') {
      return getChip(
        Text('PUT', style: const TextStyle(fontSize: fontSize)),
        color: Colors.blue.withAlpha(200),
        height: 27,
      );
    } else if (name == 'patch') {
      return getChip(
        Text('PATCH', style: const TextStyle(fontSize: fontSize)),
        color: Colors.indigoAccent.withAlpha(200),
        height: 27,
      );
    } else if (name == 'delete') {
      return getChip(
        Text(
          'DELETE',
          style: const TextStyle(color: Colors.black, fontSize: fontSize),
        ),
        color: Colors.redAccent.shade100.withAlpha(200),
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
    var w = Container(
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueGrey, width: 1),
      ),
      child: Center(child: content), // SelectionArea(child: content),
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

  Widget? getWidgetPropForTooltip(String key, value) {
    return Text('$key = $value', style: TextStyle(fontSize: 15));
  }

  List<Widget> getTooltipFromAttr(
    AttributInfo? info,
    ModelSchema? schema,
    Widget? Function(String key, dynamic value) getWidgetPropForTooltip,
  ) {
    if (info?.treePosition == null &&
        schema != null &&
        schema.qualityInfo != null) {
      List<Widget> reco = [];
      for (var recommandation in schema.qualityInfo!.recommandation) {
        reco.add(Text(recommandation, style: TextStyle(fontSize: 15)));
      }

      // cas de la root ligne
      return reco;
    }

    List<Widget> tooltip = [];
    if (info?.properties != null) {
      for (var element in info!.properties!.entries) {
        if (!element.key.startsWith('\$\$') && !element.key.startsWith('#')) {
          var widgetFromProp = getWidgetPropForTooltip(
            element.key,
            element.value,
          );
          if (widgetFromProp != null) {
            tooltip.add(widgetFromProp);
          }
        } else if (element.key == constMasterID) {
          // cas du master id
          tooltip.insert(
            0,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
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
      tooltip.add(const Text('No information'));
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

  Future<bool> doCallIA(
    BuildContext context,
    String prompt,
    Function doIAResponse,
  ) async {
    CancelToken cancelToken = CancelToken();
    final loadingNotifier = ValueNotifier<bool>(true);
    final errorNotifier = ValueNotifier<String?>(null);
    final dialogContextCompleter = Completer<BuildContext>();

    Future<void> dialogFuture = _showPromptDialog(
      context: context,
      dialogContextCompleter: dialogContextCompleter,
      loadingNotifier: loadingNotifier,
      textWithContext: prompt,
      errorNotifier: errorNotifier,
      cancelToken: cancelToken,
    );

    final dialogContext = await dialogContextCompleter.future;

    try {
      final response = await callGeminiProxy(prompt, cancelToken: cancelToken);
      // retire le ```json  si present
      final cleanedResponse = response
          .replaceAll(RegExp(r'```json'), '')
          .replaceAll(RegExp(r'```'), '');

      print('Gemini response: $cleanedResponse');

      doIAResponse(cleanedResponse);

      loadingNotifier.value = false;
      // ignore: use_build_context_synchronously
      if (Navigator.of(dialogContext).canPop()) {
        // ignore: use_build_context_synchronously
        Navigator.of(dialogContext).pop();
      }

      await dialogFuture;
      return true;
    } catch (e) {
      print('Gemini request failed: $e');
      loadingNotifier.value = false;

      if (cancelToken.isCancelled) {
        // ignore: use_build_context_synchronously
        // if (Navigator.of(dialogContext).canPop()) {
        //   // ignore: use_build_context_synchronously
        //   Navigator.of(dialogContext).pop();
        // }
        return false;
      }

      errorNotifier.value = e.toString();
      await dialogFuture; // attente du close
      return false;
    } finally {
      loadingNotifier.dispose();
      errorNotifier.dispose();
    }
  }

  Future<void> _showPromptDialog({
    required BuildContext context,
    required Completer<BuildContext> dialogContextCompleter,
    required ValueNotifier<bool> loadingNotifier,
    required String textWithContext,
    required ValueNotifier<String?> errorNotifier,
    required CancelToken cancelToken,
  }) {
    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        if (!dialogContextCompleter.isCompleted) {
          dialogContextCompleter.complete(dialogContext);
        }

        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Attente reponse Gemini'),
            content: SizedBox(
              width: 700,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: loadingNotifier,
                    builder: (ctx, isLoading, _) {
                      return Row(
                        children: [
                          if (isLoading) ...[
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Text(
                              isLoading
                                  ? 'Generation en cours...'
                                  : 'La generation a echoue.',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Prompt :'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 220),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(textWithContext),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<String?>(
                    valueListenable: errorNotifier,
                    builder: (ctx, error, _) {
                      if (error == null || error.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade300),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Erreur Gemini: $error',
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              ValueListenableBuilder<bool>(
                valueListenable: loadingNotifier,
                builder: (ctx, isLoading, _) {
                  return TextButton(
                    onPressed: () {
                      if (isLoading && !cancelToken.isCancelled) {
                        cancelToken.cancel('cancelled by user');
                      }
                      Navigator.of(dialogContext).pop();
                    },
                    child: Text(isLoading ? 'Annuler' : 'Fermer'),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
    return dialogFuture;
  }

  void doShowContextDialog(ModelAccessorAttr ma, BuildContext context) {
    // Implement the logic to show the context dialog here

    var width = MediaQuery.of(context).size.width * 0.8;
    var height = MediaQuery.of(context).size.height * 0.8;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        var textEditingController = TextEditingController(
          text: ma.get()?.toString() ?? '',
        );
        return AlertDialog(
          title: const Text('Add Features Context'),
          content: SizedBox(
            width: width,
            height: height,
            child: MarkDownEditor(
              controller: textEditingController,
              focusNode: FocusNode(),
              context: context,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the dialog
              },
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                ma.set(textEditingController.text, withHistory: true);
                Navigator.of(dialogContext).pop(); // Close the dialog
              },
              child: const Text('Save context'),
            ),
          ],
        );
      },
    );
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
  final double hpopup;

  const PositionedDialogBelow({
    super.key,
    required this.targetKey,
    required this.child,
    required this.pos,
    required this.hpopup,
  });

  @override
  Widget build(BuildContext context) {
    if (targetKey.currentContext?.mounted == true) {
      final renderBox =
          targetKey.currentContext?.findRenderObject() as RenderBox?;

      if (renderBox == null) return Container();
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      var t = position.dy + size.height + pos.dy;

      bool noPlaceOnBelow = t + hpopup > MediaQuery.of(context).size.height;
      if (noPlaceOnBelow) {
        t = t - hpopup;
      }

      return Positioned(left: position.dx + pos.dx, top: t, child: child);
    }
    return Container();
  }
}
