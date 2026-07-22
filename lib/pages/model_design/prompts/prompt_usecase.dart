String promptUseCase = '''
# Contexte techniques :  
Tu es un expert en architecture hexagonale, DDD, CQRS et NestJS.
Génère la couche **Application** complète pour le module <{{module}}> et aggregates <{{aggregates}}> suivants :

La couche Application doit être totalement indépendante de NestJS et de toute technologie.
Elle doit uniquement dépendre du domaine (entities, value objects, aggregates, domain services, domain events, repository ports).

Structure obligatoire à générer :
src/
  core/
    <module>/
      ports/
        app/                  # Interfaces vers l'infrastructure (adapters)
      application/
        app-services/         # Orchestration complexe multi-aggregates
        app-events/           # Événements applicatifs (post-use-case)         
        usecases/             # Use cases (command et query)
          handlers/              # Exécutent commands/queries
          commands/              # Inputs pour modifier l'état
          queries/               # Inputs pour lire l'état
          saga/                  # Orchestration longue, multi-aggregates, multi-événements     
        errors/            # gestion des erreurs applicatives 

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
          - ApplicationEventPublisherPort.publish()
          - CommandDispatcherPort.dispath()
          - UnitOfWorkPort.runInTransaction()

   - Ces ports doivent être utilisés par les handlers et services applicatifs.


## Contexte de code source :
- Le domaine est déjà défini.

## Contraintes techniques :
- Aucun décorateur NestJS.
- Aucun import NestJS.
- Aucun accès direct à la base de données.
- Aucun DTO NestJS.
- Aucun mapping technique.
- Code 100% TypeScript pur.
- Respect strict des invariants métier du domaine.
- gére les erreurs avec Neverthrow
- Les handlers doivent être testables sans framework (sauf Neverthrow).

## Format attendu :
1. Arborescence complète du module.
3. Explication du rôle de chaque élément.
4. Exemple de flux complet (command → handler → domaine → event).
5. Conseils pour maintenir une couche Application propre et scalable.
    ''';