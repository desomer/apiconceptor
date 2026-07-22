import 'dart:convert' show json;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/authorization_manager.dart';
import 'package:jsonschema/core/ia/call_gemini.dart';
import 'package:jsonschema/core/ia/call_gemini_proxy.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/documentation/documentation_options.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/editor/mark_down_editor.dart';
import 'package:jsonschema/widget/tree_editor/pan_yaml_tree.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_show_error.dart';
import 'package:jsonschema/widget/widget_tab.dart';

class PanModelMethodsRules extends StatefulWidget {
  const PanModelMethodsRules({super.key});

  @override
  State<PanModelMethodsRules> createState() => _PanModelMethodsRulesState();
}

/*
| Catégorie | Rôle |
| --- | --- |
| **Invariants behaviors** | Vérifier les invariants |
| **State‑changing behaviors** | Modifier l’état de l’entité |
| **Query behaviors** | Lire l’état |
| **Policy Service** | Appliquer des règles complexes aux agrégats ou inter‑agrégats |
| **Factory behaviors** | Créer des entités valides |
| **Domain event behaviors** | Publier des événements |


*/

class _PanModelMethodsRulesState extends State<PanModelMethodsRules> {
  @override
  Widget build(BuildContext context) {
    return PanBehavior(
      getSchemaFct: () async {
        return await loadBehaviour(
          currentCompany.currentModel!.namespace!,
          currentCompany.currentModel!.id,
          true,
        );
      },
    );
  }
}

// ignore: must_be_immutable
class PanBehavior extends PanYamlTree {
  PanBehavior({super.key, required super.getSchemaFct});

  @override
  Widget getToolTip({
    required List<Widget> toolContent,
    required Widget child,
  }) {
    return child;
  }

  @override
  double getHeaderSize(NodeAttribut node) {
    double wIcon = 30;
    double marge = 10;
    //double dropBox = 30;

    double sizeType = 0;
    // wIcon + node.info.type.length * 8 * (zoom.value / 100) + dropBox;
    double size =
        marge +
        wIcon +
        (node.info.name.length * 8 * (zoom.value / 100)) +
        (node.level *
            ((node.info.widgetRowState as TreeViewState).indent.indent)) +
        sizeType;
    return size;
  }

  ValueNotifier<double> refresh = ValueNotifier<double>(0);

  void initEditor(TextEditingController controller, String propName) {
    var modelAccessorAttr = ModelAccessorAttr(
      node: getSchema().selectedAttr!,
      schema: getSchema(),
      propName: propName,
    );
    controller.addListener(() {
      var text = controller.text;
      modelAccessorAttr.set(text, withHistory: true);
    });
    controller.text = modelAccessorAttr.get()?.toString() ?? '';
  }

  @override
  Widget? getBottomWidget(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: refresh,
      builder: (context, value, child) {
        if (getSchema().selectedAttr == null) {
          return const Center(child: Text("Select a set of features to edit"));
        }

        ControleurBehaviors controleurBehaviors = ControleurBehaviors();
        (getSchema().infoManager as InfoManagerBehaviors).controleurBehaviors = controleurBehaviors;


        initEditor(controleurBehaviors.controllerInvariant, 'invariantsBehaviors');
        initEditor(controleurBehaviors.controllerStateChanging, 'stateChangingBehaviors');
        initEditor(controleurBehaviors.controllerQuery, 'queryBehaviors');
        initEditor(controleurBehaviors.controllerPolicy, 'policyBehaviors');
        initEditor(controleurBehaviors.controllerFactory, 'factoryBehaviors');
        initEditor(controleurBehaviors.controllerDomainEvent, 'domainEventBehaviors');
        initEditor(controleurBehaviors.controllerPersistencePolicy, 'persistencePolicy');

        return WidgetTab(
          listTab: [
            Tab(text: "Invariants"),
            Tab(text: "State changing"),
            Tab(text: "Query"),
            Tab(text: "Policy Services"),
            Tab(text: "Factory"),
            Tab(text: "Domain events"),
            Tab(text: "Persistence policy"),
          ],
          listTabCont: [
            MarkDownEditor(
              controller: controleurBehaviors.controllerInvariant,
              focusNode: FocusNode(),
              context: context,
            ),
            MarkDownEditor(
              controller: controleurBehaviors.controllerStateChanging,
              focusNode: FocusNode(),
              context: context,
            ),
            MarkDownEditor(
              controller: controleurBehaviors.controllerQuery,
              focusNode: FocusNode(),
              context: context,
            ),
            MarkDownEditor(
              controller: controleurBehaviors.controllerPolicy,
              focusNode: FocusNode(),
              context: context,
            ),
            MarkDownEditor(
              controller: controleurBehaviors.controllerFactory,
              focusNode: FocusNode(),
              context: context,
            ),
            MarkDownEditor(
              controller: controleurBehaviors.controllerDomainEvent,
              focusNode: FocusNode(),
              context: context,
            ),
            MarkDownEditor(
              controller: controleurBehaviors.controllerPersistencePolicy,
              focusNode: FocusNode(),
              context: context,
            ),
          ],
          heightTab: 30,
        ); // Replace with your actual widget
      },
    );
  }

  @override
  Future<void> onActionRow(
    TreeNodeData<NodeAttribut> node,
    BuildContext context,
  ) {
    print("onActionRow node = ${node.data.info.name}");
    refresh.value++;
    return super.onActionRow(node, context);
  }

  @override
  void addRowWidget(
    TreeNodeData<NodeAttribut> node,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    schema.infoManager.addRowWidget(node.data, schema, row, context);
  }
}

