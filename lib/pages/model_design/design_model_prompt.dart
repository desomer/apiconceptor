import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/feature/documentation/documentation_options.dart';
import 'package:jsonschema/pages/apm/widget_prompt.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:markdown_widget/widget/markdown.dart';

// ignore: must_be_immutable
class DesignModelPromptPage extends GenericPageStateless {
  DesignModelPromptPage({super.key});
  String query = '';

  String getPromptTest(String md, String module) {
    String prompt = ''' 
 Tu es un expert TypeScript, DDD et tests unitaires.
Je veux que tu génères (ou modifies) et implémentes les tests unitaires de la couche domaine de mon module <{{module}}> suivant cette spécification :.

{{definition du domaine}}

context : 
- Le domaine est déjà défini.

Objectif :
Couvrir 100% des règles métier du domaine (pas de tests e2e, pas d'infra, pas de NestJS).
Tester uniquement les comportements métier et les invariants.
Utiliser une approche claire Arrange / Act / Assert.
Périmètre à tester :
- Aggregate
- Entity 
- Value Object
- Domain Service
- Erreurs métier avec neverthrow (Result ok/err)

Exigences de test :

- les cas nominaux
- les cas invalides

- propagation des erreurs repository
- logger appelé sur succès
- Vérifier explicitement le contenu des erreurs (code + message), pas seulement isErr.
- Ajouter des mocks/fakes simples pour repository et logger.
- Fournir des tests lisibles, isolés et déterministes.

Livrables attendus :

- Arborescence de fichiers de test proposée.
- Code complet des fichiers de test.
- Commandes npm à ajouter pour exécuter les tests.
- mets a jour, si besoin, le task.json
- Si nécessaire, les dépendances de test à installer.
- Petit résumé final de la couverture métier obtenue.

Contraintes :

TypeScript strict.
Aucun décorateur NestJS.
Aucun accès DB, HTTP ou framework.
Pas de refactor fonctionnel du domaine sans justification.
''';
    return prompt
        .replaceAll('{{definition du domaine}}', md)
        .replaceAll('{{module}}', module);
  }

  String getPromptModel(String md, String module) {
    String prompt = '''
Tu es un expert en architecture hexagonale et en DDD.  
Ajoute ou modifie la couche **Domaine** pour le module <{{module}}> suivant cette spécification :

{{definition du domaine}}

Contraintes :
- Aucun décorateur NestJS.
- Aucun import lié à un framework (sauf Neverthrow si nécessaire).
- Code 100% TypeScript pur.
- Génère ou réutilise les classes suivantes :
  - Aggregates (racines d'agrégats)
  - Entities (immutables si possible)
  - Value Objects (avec validations internes) uniquement si isVO = Val.Obj
  - Domain Services (logique métier pure)
  - Interfaces de repositories (ports côté domaine)
- Respect strict des invariants métier.
- Pas de DTO, pas de mapping, pas de persistence.
- Pas de logique technique (HTTP, DB, queues…).
- un port Logger (pour pipo) pour log métier
- utilise Neverthrow pour les erreurs métier

Format attendu :
- Arborescence des fichiers de type
   src/
     core/                # Domaine pur (DDD)
       <module>/
           domain/
              aggregates/
              entities/
              value-objects/
              services/
              ports/
              errors/      

- Explications des choix métier''';

    return prompt
        .replaceAll('{{definition du domaine}}', md)
        .replaceAll('{{module}}', module);
  }

