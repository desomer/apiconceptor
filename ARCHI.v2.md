# ARCHI v2

## Principes
- Le domaine contient uniquement la logique metier pure (aucune dependance technique).
- La couche application orchestre les cas d'usage.
- L'infrastructure implemente les ports du core.
- Les mappings DTO existent uniquement aux frontieres entrante/sortante.

## Arborescence proposee

core/
  <module>/
    domain/
      aggregates/      # role: regles metier et invariants des entites
      entities/        # role: objets metier avec identite
      value-objects/   # role: attributs avec controle (device, numero de carte)
      services/        # role: logique metier complexe transverse aux entites
      events/          # role: evenements du domaine
      errors/          # role: classes d'erreur metier

    application/
      use-cases/
        commands/                 # role: intentions d'ecriture (actions metier)
          <command>.dart          # role: contrat de commande
          <command>_handler.dart  # role: action + orchestration du cas d'usage
        queries/                  # role: intentions de lecture (recuperation)
          <query>.dart            # role: contrat de requete
          <query>_handler.dart    # role: recuperation + orchestration du cas d'usage
        sagas/                    # role: processus metier long/distribue, 
                                        souvent asynchrone
      app-services/               # role: orchestration bout en bout 
                                        (validation, ports, persistance, events)
      app-events/                 # role: evenements applicatifs
      errors/                     # role: erreurs de workflow/use case

    ports/
      repositories/    # role: port de persistance
      gateways/        # role: port d'acces aux services externes
      storage/         # role: port de stockage objet (bucket)
      messaging/       # role: port de messagerie
      logger/          # role: port de logging

infrastructure/
  <module>/
    adapters/
      inbound/
        http/<v1>/         # role: adaptateurs HTTP entrants avec version
          controllers/   # role: recoit les API
          dto-in/        # role: contrats d'entree transport
          dto-out/       # role: contrats de sortie transport
          mappers/       # role: mapping toDto / toDomain
        graphql/<v1>/    # role: adaptateurs GraphQL entrants
        cli/             # role: adaptateurs ligne de commande
        scheduler/       # role: declencheurs planifies (cron)
          jobs/          # role: taches cron qui appellent des use-cases

      outbound/
        persistence/
          repositories/  # role: persistance simple
          schemas/       # role: schema de stockage
          read-model/    # role: requetes complexes
          mappers/       # role: mapping toPersistence / toDomain

        external-api/    # role: integration vers APIs externes
          clients/       # role: clients techniques sortants
          dto-in/        # role: objet exterieur entrant
          dto-out/       # role: objet exterieur sortant
          mappers/       # role: mapping vers l'exterieur

        bucket/          # role: acces au stockage objet
          clients/       # role: clients SDK bucket (GCS/S3)
          dto-in/        # role: contrats entrants depuis le provider
          dto-out/       # role: contrats sortants vers le provider
          mappers/       # role: mapping metier <-> provider bucket

        messaging/              # role: transport de messages sortants/entrants
          consumers/            # role: consommation de messages
          publishers/           # role: publication de messages
          avro/                 # role: outillage schema/encodage des events
            serializers/        # role: serialisation payload -> avro
            deserializers/      # role: deserialisation avro -> payload
            registry/           # (optionnel) role: integration schema registry

        logging/        # role: log technique (ex: GCP)

    config/
      database/        # role: config base de donnees
      messaging/       # role: config messaging/pubsub
      scheduling/      # role: config cron/planning
      storage/         # role: config bucket (credentials, nom de bucket)
      external-api/    # role: config API externes