Future<ModelSchema> loadBehaviour(
  String idDomain,
  String idModel,
  bool cache,
) async {
  var schema = ModelSchema(
    category: Category.behavior,
    headerName: "set of features",
    id: '$idModel/behaviors',
    infoManager: InfoManagerBehaviors(),
    refDomain: null,
  );
  schema.namespace = idDomain;

  if (withBdd) {
    try {
      await schema.loadYamlAndProperties(cache: cache, withProperties: true);
    } on Exception catch (e) {
      print("$e");
      startError.add("$e");
    }
  }
  schema.namespace = idDomain;
  schema.isReadOnlyModel = isProfilAdmin() == false;
  return schema;
}

class ControleurBehaviors {
  TextEditingController controllerInvariant = TextEditingController();
  TextEditingController controllerStateChanging = TextEditingController();
  TextEditingController controllerQuery = TextEditingController();
  TextEditingController controllerPolicy = TextEditingController();
  TextEditingController controllerFactory = TextEditingController();
  TextEditingController controllerDomainEvent = TextEditingController();
  TextEditingController controllerPersistencePolicy = TextEditingController();
}

class InfoManagerBehaviors extends InfoManager with WidgetHelper {
  ControleurBehaviors? controleurBehaviors;

  Future<void> _showGeminiWaitingDialog(
    BuildContext context, {
    required VoidCallback onCancel,
    required ValueChanged<BuildContext> onDialogContext,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        onDialogContext(dialogContext);
        return AlertDialog(
          title: const Text('Gemini request'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Please wait while Gemini is generating the response...'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onCancel();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  void addRowWidget(
    NodeAttribut attr,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    var isRoot = attr.info.type == 'root';
    if (isRoot) return;

    row.add(
      ElevatedButton(
        onPressed: () async {
          DocumentationInfo info = DocumentationInfo();
          info.showExampleAvro = false;
          info.showExampleDto = false;
          info.showExampleMongoose = false;

          var modelDesc = DocumentationOptions(
            info: info,
            context: context,
          ).getModelDocumentation("");

          String prompt =
              '''
donne moi la liste des 
- Invariants behaviors (et Méthodes internes associées), 
- State‑changing behaviors (et Méthodes internes associées)
- Query behaviors (et Méthodes internes associées)
- Policy Service (et Méthodes internes associées)
- Factory behaviors (et Méthodes internes associées)
- Domain event behaviors (et Méthodes internes associées)
pour le modèle suivant :

$modelDesc

contraintes de sortie :
- format de sortie de type json avec les clés suivantes : "invariant_behaviors", "state_changing_behaviors", "query_behaviors", "policy_service_behaviors", "factory_behaviors", "domain_event_behaviors"
- pour invariant_behaviors : avoir une liste de controles invariant en fonction des attribut du modeles
    - validateXXX()
- pour state_changing_behaviors : avoir une liste de methodes qui modifie l'etat du modele
    - avec la règle de changement d'état
- pour query_behaviors : avoir une liste de methodes qui retourne les états, les calculs et les donnees dérivées sur le modele
    - isXXX(), canXXX(), getXXX(), computeXXX()
- pour policy_service_behaviors : avoir une liste de methodes qui applique des règles complexes aux agrégats ou inter‑agrégats
- pour factory_behaviors : avoir une liste de methodes qui crée des entités valides
    - createXXX(), fromSnapshot(rawData)
- pour domain_event_behaviors : avoir une liste de methodes qui publie des événements
    - publishXXX(), onXXX() 

- chaque clé contient une liste d'objets avec les clés suivantes : 
    {
      "behavior": "nom du behavior",
      "rules": ["liste des règles associées"],
      "associated_internal_methods": [
        "method(param1, param2, ...)",
      ]
    }
- sortie le json uniquement
''';
          CancelToken cancelToken = CancelToken();
          BuildContext? dialogContext;

          void closeWaitingDialog() {
            final ctx = dialogContext;
            if (ctx != null && Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop();
            }
          }

          _showGeminiWaitingDialog(
            context,
            onCancel: () {
              cancelToken.cancel('User cancelled the Gemini request');
              closeWaitingDialog();
            },
            onDialogContext: (ctx) {
              dialogContext = ctx;
            },
          );

          try {
            final response = await callGeminiProxy(prompt, cancelToken: cancelToken);
            // retire le ```json  si present
            final cleanedResponse = response
                .replaceAll(RegExp(r'```json'), '')
                .replaceAll(RegExp(r'```'), '');

            final decoded = json.decode(cleanedResponse);
            var behaviorsModel = BehaviorsModel.fromJson(decoded);

            StringBuffer buffer = StringBuffer();

            behaviorsModel.writeSection(
              buffer,
              behaviorsModel.invariantBehaviors,
            );
            controleurBehaviors?.controllerInvariant.text = buffer.toString();
            buffer.clear();

            behaviorsModel.writeSection(
              buffer,
              behaviorsModel.stateChangingBehaviors,
            );
            controleurBehaviors?.controllerStateChanging.text = buffer
                .toString();
            buffer.clear();

            behaviorsModel.writeSection(buffer, behaviorsModel.queryBehaviors);
            controleurBehaviors?.controllerQuery.text = buffer.toString();
            buffer.clear();

            behaviorsModel.writeSection(
              buffer,
              behaviorsModel.policyServiceBehaviors,
            );
            controleurBehaviors?.controllerPolicy.text = buffer.toString();
            buffer.clear();

            behaviorsModel.writeSection(
              buffer,
              behaviorsModel.factoryBehaviors,
            );
            controleurBehaviors?.controllerFactory.text = buffer.toString();
            buffer.clear();

            behaviorsModel.writeSection(
              buffer,
              behaviorsModel.domainEventBehaviors,
            );
            controleurBehaviors?.controllerDomainEvent.text = buffer.toString();
            buffer.clear();

            print('Generated Markdown:\n${buffer.toString()}');

            closeWaitingDialog();
            print('Gemini response: $response');
          } catch (e) {
            closeWaitingDialog();
            print('Gemini request failed: $e');
          }
        },
        child: Text('Ask Gemini for behaviors'),
      ),
    );
    // row.add(
    //   ElevatedButton(
    //     onPressed: () {
    //       currentCompany.currentApps = schema;
    //       schema.selectedAttr = attr;
    //       RouteManager.goto(Pages.pageViewer.id(attr.info.masterID!), context);
    //     },
    //     child: Text('Open app'),
    //   ),
    // );
  }

  @override
  String getTypeTitle(NodeAttribut node, String name, dynamic type) {
    String? typeStr;
    typeStr ??= '$type';
    return typeStr;
  }

  @override
  InvalidInfo? isTypeValid(
    NodeAttribut nodeAttribut,
    String name,
    dynamic type,
    String typeTitle,
  ) {
    return null;
  }

  @override
  Function? getValidateKey() {
    return null;
  }

  @override
  Widget getRowHeader(TreeNodeData<NodeAttribut> node, BuildContext context) {
    var isRoot = node.isRoot;
    var attr = node.data.info;
    if (isRoot) return const Text("select");

    return InkWell(
      onTap: () {
        node.doTapHeader();
      },
      child: Text(attr.name),
    );
  }
}

/// Root model
class BehaviorsModel {
  final List<BehaviorGroup> invariantBehaviors;
  final List<BehaviorGroup> stateChangingBehaviors;
  final List<BehaviorGroup> queryBehaviors;
  final List<BehaviorGroup> policyServiceBehaviors;
  final List<BehaviorGroup> factoryBehaviors;
  final List<BehaviorGroup> domainEventBehaviors;

  BehaviorsModel({
    required this.invariantBehaviors,
    required this.stateChangingBehaviors,
    required this.queryBehaviors,
    required this.policyServiceBehaviors,
    required this.factoryBehaviors,
    required this.domainEventBehaviors,
  });

  factory BehaviorsModel.fromJson(Map<String, dynamic> json) {
    List<BehaviorGroup> parseList(String key) {
      return (json[key] as List<dynamic>)
          .map((e) => BehaviorGroup.fromJson(e))
          .toList();
    }

    return BehaviorsModel(
      invariantBehaviors: parseList("invariant_behaviors"),
      stateChangingBehaviors: parseList("state_changing_behaviors"),
      queryBehaviors: parseList("query_behaviors"),
      policyServiceBehaviors: parseList("policy_service_behaviors"),
      factoryBehaviors: parseList("factory_behaviors"),
      domainEventBehaviors: parseList("domain_event_behaviors"),
    );
  }

  Map<String, dynamic> toJson() => {
    "invariant_behaviors": invariantBehaviors.map((e) => e.toJson()).toList(),
    "state_changing_behaviors": stateChangingBehaviors
        .map((e) => e.toJson())
        .toList(),
    "query_behaviors": queryBehaviors.map((e) => e.toJson()).toList(),
    "policy_service_behaviors": policyServiceBehaviors
        .map((e) => e.toJson())
        .toList(),
    "factory_behaviors": factoryBehaviors.map((e) => e.toJson()).toList(),
    "domain_event_behaviors": domainEventBehaviors
        .map((e) => e.toJson())
        .toList(),
  };

  void writeSection(StringBuffer buffer, List<BehaviorGroup> groups) {
    if (groups.isEmpty) {
      buffer.writeln('pas de comportements définis pour cette catégorie.');
      buffer.writeln();
      return;
    }

    for (final group in groups) {
      buffer.writeln('### ${group.behavior}');
      if (group.rules.isNotEmpty) {
        buffer.writeln('- Rules:');
        for (final rule in group.rules) {
          buffer.writeln('  - $rule');
        }
      }
      if (group.associatedInternalMethods.isNotEmpty) {
        buffer.writeln('- Associated internal methods:');
        for (final method in group.associatedInternalMethods) {
          buffer.writeln('  - $method');
        }
      }
      buffer.writeln();
    }
  }
}

/// A single behavior entry
class BehaviorGroup {
  final String behavior;
  final List<String> rules;
  final List<String> associatedInternalMethods;

  BehaviorGroup({
    required this.behavior,
    required this.rules,
    required this.associatedInternalMethods,
  });

  factory BehaviorGroup.fromJson(Map<String, dynamic> json) {
    return BehaviorGroup(
      behavior: json["behavior"],
      rules: List<String>.from(json["rules"]),
      associatedInternalMethods: List<String>.from(
        json["associated_internal_methods"],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    "behavior": behavior,
    "rules": rules,
    "associated_internal_methods": associatedInternalMethods,
  };

  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('### $behavior');

    if (rules.isNotEmpty) {
      buffer.writeln('- Rules:');
      for (final rule in rules) {
        buffer.writeln('  - $rule');
      }
    }

    if (associatedInternalMethods.isNotEmpty) {
      buffer.writeln('- Associated internal methods:');
      for (final method in associatedInternalMethods) {
        buffer.writeln('  - $method');
      }
    }

    return buffer.toString().trim();
  }
}
