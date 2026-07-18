import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/pages/apm/widget_prompt.dart';

import 'package:jsonschema/pages/router_generic_page.dart';



class ApmPrompt extends GenericPageStateless {
  const ApmPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: WidgetPrompt(listPrompt: buildNameChecklistWithMarkdownDetail()),
    );
  }

  List<PromptItem> buildNameChecklistWithMarkdownDetail() {
    final items = <PromptItem>[
      PromptItem(
        name: 'docker apiarchitec',
        fileName: 'docker-apiarchitec.md',
        isSelectable: false,
        markdown: '''
creer un dossier a la racine
   docker/apiarchitec

contenant le fichier docker-compose.yml
```md      
services:
  apiarchi:
    image: ghcr.io/apiarchitec/proxy:latest
    container_name: apiarchitec
    ports:
      - "3128:3128"
    volumes:
      - ../../prompts:/prompts
```
''',
      ),
      PromptItem(
        name: 'docker mongo',
        fileName: 'docker-mongo.md',  
        isSelectable: true,
        markdown: '''
creer un dossier a la racine
   docker/mongo

contenant le fichier docker-compose.yml
```md      
services:
  mongo:
    image: mongo:latest
    container_name: mongodb
    ports:
      - "27017:27017"
    volumes:
      - ./mongo-data:/data/db
```
''',
      ),
      PromptItem(
        name: 'docker pubsub',
        fileName: 'docker-pubsub.md',
        isSelectable: true,
        markdown: '''
creer un dossier a la racine
   docker/pubsub

contenant le fichier docker-compose.yml
```md      
services:
  pubsub:
    image: google/cloud-sdk:latest
    container_name: pubsub-emulator
    command: >
      gcloud beta emulators pubsub start
      --project=my-local-project
      --host-port=0.0.0.0:8681
    ports:
      - "8681:8681"
    environment:
      - PUBSUB_EMULATOR_HOST=0.0.0.0:8681

  pubsub-ui:
    image: ghcr.io/neoscript/pubsub-emulator-ui:latest
    container_name: pubsub-emulator-ui
    depends_on:
      - pubsub
    ports:
      - "8086:80"
    environment:
      - PUBSUB_EMULATOR_HOST=pubsub:8681
```
'''
      ),      
      PromptItem(
        name: 'stack boilerplate',
        fileName: 'stack-boilerplate.md',
        isSelectable: true,
        markdown: '''
Tu es un expert NestJS. Génère un boilerplate light avec les exigences suivantes :

context :
ce boilerplate servira de base pour d'autre prompt de modélisation d'une architecture hexa 

1. Stack :
   - NestJS (architecture modulaire)
   - Pino Logger via `nestjs-pino`
   - Zod pour validation
   - neverthrow pour la gestion fonctionnelle des erreurs
   - TypeScript strict
   - Fastify comme adapter HTTP

2. Structure du projet :
   src/
     main.ts (Fastify + Pino + global Zod pipe)
     app.module.ts


3. Futur fonctionnalités obligatoires :
   - DTO 100% Zod (pas de class-validator)
   - Pipe global pour valider les inputs via Zod
   - Services retournant des Result<Ok, Err> via neverthrow
   - Logger Pino configuré avec :
       - prettyPrint en dev
       - JSON en prod
       - correlation-id middleware

4. Génère :
   - Les imports corrects
   - Un package.json minimal pour lancer le projet
   - ajoute le log du port de l'application dans le main.ts
   - crée une route GET /health qui retourne un JSON { status: 'ok', timestamp: Date.now() }
   - crée une route POST /echo qui prends un body JSON {message : 'message'}.
       - cette route doit valider le body avec Zod (via zod-validation.pipe... le message est obligatoire) et retourner {message: 'message'}
   - n'oublie pas d'injecter AppService dans le contrôleur au runtime
   - crée le fichier Dockerfile pour l'application
   - crée le fichier .dockerignore avec node_modules et dist
   - crée le fichier npm-commands.md avec les commandes npm possible
   - créé le fichier .gitignore avec node_modules et dist
   - crée le fichier tasks.json (VSCode) pour les taches de debug, dev et build
   - crée le fichier README.md avec les instructions pour lancer le projet
   - crée le fichier .env avec les variables d'environnement nécessaires
  

5. Contraintes :
   - Code propre, lisible, modulaire
   - Pas de décorateurs inutiles
   - Pas de class-validator / class-transformer
   - Respect des conventions NestJS
''',
      ),
    ];
    return items;
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    GlobalKey keyPage,
    PageInit? pageInit,
  ) {
    return NavigationInfo();
  }
}