  String getPromptPersistance(String md, String module) {
    String prompt = '''
Tu es un expert en architecture hexagonale, NestJS et MongoDB.
Ajoute ou modifie la couche **Infrastructure → Persistence (MongoDB)** <{{module}}> suivant cette spécification :

{{definition du domaine}}

Contexte :
- Le domaine est déjà défini.
- Les ports de repository sont dans : core/<module>/domain/repository-ports/
- Le repository MongoDB doit implémenter ces ports.

Contraintes techniques :
- Utiliser NestJS uniquement dans l'infrastructure.
- Utiliser MongoDB via Mongoose.
- Respecter strictement les interfaces du domaine.
- Ne jamais mettre de logique métier dans l'infrastructure.
- Mapper correctement :
  - Domain → Persistence
  - Persistence → Domain
- Ne jamais retourner un domaine invalide (respect des invariants métier).
- Le repository doit être une classe NestJS annotée avec @Injectable().
- Le module doit fournir :
  - Schema MongoDB
  - Model Mongoose
  - Repository implémentant le port
  - Mappers
  - Module NestJS pour assembler le tout
- Génère ou réutilise les classes si elles existent déjà dans le domaine.
- un port Logger (pour pipo) pour le debug log de la base de données
- utilise Neverthrow pour les erreurs  

Format attendu :
1. Arborescence complète :
   infrastructure/<module>/repositories/
   infrastructure/<module>/schemas/
   infrastructure/<module>/mappers/
   infrastructure/<module>/<module>.module.ts

2. Code complet pour :
   - Schema MongoDB
   - Repository MongoDB (implémentation du port)
   - Mappers (domain ↔ persistence)
   - Module NestJS

3. Explication du câblage :
   - Injection du modèle MongoDB
   - Injection du repository dans les use cases
   - Rôle de chaque fichier

4. Bonus :
   - Conseils pour éviter les pièges MongoDB dans l'hexagonal
   - Comment garantir les invariants métier côté persistance
   ''';

    // remplace {{definition du domaine}} par le contenu de md
    return prompt
        .replaceAll('{{definition du domaine}}', md)
        .replaceAll('{{module}}', module);
  }

  String getPromptUseCase(String module, String aggregates) {
    String prompt = '''
Tu es un expert en architecture hexagonale, DDD, CQRS et NestJS.
Génère la couche **Application** complète pour le module <{{module}}> et aggregates <{{aggregates}}> suivants :

La couche Application doit être totalement indépendante de NestJS et de toute technologie.
Elle doit uniquement dépendre du domaine (entities, value objects, aggregates, domain services, domain events, repository ports).

Structure obligatoire à générer :
src/
  core/
    <module>/
      application/
        commands/              # Inputs pour modifier l'état
        queries/               # Inputs pour lire l'état
        handlers/              # Exécutent commands/queries
        application-services/  # Orchestration complexe multi-aggregates
        saga/                  # Orchestration longue, multi-aggregates, multi-événements
        application-events/    # Événements applicatifs (post-use-case)
        ports/                 # Interfaces vers l'infrastructure (adapters)
        exceptions/            # gestion des erreurs applicatives 

Détails attendus pour chaque dossier :

1. commands/
   - Générer une classe par action métier qui modifie l'état.
   - Classes simples, immuables, sans logique.
   - Exemple : CreateUserCommand, PlaceOrderCommand.

2. queries/
   - Générer une classe par action de lecture.
   - Classes simples, immuables, sans logique.
   - Exemple : GetUserByIdQuery, ListOrdersQuery.

3. handlers/
   - Générer un handler par command et par query.
   - Chaque handler doit :
     - Injecter les ports (repositories, services externes).
     - Orchestrer le domaine.
     - Garantir les invariants applicatifs.
     - Ne contenir aucune logique technique.
   - Méthode obligatoire : execute().

4. application-services/
   - Générer des services applicatifs pour les workflows complexes.
   - Ils orchestrent plusieurs aggregates ou plusieurs use cases.
   - Ne contiennent aucune logique métier, seulement de l'orchestration.
   - orchestration courte, synchrone, dans une seule transaction.

5. saga/ 
   - orchestration longue, asynchrone, multi‑événements, multi‑aggregates, avec compensation.
   - tu as un processus multi‑étapes
   - tu dois écouter des événements
   - tu dois déclencher plusieurs commands
   - tu dois gérer des échecs
   - tu dois compenser (rembourser, annuler, rollback métier)

6. application-events/
   - Générer les événements applicatifs déclenchés après un use case.
   - Exemple : UserRegisteredEvent, OrderPlacedEvent.
   - Ne pas confondre avec les domain events.

7. application-ports/
   - Générer les interfaces nécessaires à l'infrastructure :
     - Repositories
     - Gateways externes
     - Read models
     - Services techniques
   - Ces ports doivent être utilisés par les handlers et services applicatifs.


Contexte :
- Le domaine est déjà défini.

Contraintes générales :
- Aucun décorateur NestJS.
- Aucun import NestJS.
- Aucun accès direct à la base de données.
- Aucun DTO NestJS.
- Aucun mapping technique.
- Code 100% TypeScript pur.
- Respect strict des invariants métier du domaine.
- gére les erreurs avec Neverthrow
- Les handlers doivent être testables sans framework (sauf Neverthrow).

Format attendu :
1. Arborescence complète du module.
3. Explication du rôle de chaque élément.
4. Exemple de flux complet (command → handler → domaine → event).
5. Conseils pour maintenir une couche Application propre et scalable.
    ''';

    // remplace {{definition du domaine}} par le contenu de md
    return prompt
        .replaceAll('{{module}}', module)
        .replaceAll('{{aggregates}}', aggregates);
  }