## Regles de placement
1. Une regle metier complexe va dans domain/services.
2. Un enchainement de plusieurs etapes metier-techniques va dans application/use-cases/*_handler.
3. Un processus long, asynchrone ou distribue va dans application/use-cases/sagas.
4. Les classes d'erreur restent dans leur couche d'origine (domain/errors ou application/errors).
5. Les implementations techniques ne remontent jamais dans core/.

## Terminologie (uniformisee)
- Utiliser les noms techniques en anglais pour les dossiers: domain, application, ports, adapters, inbound, outbound.
- Utiliser les descriptions en francais pour les commentaires `# role: ...`.
- Employer `use-cases` partout (et non `use-case`).
- Employer `app-services` pour l'orchestration applicative et `domain/services` pour la logique metier pure.
- Employer `read-model` pour les lectures optimisees et `logging` pour la journalisation technique.

## Conventions de nommage
1. Commande: `<action>_<resource>_command.dart`.
2. Handler de commande: `<action>_<resource>_command_handler.dart`.
3. Requete: `<action>_<resource>_query.dart`.
4. Handler de requete: `<action>_<resource>_query_handler.dart`.
5. Mapper: `<source>_to_<target>_mapper.dart`.
6. Repository (port): `<resource>_repository.dart`.
7. Repository (implementation): `<provider>_<resource>_repository.dart`.
8. Evenement de domaine: `<resource>_<past_tense>_event.dart`.
9. Erreur metier: `<business_rule>_error.dart`.
10. Saga: `<process_name>_saga.dart`.


## Placement des schemas Avro et SWAGGER
Arborescence recommandee:

contracts/
  events/                         # role: contrats d'evenements inter-services
    order-created/                # role: famille d'evenement metier
      v1/                         # role: version de contrat backward-compatible
        order-created.avsc        # role: schema Avro de reference
      v2/                         # role: nouvelle version de contrat
        order-created.avsc        # role: schema Avro versionne
    payment-confirmed/            # role: famille d'evenement metier
      v1/                         # role: version de contrat backward-compatible
        payment-confirmed.avsc    # role: schema Avro de reference
  api/                            # role: contrats d'API publiques
    order-service/                # role: contrat API du service
      v1/                         # role: version majeure API
        openapi.yaml              # role: specification OpenAPI v1
      v2/                         # role: nouvelle version majeure API
        openapi.yaml              # role: specification OpenAPI v2


Regles:
1. Les fichiers `.avsc` sont des contrats inter-services, donc dans `contracts/events`.
2. Le producteur est proprietaire de son schema et de son versionning.
3. Toute rupture de compatibilite cree une nouvelle version (v2, v3...).
4. Le code de serialisation/deserialisation Avro reste en infrastructure (jamais en domain).
5. Les handlers applicatifs manipulent des objets metier/applicatifs, pas des objets Avro bruts.
6. Les contrats HTTP publics sont versionnes dans `contracts/api/<service>/vX/openapi.yaml`.

Compatibilite conseillee:
1. Backward compatible par defaut.
2. Ajouter des champs avec valeur par defaut pour eviter les ruptures.
3. Ne pas supprimer/renommer un champ en place; introduire une nouvelle version.

## Exemples de flux

### 1) Query simple (cas de base)
1. `http/controllers` recoit `GetCustomerById`.
2. Le controller mappe le `dto-in` vers `core/<module>/application/use-cases/queries/get_customer_by_id_query.dart`.
3. `core/<module>/application/use-cases/queries/get_customer_by_id_query_handler.dart` appelle `core/<module>/ports/repositories/customer_repository.dart`.
4. Le repository retourne l'entite ou une vue simple.
5. Le handler mappe en `infrastructure/<module>/adapters/inbound/http/dto-out/get_customer_by_id_response.dart` et renvoie la reponse.

### 2) Commande simple (synchrone)
1. `http/controllers` recoit `CreateOrder`.
2. `dto-in` est valide puis mappe vers `core/<module>/application/use-cases/commands/create_order_command.dart`.
3. `core/<module>/application/use-cases/commands/create_order_command_handler.dart` charge les dependances via `core/<module>/ports/repositories`.
4. Le handler appelle le domaine (`entities`, `value-objects`, `domain/services`) pour appliquer les regles metier.
5. Le repository persiste l'agregat dans `infrastructure/<module>/adapters/outbound/persistence/repositories`.
6. Le handler publie un `app-event` et retourne un `dto-out` via le controller.

### 3) Saga avec compensation (asynchrone)
1. `core/<module>/application/app-events/order_created_event.dart` demarre `core/<module>/application/use-cases/sagas/order_fulfillment_saga.dart`.
2. La saga demande la reservation du stock via `infrastructure/<module>/adapters/outbound/messaging/publishers`.
3. Si stock reserve, la saga declenche la demande de paiement.
4. Si paiement accepte, la saga publie `core/<module>/application/app-events/order_confirmed_event.dart`.
5. Si paiement refuse, la saga execute la compensation: publication d'un message de liberation de stock.
6. La saga termine avec un etat final (`confirmed` ou `cancelled`) et trace l'execution dans `infrastructure/<module>/adapters/outbound/logging`.

### 4) Query avec read model (lecture optimisee)
1. `http/controllers` recoit `GetOrderById`.
2. Le controller mappe le `dto-in` vers `core/<module>/application/use-cases/queries/get_order_by_id_query.dart`.
3. `core/<module>/application/use-cases/queries/get_order_by_id_query_handler.dart` lit via `infrastructure/<module>/adapters/outbound/persistence/read-model`.
4. Le handler ne modifie aucun etat metier (read-only).
5. Le resultat est mappe en `infrastructure/<module>/adapters/inbound/http/dto-out/get_order_by_id_response.dart` puis renvoye au client.

### 5) Integration API externe avec retry (sans pubsub)
1. `core/<module>/application/use-cases/commands/create_invoice_command_handler.dart` prepare la demande de facturation.
2. Le handler appelle un port `gateway` du core.
3. L'implementation technique dans `infrastructure/<module>/adapters/outbound/external-api/clients` effectue l'appel HTTP.
4. En cas d'erreur transitoire, un retry borné est applique.
5. En cas d'echec final, une erreur applicative est levee dans `core/<module>/application/errors`.
6. Le domaine reste inchange: aucune logique HTTP dans `core/<module>/domain`.

### 6) Consommateur de message idempotent
1. Un consumer Pub/Sub dans `infrastructure/<module>/adapters/outbound/messaging/consumers` recoit `payment_confirmed_event`.
2. Le message est transforme en commande applicative (`confirm_payment_command.dart`) puis transmis au handler correspondant.
3. Le handler controle l'idempotence via `core/<module>/ports/repositories/processed_message_repository.dart`.
4. Si `messageId` a deja ete traite, le consumer fait `ack` immediatement (message deja applique).
5. Sinon, le handler met a jour la commande via `core/<module>/ports/repositories/order_repository.dart`, puis marque le message comme traite.
6. Si le traitement metier et la persistance reussissent, le consumer Pub/Sub fait `ack`.
7. En cas d'erreur transitoire (timeout DB/API), le consumer fait `nack` pour declencher un retry Pub/Sub.
8. En cas d'erreur non recuperable (payload invalide/schema incompatible), le message est redirige vers la DLQ puis `ack` pour eviter une boucle infinie.



| Critere                | Neverthrow        | Either (fp-ts)     |
|:-----------------------|:------------------|:-------------------|
| Courbe d'apprentissage | Facile            | Difficile          |
| Lisibilite             | Haute             | Moyenne            |
| Async                  | Excellent         | Moins naturel      |
| Puissance FP           | Moyenne           | Tres elevee        |
| Integration TS         | Parfaite          | Demande fp-ts      |
| Ideal pour             | Projets TS normaux| Code FP pur        |