import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:highlight/languages/cmake.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/ia/call_gemini_proxy.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/core/import/url2api.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/mark_down_editor.dart';
import 'package:jsonschema/widget/widget_tab.dart';

// ignore: must_be_immutable
class PanAPIImport extends StatelessWidget {
  PanAPIImport({super.key, required this.yamlEditorConfig});

  late TabController tabImport;
  final CodeEditorConfig yamlEditorConfig;

  Widget _getImportTab(Url2Api import, ModelSchema? model, BuildContext ctx) {
    return WidgetTab(
      onInitController: (TabController tab) {
        tabImport = tab;
        // tab.addListener(() {});
      },
      listTab: [
        Tab(text: 'Ask gemini'),
        Tab(text: 'From urls'),
        Tab(text: 'From Open API Swagger'),
      ],
      listTabCont: [
        _getAskGemini(ctx),
        _getURLImport(import),
        _getAttrSelector(model),
      ],
      heightTab: 40,
    );
  }

  final TextEditingController promptIAtextEditingController =
      TextEditingController(text: '');

  Widget _getAskGemini(BuildContext context) {
    promptIAtextEditingController.text = '''
- il doit permettre de gérer les cas d'utilisation suivants :

<REMPLIR LES CAS D'UTILISATION ICI>
''';

    return MarkDownEditor(
      controller: promptIAtextEditingController,
      focusNode: FocusNode(),
      context: context,
    );
  }

  // void fromJsonSchema(Map<String, String> info) {
  //   String js = jsonschema;
  //   if (js.trim().isEmpty) {
  //     return;
  //   }
  //   JsonSchemaParser parser = JsonSchemaParser();
  //   var paths = parser.parse(js);
  //   // paths.forEach((element) {
  //   //   print(element);
  //   // });
  //   String treeYaml = parser.getTreeYaml(paths);
  //   //print('jsonschema parsed : ${treeYaml}');
  //   fromJson(treeYaml, info, propByPath: paths);
  // }

  Widget _getURLImport(Url2Api import) {
    var dom = currentCompany.listDomain!.selectedAttr;
    import.raw =
        '''
        # GET /<YOUR_DOMAIN>/example/v1
        # GET /${dom?.info.name.toLowerCase()}/example/v1
        # POST /${dom?.info.name.toLowerCase()}/example/v1
        # GET /${dom?.info.name.toLowerCase()}/example/v1/{param}?field={field}
        # GET /${dom?.info.name.toLowerCase()}/example/v1/{param}?field={field}     request/body=\$model    responses/200=\$model

        GET /${dom?.info.name.toLowerCase()}/example/v1/{param}?field={field}
        ''';

    return TextEditor(
      config: CodeEditorConfig(
        isModel: false,
        mode: cmake,
        getText: () {
          return import.raw;
        },
        onChange: (String json, CodeEditorConfig config) {
          import.raw = json;
        },
        notifError: ValueNotifier(''),
      ),
      header: 'import list of urls',
    );
  }