  String getPromptInterface(String module, String aggregates) {
    String prompt = '''
Tu es un expert en architecture Hexagonale, DDD, CQRS et Clean Architecture.

Génère la couche **interface** complète pour le module <{{module}}> et aggregates <{{aggregates}}>.

Contexte :
- Le domaine est déjà défini.
- La couche Application est déjà définie.

Respecte strictement l'arborescence suivante :
interface/
  <module>/
      ├── http/
      │    ├── controllers/
      │    ├── dto/
      │    ├── responses/
      │    └── mappers/
      │
      ├── graphql/            (si GraphQL est utilisé)
      │    ├── resolvers/
      │    ├── inputs/
      │    └── outputs/
      │
      ├── subscribers/        (si des events applicatifs doivent être écoutés)
      └── cli/                (si des commandes CLI doivent être exposées)

Règles obligatoires :

1. **DTO (dto/)**
   - Validation technique via zod
   - Aucun décorateur métier.

2. **Responses (responses/)**
   - Types primitifs uniquement.
   - Jamais exposer le domaine.
   - Format JSON brut pour l'API.

3. **Controller (controllers/)**
   - Reçoit un DTO d'entrée.
   - Convertit DTO → Command.
   - Appelle CommandBus ou QueryBus.
   - Convertit Domain → Response DTO via un Mapper.
   - Ne contient aucune logique métier.

4. **Mapper (mappers/)**
   - Transforme DTO → Command.
   - Transforme Domain → Response DTO.
   - Ne dépend pas de NestJS.
   - Ne contient aucune logique métier.

5. **GraphQL (graphql/)**
   - Inputs = équivalent des DTO.
   - Outputs = équivalent des responses.
   - Resolvers = équivalent des controllers.

6. **Subscribers (subscribers/)**
   - Écoute des events applicatifs.
   - Ne modifie jamais le domaine.
   - Peut envoyer des emails, WebSocket, logs, etc.

7. **CLI (cli/)**
   - Interface en ligne de commande.
   - Convertit arguments CLI → Command.
   - Appelle CommandBus.

Génère :
- l'arborescence complète
- tous les fichiers
- le code TypeScript complet
- les DTO
- les responses
- le controller
- le mapper
- les exemples de commands utilisées
- un flux complet : DTO → Command → Handler → Domain → Response

- utilise le logger pipo
- gére les erreurs avec Neverthrow
- utilise zod pour valider les DTO et les inputs GraphQL
 

Le code doit être propre, idiomatique, structuré, et conforme aux bonnes pratiques Hexagonales + DDD + CQRS.
''';

    // remplace {{definition du domaine}} par le contenu de md
    return prompt
        .replaceAll('{{module}}', module)
        .replaceAll('{{aggregates}}', aggregates);
  }

