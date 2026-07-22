import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:highlight/languages/json.dart' show json;
import 'package:jsonschema/authorization_manager.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/ia/call_gemini.dart';
import 'package:jsonschema/core/ia/call_gemini_proxy.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/yaml_browser.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/core/import/json2schema_yaml.dart';
import 'package:jsonschema/core/json_browser/browse_model.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/mark_down_editor.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget/widget_md_doc.dart';

import '../../core/import/swagger2prop.dart';

// ignore: must_be_immutable
class PanModelImportDialog extends StatelessWidget {
  PanModelImportDialog({super.key, required this.yamlEditorConfig});

  final CodeEditorConfig yamlEditorConfig;
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
              fromJson(import.doImportJSON().yaml.toString(), info);
              Navigator.of(context).pop();
            } else if (tabImport.index == 2) {
              fromJsonSchema(info);
              Navigator.of(context).pop();
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
    var modelSchemaDetail = currentCompany.listModel!;
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
    modelSchemaDetail.doChangeAndRepaintYaml(yamlEditorConfig, true, 'import');
    await bddStorage.doStoreSync();

    Future.delayed(Duration(seconds: 1)).then((_) async {
      await bddStorage.doStoreSync();
      // save du json du model
      var newModel =
          modelSchemaDetail.mapInfoByJsonPath['root>$domainKey>$nameKey'];
      var id = newModel!.masterID!;
      var aModel = ModelSchema(
        category: Category.model,
        infoManager: InfoManagerModel(typeMD: TypeMD.model),
        headerName: nameKey,
        id: id,
        refDomain: currentCompany.listModel,
      );
      aModel.modelYaml = yaml;
      aModel.doChangeAndRepaintYaml(null, true, 'import');
      if (propByPath != null) {
        // aModel = ModelSchema(
        //   category: Category.model,
        //   infoManager: InfoManagerModel(typeMD: TypeMD.model),
        //   headerName: nameKey,
        //   id: id,
        //   refDomain: currentCompany.listModel,
        // );
        // aModel.modelYaml = yaml;
        BrowseSingle(config: BrowserConfig()).browse(aModel, false);

        Future.delayed(Duration(seconds: 1)).then((_) {
          for (var aPropByPath in propByPath) {
            if (aPropByPath.properties.isNotEmpty) {
              var p = aModel.mapInfoByJsonPath[aPropByPath.pathJson];
              p?.properties ??= {};
              p?.properties!.addAll(aPropByPath.properties);
              var node = aModel.getNodeFromAttributInfo(p!);
              node?.info.action = 'U';
              //node?.repaint();
            }
          }
          if (aModel.autoSaveProperties) {
            aModel.saveProperties();
          }
        });
      }
    });
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
''';

    return MarkDownEditor(
      controller: promptIAtextEditingController,
      focusNode: FocusNode(),
      context: context,
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
    final cancelToken = CancelToken();
    var text = promptIAtextEditingController.text;
    final loadingNotifier = ValueNotifier<bool>(true);
    final errorNotifier = ValueNotifier<String?>(null);
    final dialogContextCompleter = Completer<BuildContext>();

    var textWithContext =
        '''
Tu es un expert en modélisation de données (dataSteward). 
donne moi un jsonschemas (version draft = "2020-12") complet pour modéliser un ${info['model name']} du domaine ${info['subdomain']}.
donne un title, description et un example (si interresant) et pattern (si interessant) pour chaque attribut

voici le contexte et contraintes de modélisation :
$text

utilise, de préférence, ce catalogue de notion pour nommer les propriétés (d'autres sont acceptables si nouvelle notion) :
- id : identifiant unique, type string, format uuid
- name : nom de l'objet
- description : description de l'objet

Sortie attendue :
   - format de sortie de type jsonschemas 
   - sortie le json uniquement (pas de blabla, pas d'explication, pas de texte, pas de code block)
''';

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
                  const Text('Prompt envoye :'),
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

    final dialogContext = await dialogContextCompleter.future;

    try {
      final response = await callGeminiProxy(
        textWithContext,
        cancelToken: cancelToken,
      );
      final cleanedResponse = response
          .replaceAll(RegExp(r'```json'), '')
          .replaceAll(RegExp(r'```'), '');

      jsonschema = cleanedResponse;
      fromJsonSchema(info);

      loadingNotifier.value = false;
      if (Navigator.of(dialogContext).canPop()) {
        Navigator.of(dialogContext).pop();
      }

      await dialogFuture;
      return true;
    } catch (e) {
      loadingNotifier.value = false;

      if (cancelToken.isCancelled) {
        if (Navigator.of(dialogContext).canPop()) {
          Navigator.of(dialogContext).pop();
        }
        await dialogFuture;
        return false;
      }

      errorNotifier.value = e.toString();
      await dialogFuture;
      return false;
    } finally {
      loadingNotifier.dispose();
      errorNotifier.dispose();
    }
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