  Widget _getAttrSelector(ModelSchema? model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        //TextButton(onPressed: () {}, child: Text("Import")),
        //  Expanded(child: WidgetModelLink(listModel: model)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Url2Api import = Url2Api();

    // ModelSchema model = ModelSchema(
    //   category: Category.selector,
    //   headerName: 'Select Models',
    //   id: 'model',
    //   infoManager: currentCompany.listModel!.infoManager,
    //   ref: currentCompany.listModel!,
    // );
    // model.autoSaveProperties = false;
    // model.mapModelYaml = currentCompany.listModel!.mapModelYaml;
    // model.modelProperties = currentCompany.listModel!.modelProperties;

    Size size = MediaQuery.of(context).size;
    double width = size.width * 0.8;
    double height = size.height * 0.8;

    return AlertDialog(
      title: const Text('Import API from ...'),
      content: SizedBox(
        width: width,
        height: height,

        child: _getImportTab(import, null, context),
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
              List<dynamic>? listRoute = await fromIA(context, import, {});
              if (listRoute == null || listRoute.isEmpty) {
                return;
              }
              var modelSchemaDetail = currentCompany.listAPI!;
              modelSchemaDetail.modelYaml = import
                  .doImportJSON(modelSchemaDetail)
                  .yaml
                  .toString();

              modelSchemaDetail.doChangeAndRepaintYaml(
                yamlEditorConfig,
                true,
                'import',
              );
              await bddStorage.doStoreSync();

              Future.delayed(Duration(seconds: 1)).then((_) async {
                var path = modelSchemaDetail.mapInfoByJsonPath;
                print('listRoute: ${listRoute.length}');
                for (var route in listRoute) {
                  var attr = path[route['pathJSON']];
                  attr?.properties ??= {};
                  attr?.properties!['summary'] = route['usage'];
                  attr?.properties!['description'] = route['description'];
                  attr?.properties!['tag'] = route['tag'];
                  var node = modelSchemaDetail.getNodeFromAttributInfo(attr!);
                  node?.info.action = 'U';
                }
                if (modelSchemaDetail.autoSaveProperties) {
                  modelSchemaDetail.saveProperties();
                }
                await bddStorage.doStoreSync();
                yamlEditorConfig.repaintTree();

                // for (var aPropByPath in propByPath) {
                //   if (aPropByPath.properties.isNotEmpty) {
                //     var p = aModel.mapInfoByJsonPath[aPropByPath.pathJson];
                //     p?.properties ??= {};
                //     p?.properties!.addAll(aPropByPath.properties);
                //   }
                // }

                // save du json du model
                // var newModel = modelSchemaDetail
                //     .mapInfoByJsonPath['root>$domainKey>$nameKey'];
                // var id = newModel!.masterID!;
                // var aModel = ModelSchema(
                //   category: Category.model,
                //   infoManager: InfoManagerModel(typeMD: TypeMD.model),
                //   headerName: nameKey,
                //   id: id,
                //   refDomain: currentCompany.listModel,
                // );
                // aModel.modelYaml = yaml;
                // aModel.doChangeAndRepaintYaml(null, true, 'import');
                // if (propByPath != null) {
                //   // aModel = ModelSchema(
                //   //   category: Category.model,
                //   //   infoManager: InfoManagerModel(typeMD: TypeMD.model),
                //   //   headerName: nameKey,
                //   //   id: id,
                //   //   refDomain: currentCompany.listModel,
                //   // );
                //   // aModel.modelYaml = yaml;
                //   BrowseSingle(config: BrowserConfig()).browse(aModel, false);

                //   Future.delayed(Duration(seconds: 1)).then((_) {
                //     for (var aPropByPath in propByPath) {
                //       if (aPropByPath.properties.isNotEmpty) {
                //         var p = aModel.mapInfoByJsonPath[aPropByPath.pathJson];
                //         p?.properties ??= {};
                //         p?.properties!.addAll(aPropByPath.properties);
                //       }
                //     }
                //   });
                //}
              });
            } else if (tabImport.index == 1) {
              var modelSchemaDetail = currentCompany.listAPI!;
              modelSchemaDetail.modelYaml = import
                  .doImportJSON(modelSchemaDetail)
                  .yaml
                  .toString();

              //stateApi.repaintListAPI();

              modelSchemaDetail.doChangeAndRepaintYaml(
                yamlEditorConfig,
                true,
                'import',
              );

              // WidgetsBinding.instance.addPostFrameCallback((_) {
              //   var newModel =
              //       modelSchemaDetail
              //           .mapInfoByJsonPath['root>$domainKey>$nameKey'];
              //   var id = newModel!.masterID!;
              //   var aModel = ModelSchemaDetail(
              //     type: YamlType.model,
              //     infoManager: InfoManagerModel(typeMD: TypeMD.model),
              //     name: nameKey,
              //     id: id,
              //   );
              //   aModel.modelYaml = yaml;
              //   aModel.doChangeYaml(null, true, 'import');
              // });
            } else if (tabImport.index == 2) {
              //doImportFromModel(model);
            }
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  // void doImportFromModel(ModelSchemaDetail model) {
  //   print(model.lastBrowser?.selectedPath);
  //   for (var sel in model.lastBrowser?.selectedPath ?? {}) {
  //     var info = model.mapInfoByJsonPath[sel];
  //     var node = (model.lastJsonBrowser as JsonBrowserWidget).findNode(info!);
  //     var data = node!.data;
  //     List<NodeAttribut> path = [];
  //     while (data != null) {
  //       path.insert(0, data);
  //       data = data.parent;
  //       if (data?.info.type == 'model') {
  //         break;
  //       }
  //     }

  //     var modelSchemaDetail = currentCompany.currentModel!;
  //     modelSchemaDetail.modelYaml = '${modelSchemaDetail.modelYaml}add';
  //     // ignore: invalid_use_of_protected_member
  //     stateModel.keyModelYamlEditor.currentState?.setState(() {});
  //     modelSchemaDetail.doChangeYaml(null, true, 'import');
  //   }
  // }

  Future<List<dynamic>?> fromIA(
    BuildContext context,
    Url2Api import,
    Map<String, String> info,
  ) async {
    final cancelToken = CancelToken();
    var text = promptIAtextEditingController.text;
    final loadingNotifier = ValueNotifier<bool>(true);
    final errorNotifier = ValueNotifier<String?>(null);
    final dialogContextCompleter = Completer<BuildContext>();

    var model = '';

    var textWithContext =
        '''
Tu es un expert en modélisation d'API REST a la norme juheapi. 
donne moi les routes API REST. 

voici le contexte et contraintes de modélisation :
$text

voici le modéle de données à utiliser pour la modélisation des routes API REST :
$model

voici les contraintes de sortie à respecter pour la modélisation des routes API REST :
- le format de sortie doit être un tableau d'objets JSON
- chaque objet JSON doit contenir les champs suivants : 
   usage : a quoi sert la route API REST 
   description : description de la route API REST
   path : chemin de la route API REST
   tag : tag de la route API REST 
   method : méthode HTTP de la route API REST (GET, POST, PUT, DELETE, PATCH)
   request usage : description de l'utilisation de la requête
   request :
      - path : chemin de la requête (ex: /users/{id})
          description : description du paramètre de la requête
          name : nom du paramètre de la requête (ex: id)
          type : type du paramètre de la requête (ex: string, integer)
          example : exemple de la valeur du paramètre de la requête
      - query : paramètres de la requête (ex: ?name=John&age=30)
          description : description du paramètre de la requête
          name : nom du paramètre de la requête (ex: name)
          type : type du paramètre de la requête (ex: string, integer)
          example : exemple de la valeur du paramètre de la requête
   responses usage : description de l'utilisation de la réponse      

Sortie attendue :
   - format de sortie de type json 
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

      // jsonschema = cleanedResponse;
      // fromJsonSchema(info);

      print('Gemini response: $cleanedResponse');
      // deserialisation de la reponse json
      List<dynamic> json = jsonDecode(cleanedResponse);
      StringBuffer sb = StringBuffer();
      for (var route in json) {
        var path = route['path'];
        var method = route['method'];
        sb.writeln('$method $path');
        //break;
      }
      import.raw = sb.toString();
      import.definitions = json;

      loadingNotifier.value = false;
      // ignore: use_build_context_synchronously
      if (Navigator.of(dialogContext).canPop()) {
        // ignore: use_build_context_synchronously
        Navigator.of(dialogContext).pop();
      }

      await dialogFuture;
      return json;
    } catch (e) {
      loadingNotifier.value = false;

      if (cancelToken.isCancelled) {
        // ignore: use_build_context_synchronously
        if (Navigator.of(dialogContext).canPop()) {
          // ignore: use_build_context_synchronously
          Navigator.of(dialogContext).pop();
        }
        await dialogFuture;
        return null;
      }

      errorNotifier.value = e.toString();
      await dialogFuture;
      return null;
    } finally {
      loadingNotifier.dispose();
      errorNotifier.dispose();
    }
  }
}