  String getPromptIntegration(String module) {
    String prompt = '''
Intègre (ou met à jour) les couches Infrastructure MongoDB, Application (usecase) et Interface HTTP du module <{{MODULE}}> dans l’application NestJS existante.

Contexte :
- Le domaine et l'infrastructure <{{MODULE}}> existent déjà.
- La couche application/usecase <{{MODULE}}> existe déjà.
- La couche interface HTTP <{{MODULE}}> existe déjà.
- Le repository MongoDB implémente le port du domaine via le token xxxxx_REPOSITORY_PORT.

À faire :
1. Modifier AppModule pour importer :
   - MongooseModule.forRoot(...) avec une configuration propre et centralisée
   - VoitureInfrastructureModule
   - le module Interface HTTP du module <{{MODULE}}>
2. Vérifier que le repository MongoDB est bien injectable via xxxx_REPOSITORY_PORT dans les use cases / handlers applicatifs.
3. Vérifier que les providers nécessaires aux use cases sont bien câblés :
   - repository port
   - logger port
   - event bus applicatif
   - read model port
4. Vérifier que la couche interface peut injecter correctement :
   - command bus / query bus
   - handlers applicatifs
   - adapters read model
   - logger pino
   - model Mongoose nécessaire aux adapters
5. Ajouter un contrôle d'injection explicite :
   - s'assurer que tous les tokens exportés par les modules infrastructure sont bien exportés/importés là où ils sont consommés
   - ajouter un contrôle simple au bootstrap ou au module pour détecter rapidement les dépendances manquantes
   - éviter les injections implicites fragiles quand un token explicite est nécessaire
6. Ne pas ajouter de logique métier dans l'infrastructure.
7. Ne pas toucher au domaine sauf si un ajustement de contrat est strictement nécessaire.
8. Garder du TypeScript pur côté domaine et respecter la structure hexagonale.

Contraintes :
- NestJS uniquement dans l'infrastructure et l'interface.
- MongoDB via Mongoose.
- Les use cases / handlers applicatifs doivent rester sans dépendance NestJS.
- Les DTO et mappings HTTP restent dans la couche interface.
- Pas de logique de persistance dans le domaine.
- Pas de logique métier dans les controllers.

Livrable attendu :
- Les fichiers modifiés
- Une explication courte du câblage
- Une explication courte du contrôle d'injection mis en place
- Validation par build TypeScript

''';

    return prompt.replaceAll('{{MODULE}}', module);
  }

  @override
  Widget build(BuildContext context) {
    DocumentationInfo info = DocumentationInfo();
    info.showExampleAvro = false;
    info.showExampleDto = false;
    info.showExampleMongoose = false;

    var md = DocumentationOptions(
      info: info,
      context: context,
    ).getModelDocumentation();

    //return MiroLikeWidget();

    var module =
        currentCompany.listModel!.selectedAttr?.parent?.info.name ?? 'module';

    var aggregate =
        currentCompany.listModel!.selectedAttr?.info.name ?? 'aggregate';

    WidgetPrompt promptWidget = WidgetPrompt(
      listPrompt: [
        PromptItem(
          name: 'domain',
          isSelectable: true,
          markdown: getPromptModel(md, module),
          fileName: 'domain-$module-$aggregate.md',
        ),
        PromptItem(
          name: 'persistence',
          isSelectable: true,
          markdown: getPromptPersistance(md, module),
          fileName: 'persistence-$module-$aggregate.md',
        ),
        PromptItem(
          name: 'use case',
          isSelectable: true,
          markdown: getPromptUseCase(module, aggregate),
          fileName: 'usecase-$module-$aggregate.md',
        ),
        PromptItem(
          name: 'interface',
          isSelectable: true,
          markdown: getPromptInterface(module, aggregate),
          fileName: 'interface-$module-$aggregate.md',
        ),
        PromptItem(
          name: 'domain unit test',
          isSelectable: true,
          markdown: getPromptTest(md, module),
          fileName: 'domain_unit_test-$module-$aggregate.md',
        ),
        PromptItem(
          name: 'check integration',
          isSelectable: true,
          markdown: getPromptIntegration(module),
          fileName: 'check-integration-$module.md',
        ),
      ],
    );

    return promptWidget;
  }

