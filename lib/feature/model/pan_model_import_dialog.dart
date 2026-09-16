import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:highlight/languages/json.dart' show json;
import 'package:jsonschema/authorization_manager.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/yaml_browser.dart';
import 'package:jsonschema/prompts/prompt_model_design.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/core/json_browser/import/json2schema_yaml.dart';
import 'package:jsonschema/core/json_browser/browse_model.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/mark_down_editor.dart';
import 'package:jsonschema/widget/tree_editor/pan_yaml_tree.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget/widget_md_doc.dart';

import '../../core/json_browser/import/swagger2prop.dart';

// ignore: must_be_immutable
class PanModelImportDialog extends StatelessWidget with WidgetHelper {
  PanModelImportDialog({super.key, required this.panYamlTree});

  PanYamlTree panYamlTree;

  // final CodeEditorConfig yamlEditorConfig;
  var promptIAtextEditingController = TextEditingController();

  late TabController tabImport;
  JsonToSchemaYaml import = JsonToSchemaYaml();

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width * 0.8;
    double height = size.height * 0.8;
    Map<String, String> info = {};

    return AlertDialog(
      title: const Text('Create model from ...'),
      content: SizedBox(
        width: width,
        height: height,

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 80,
              width: 600,
              child: Row(
                spacing: 20,
                children: [
                  Flexible(
                    child: CellEditor(
                      acces: InfoAccess(map: info, name: 'subdomain'),
                      inArray: false,
                    ),
                  ),
                  Flexible(
                    child: CellEditor(
                      acces: InfoAccess(map: info, name: 'model name'),
                      inArray: false,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _getImportTab(context)),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('Create'),
          onPressed: () async {
            if (tabImport.index == 0) {
              final ok = await fromIA(context, info);
              if (ok) {
                // ignore: use_build_context_synchronously
                Navigator.of(context).pop();
              }
            } else if (tabImport.index == 1) {
              Navigator.of(context).pop();
              fromJson(import.doImportJSON().yaml.toString(), info);
            } else if (tabImport.index == 2) {
              Navigator.of(context).pop();
              fromJsonSchema(info);
            }
          },
        ),
      ],
    );
  }

  void fromJson(
    String yaml,
    Map<String, String> info, {
    List<JsonSchemaPath>? propByPath,
  }) async {
    var modelSchemaDetail = panYamlTree.getSchema();
    CodeEditorConfig yamlEditorConfig = panYamlTree.getYamlConfig();

    await modelSchemaDetail.prepareChange();

    YamlDoc docYaml = YamlDoc();
    docYaml.load(modelSchemaDetail.modelYaml);
    docYaml.doAnalyse();

    YamlLine? domain;
    for (var element in docYaml.listRoot) {
      if (element.name?.toLowerCase() == info['subdomain']?.toLowerCase()) {
        domain = element;
        break;
      }
    }
    var domainKey = info['subdomain'] ?? 'new';
    var nameKey = info['model name'] ?? 'new';
    domain ??= docYaml.addAtEnd(domainKey, '');
    docYaml.addChild(domain, nameKey, 'model');
    var newYaml = docYaml.getDoc();
    modelSchemaDetail.modelYaml = newYaml;

    await modelSchemaDetail.saveYaml(yamlEditorConfig, true, 'norepaint');
    await bddStorage.doStoreSync();


    await BrowseSingle(
      config: BrowserConfig(),
    ).browseSync(modelSchemaDetail, false, 0);
    await bddStorage.doStoreSync();

    // save du json du model
    var newModelAttr =
        modelSchemaDetail.mapInfoByJsonPath['root>$domainKey>$nameKey'];
    var id = newModelAttr!.masterID!;
    var aPropByPath = propByPath?.first;
    newModelAttr.properties ??= {};
    newModelAttr.properties!.addAll(aPropByPath?.properties ?? {});
    var node = modelSchemaDetail.getNodeFromAttributInfo(newModelAttr);
    node?.info.action = 'U';
    await modelSchemaDetail.saveProperties();
    await bddStorage.doStoreSync();

    yamlEditorConfig = panYamlTree.getYamlConfig();
    await modelSchemaDetail.saveYaml(yamlEditorConfig, true, 'import');

    var aNewModel = ModelSchema(
      category: Category.model,
      infoManager: InfoManagerModel(typeMD: TypeMD.model),
      headerName: nameKey,
      id: id,
      refDomain: currentCompany.listModel,
    );
    aNewModel.modelYaml = yaml;
    await aNewModel.saveYaml(null, true, 'norepaint');

    if (propByPath != null) {
      // SchedulerBinding.instance.addPostFrameCallback((_) async {
      await bddStorage.doStoreSync();
      await BrowseSingle(config: BrowserConfig()).browseSync(aNewModel, false, 0);
      for (var aPropByPath in propByPath) {
        if (aPropByPath.properties.isNotEmpty) {
          String pathJson = aPropByPath.pathJson;
          if (pathJson == '<root>') {
            continue;
          }
          var p = aNewModel.mapInfoByJsonPath[pathJson];
          p?.properties ??= {};
          p?.properties!.addAll(aPropByPath.properties);
          if (p != null) {
            var node = aNewModel.getNodeFromAttributInfo(p);
            node?.info.action = 'U';
            //node?.repaint();
          }
        }
      }

      if (info['context'] != null) {
        // save du context dans le model
        var contextNode = aNewModel.getExtendedNode(cstDoc);
        var accessContext = ModelAccessorAttr(
          node: contextNode,
          schema: aNewModel,
          propName: cstDoc,
        );
        accessContext.set(info['context']!, withHistory: false);
      }

      if (aNewModel.autoSaveProperties) {
        await aNewModel.saveProperties();
        await bddStorage.doStoreSync();
      }

      SchedulerBinding.instance.addPostFrameCallback((_) {
        panYamlTree.reload();
        panYamlTree.repaint();
      });
    }
    //});
  }

  Widget _getImportTab(BuildContext ctx) {
    return WidgetTab(
      onInitController: (TabController tab) {
        tabImport = tab;
        // tab.addListener(() {});
      },
      listTab: [
        Tab(text: 'Ask gemini'),
        Tab(text: 'From Json'),
        Tab(text: 'From JsonSchema'),
      ],
      listTabCont: [
        _getAskGemini(ctx),
        _getJsonImport(import),
        _getJsonSchemaImport(),
      ],
      heightTab: 40,
    );
  }

  Widget _getJsonImport(JsonToSchemaYaml import) {
    return TextEditor(
      config: CodeEditorConfig(
        isModel: false,
        mode: json,
        getText: () {
          return '';
        },
        onChange: (String json, CodeEditorConfig config) {
          import.rawJson = json;
        },
        notifError: ValueNotifier(''),
      ),
      header: 'import json',
    );
  }

  String jsonschema = '';

  Widget _getJsonSchemaImport() {
    return TextEditor(
      config: CodeEditorConfig(
        isModel: false,
        mode: json,
        getText: () {
          return jsonschema;
        },
        onChange: (String json, CodeEditorConfig config) {
          jsonschema = json;
        },
        notifError: ValueNotifier(''),
      ),
      header: 'import json schema',
    );
  }

  Widget _getAskGemini(BuildContext context) {
    promptIAtextEditingController.text = '''
Génère moi un objet métier : 
- il doit servir à modéliser :

<REMPLIR ICI LE CONTEXTE METIER DE L'OBJET>

- avec les propriétés suivantes :

<REMPLIR LES PROPRIETES ICI>

- il doit permettre de gérer les cas d'utilisation suivants :

<REMPLIR LES CAS D'UTILISATION ICI>

- Ne dois pas générer les cas d'utilisation suivants :
<REMPLIR LES CAS D'UTILISATION A NE PAS GERER ICI>
''';

    var addModelsContextButton = ElevatedButton(
      onPressed: () async {
        doShowContextDialogForPrompt(context, (contextText) {
          insertTextAtCursor(promptIAtextEditingController, '''
voici les modèles de données externes à utiliser pour t'aider dans la modélisation:
${contextText.toString()}
''');
        });
      },
      child: const Text('Add models context'),
    );

    return Column(
      children: [
        Row(children: [addModelsContextButton]),
        Expanded(
          child: MarkDownEditor(
            editorOnly: true,
            controller: promptIAtextEditingController,
            focusNode: FocusNode(),
            context: context,
          ),
        ),
      ],
    );
  }

  void fromJsonSchema(Map<String, String> info) {
    String js = jsonschema;
    if (js.trim().isEmpty) {
      return;
    }
    JsonSchemaParser parser = JsonSchemaParser();
    var paths = parser.parse(js);
    // paths.forEach((element) {
    //   print(element);
    // });
    String treeYaml = parser.getTreeYaml(paths);
    //print('jsonschema parsed : ${treeYaml}');
    fromJson(treeYaml, info, propByPath: paths);
  }

  Future<bool> fromIA(BuildContext context, Map<String, String> info) async {
    //    final cancelToken = CancelToken();
    var text = promptIAtextEditingController.text;
    // final loadingNotifier = ValueNotifier<bool>(true);
    // final errorNotifier = ValueNotifier<String?>(null);
    // final dialogContextCompleter = Completer<BuildContext>();

    var textWithContext = promptModelDesign
        .replaceAll('{{modelname}}', info['model name']!)
        .replaceAll('{{subdomain}}', info['subdomain']!)
        .replaceAll('{{contraints}}', text);

    void doIAResponse(String response) {
      jsonschema = response;
      info['context'] = text;
      Future.delayed(Duration.zero, () {
        fromJsonSchema(info);
      });
    }

    return await doCallIA(context, textWithContext, doIAResponse);

    // Future<void> dialogFuture = showIADialog(
    //   context: context,
    //   dialogContextCompleter: dialogContextCompleter,
    //   loadingNotifier: loadingNotifier,
    //   textWithContext: textWithContext,
    //   errorNotifier: errorNotifier,
    //   cancelToken: cancelToken,
    // );

    // final dialogContext = await dialogContextCompleter.future;

    // try {
    //   final response = await callGeminiProxy(
    //     textWithContext,
    //     cancelToken: cancelToken,
    //   );
    //   final cleanedResponse = response
    //       .replaceAll(RegExp(r'```json'), '')
    //       .replaceAll(RegExp(r'```'), '');

    //   jsonschema = cleanedResponse;
    //   info['context'] = text;
    //   fromJsonSchema(info);

    //   loadingNotifier.value = false;
    //   // ignore: use_build_context_synchronously
    //   if (Navigator.of(dialogContext).canPop()) {
    //     // ignore: use_build_context_synchronously
    //     Navigator.of(dialogContext).pop();
    //   }

    //   await dialogFuture;
    //   return true;
    // } catch (e) {
    //   loadingNotifier.value = false;

    //   if (cancelToken.isCancelled) {
    //     if (Navigator.of(dialogContext).canPop()) {
    //       Navigator.of(dialogContext).pop();
    //     }
    //     await dialogFuture;
    //     return false;
    //   }

    //   errorNotifier.value = e.toString();
    //   await dialogFuture;
    //   return false;
    // } finally {
    //   loadingNotifier.dispose();
    //   errorNotifier.dispose();
    // }
  }
}

class InfoAccess extends ValueAccessor {
  InfoAccess({required this.map, required this.name});

  final Map<String, String> map;
  final String name;

  @override
  dynamic get() {
    return map[name] ?? '';
  }

  @override
  String getName() {
    return name;
  }

  @override
  bool isEditable() {
    return true;
  }

  @override
  void remove() {
    map.remove(name);
  }

  @override
  void set(value) {
    map[name] = value;
  }
}
