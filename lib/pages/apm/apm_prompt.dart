import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/pages/apm/widget_prompt.dart';

import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';

/*
services:
  apiarchi:
    image: ghcr.io/apiarchitec/proxy:latest
    container_name: apiarchitec
    ports:
      - "3128:3128"
    volumes:
      - ../../prompts:/prompts
*/

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
    var listApps = currentCompany.currentAPM;
    var currentApp = listApps?.selectedAttr?.info.name ?? '';
    currentApp = currentApp.toLowerCase();

    final items = <PromptItem>[
      PromptItem(
        name: 'docker apiarchitec',
        fileName: 'docker-apiarchitec.md',
        isSelectable: false,
        markdown: '''
creer un dossier a la racine
   docker/apiarchitec

contenant le fichier .env
   avec le contenu suivant : 
```env
GEMINI_API_KEY=your_gemini_api_key_here
```

contenant le fichier docker-compose.yml
```md      
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    env_file:
      - .env
    ports:
      - "11434:11434"
    volumes:
      - \${OLLAMA_STORAGE_DIR:-../ollama-data}:/root/.ollama
    gpus: all
    restart: unless-stopped

  qdrant:
    image: qdrant/qdrant:v1.13.2
    container_name: qdrant
    env_file:
      - .env
    ports:
      - "6333:6333"
    volumes:
      - \${QDRANT_STORAGE_DIR:-../qdrant-data}:/qdrant/storage
    restart: unless-stopped

  apiarchitect-proxy:
    image: ghcr.io/apiarchitec/proxy:latest
    restart: unless-stopped
    ports:
      - "3128:3128"
    depends_on:
      - ollama
      - qdrant
    env_file:
      - .env
    environment:
      OLLAMA_HOST: http://ollama:11434
      OLLAMA_EMBED_MODEL: nomic-embed-text
      OLLAMA_CHAT_MODEL: llama3.2
      QDRANT_URL: http://qdrant:6333
      QDRANT_COLLECTION: knowledge_markdown
      KNOWLEDGE_DIR: /knowledge
      RAG_CANDIDATE_K: 12
      RAG_TOP_K: 4
      GEMINI_API_KEY: \${GEMINI_API_KEY}
      GEMINI_MODEL : gemini-flash-latest
      GEMINI_TIMEOUT_MS : 60000
    volumes:
      - ../../knowledge:/knowledge:ro
      - ../../prompts:/prompts
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3128/healthz"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 5s
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
''',
      ),
      PromptItem(
        name: 'stack boilerplate',
        fileName: 'stack-boilerplate.md',
        isSelectable: true,
        markdown:
            '''
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
       - correlation-id middleware de type `x-correlation-id` avec un uuidv4 généré si absent

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
   - crée le fichier .env avec les variables d'environnement suivantes :
   - le tsconfig.json n'a pas d'erreur en utilisant la dernière version de la norme
```
PORT=3000
NODE_ENV=development
LOG_LEVEL=debug
HOSTNAME=local-dev-pod
PUBSUB_EMULATOR_HOST=127.0.0.1:8681
PUBSUB_PROJECT_ID=my-local-project
MONGODB_URI=mongodb://127.0.0.1:27017
MONGODB_DB_NAME=$currentApp  
```

5. Contraintes techniques :
   - Code propre, lisible, modulaire
   - Pas de décorateurs inutiles
   - Pas de class-validator / class-transformer
   - Respect des conventions NestJS

6. Anti-régression runtime (obligatoire) :
   - Ne pas dépendre implicitement de `emitDecoratorMetadata` pour l'injection en dev/watch.
   - Dans les contrôleurs, faire une injection explicite de service (ex: `constructor(@Inject(AppService) private readonly appService: AppService) {}`).
   - Conserver une pipe Zod globale, mais pour les payloads critiques (`@Body`) appliquer aussi un schéma explicite sur la route (ex: `@Body(new ZodValidationPipe(EchoBodySchema))`) pour éviter les régressions de métadonnées selon le runner (`tsx`/`esbuild`).
   - Vérifier au minimum au runtime après génération :
     - `GET /health` retourne `200` avec `{ status: 'ok', timestamp: number }`
     - `POST /echo` valide retourne `201` avec `{ message: string }`
     - `POST /echo` invalide (`{}`) retourne `400` avec détails de validation Zod   
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