  Widget getPromptWidget(String md, BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.copy),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: md));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('copied to clipboard')));
          },
          label: Text('Prompt in clipboard'),
        ),
        Expanded(
          child: MarkdownWidget(data: md, config: MarkdownConfig.darkConfig),
        ),
      ],
    );
  }
  // Widget build2(BuildContext context) {
  //   return WidgetTab(
  //     key: stateModel.keyTab,
  //     onInitController: (TabController tab) {
  //       stateModel.tabModel = tab;
  //       tab.addListener(() {
  //         if (tab.index == 0) {
  //           stateModel.setTab();
  //         }
  //       });
  //     },
  //     tabDisable: stateModel.tabDisable,
  //     listTab: [
  //       Tab(text: 'Models Browser'),
  //       Tab(text: 'Model Editor'),
  //       Tab(text: 'Json schema'),
  //     ],
  //     listTabCont: [
  //       Column(
  //         children: [
  //           PanModelActionHub(),
  //           Expanded(child: KeepAliveWidget(child: WidgetModelMain())),
  //         ],
  //       ),
  //       KeepAliveWidget(
  //         child: WidgetModelEditor(key: stateModel.keyModelEditor),
  //       ),
  //       WidgetJsonValidator(),
  //     ],
  //     heightTab: 40,
  //   );
  // }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    GlobalKey keyPage,
    PageInit? pageInit,
  ) {
    query =
        routerState.uri.queryParameters['id'] ??
        currentCompany.currentModel!.id;
    var attr = currentCompany.listModel!.getNodeByMasterIdPath(query);
    var name = attr?.info.name;
    var version = attr?.info.properties?['#version'] ?? '0.0.1';
    if (currentCompany.currentModel?.id == query) {
      version = currentCompany.currentModel!.getVersionText();
    }

    return NavigationInfo()
      ..navLeft = [
        BreadNode(
          icon: const Icon(Icons.data_object),
          settings: const RouteSettings(name: 'Design model'),
          type: BreadNodeType.widget,
          path: Pages.modelDetail.urlpath,
        ),

        BreadNode(
          icon: const Icon(Icons.verified),
          settings: const RouteSettings(name: 'Examples'),
          type: BreadNodeType.widget,
          path: Pages.modelJsonSchema.urlpath,
        ),

        BreadNode(
          icon: const Icon(Icons.devices),
          settings: const RouteSettings(name: 'UI view'),
          type: BreadNodeType.widget,
          path: Pages.modelUI.urlpath,
        ),

        BreadNode(
          icon: const Icon(Icons.bubble_chart),
          settings: const RouteSettings(name: 'Graph view'),
          type: BreadNodeType.widget,
        ),

        BreadNode(
          icon: const Icon(Icons.airplane_ticket),
          settings: const RouteSettings(name: 'Doc.'),
          type: BreadNodeType.widget,
          path: Pages.modelScrum.urlpath,
        ),

        BreadNode(
          // icon IA
          icon: const Icon(Icons.smart_toy),
          settings: const RouteSettings(name: 'Prompt AI'),
          type: BreadNodeType.widget,
          path: Pages.modelPromptAI.urlpath,
        ),
      ]
      ..breadcrumbs = [
        BreadNode(
          settings: const RouteSettings(name: 'Domain'),
          type: BreadNodeType.domain,
          path: Pages.models.urlpath,
        ),
        BreadNode(
          settings: const RouteSettings(name: 'List model'),
          type: BreadNodeType.widget,
          path: Pages.models.urlpath,
        ),
        BreadNode(
          settings: RouteSettings(name: name),
          type: BreadNodeType.widget,
        ),
        BreadNode(
          settings: RouteSettings(name: version),
          type: BreadNodeType.widget,
        ),
        BreadNode(
          settings: RouteSettings(name: 'link'),
          type: BreadNodeType.link,
          path:
              '${Pages.modelDetail.urlpath}?id=$query&ns=${currentCompany.currentNameSpace}',
        ),
      ];
  }
}
