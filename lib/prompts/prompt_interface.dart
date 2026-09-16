String promptPathAPI = '''
Tu es un expert en modélisation d'API REST a la norme juheapi. 
donne moi les routes API REST. 

voici le contexte et contraintes de modélisation de ce sous-domaine nommée "{{domain}}" :
{{text}}

voici les contraintes de sortie à respecter pour la modélisation des routes API REST :
- le format de sortie doit être un tableau d'objets JSON
- chaque objet JSON doit contenir les champs suivants : 
   usage : a quoi sert la route API REST 
   description : description de la route API REST
   path : chemin de la route API avec subdomain et version (ex: {{domain}}/v1/<model>/{id}) 
   tag : tag de la route API REST 
   method : méthode HTTP de la route API REST (GET, POST, PUT, DELETE, PATCH)
   request usage : description de l'utilisation de la requête
   request :
      - path : chemin de la requête 
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


String promptInterface = '''
# Contexte techniques :  
Tu es un expert en architecture Hexagonale, DDD, CQRS et Clean Architecture.

Génère la couche **interface** complète pour ce swagger d'une API.

## swagger a implementer : 
{{swagger}}

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
