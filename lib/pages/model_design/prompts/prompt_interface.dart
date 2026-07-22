String promptInterface = '''
# Contexte techniques :  
Tu es un expert en architecture Hexagonale, DDD, CQRS et Clean Architecture.

Génère la couche **interface** complète pour le module <{{module}}> et aggregates <{{aggregates}}>.

## Contexte de code source :
- Le domaine est déjà défini.
- La couche Application est déjà définie.

Respecte strictement l'arborescence suivante :
interface/
  <module>/
      └── mappers/
      │    ├── dto-in/
      │    ├── dto-out/
      ├── http/
      │    ├── controllers/
  <!--│
      ├── graphql/            (si GraphQL est utilisé)
      │    ├── resolvers/
      │    ├── inputs/
      │    └── outputs/
      │
      ├── subscribers/        (si des events applicatifs doivent être écoutés)
      └── cli/                (si des commandes CLI doivent être exposées)
-->

## Règles obligatoires :

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
   - Appelle usecase Command ou Query.
   - Convertit Domain → Response DTO via un Mapper.
   - Ne contient aucune logique métier.
   - pas d'appel direct au domaine, tout passe par la couche Application.
   - Utilise le logger pipo pour log technique.
   - ne pas mettre d'appel à un bus d'événement, tout doit passer par la couche Application.

4. **Mapper (mappers/)**
   - Transforme DTO → Command.
   - Transforme Domain → Response DTO.
   - Ne dépend pas de NestJS.
   - Ne contient aucune logique métier.

<!--
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
-->

## Génère :
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
