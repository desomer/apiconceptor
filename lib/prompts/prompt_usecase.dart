import 'package:jsonschema/prompts/prompt_header.dart';

String promptDesignUseCase = '''
# Contexte techniques :  
Tu es un expert en architecture hexagonale, Domain-Driven Design (DDD), CQRS et Saga

{{usecase}}

Donne moi la cartographie des Use Cases et des Sagas possibles de la couche applicative par Bounded Context, 
suivie de la spécification détaillée de ses Use Case et des Saga orchestrées.

# exemple de USE CASE: UpdateProductPrice

1. Objectif métier
   Permettre la mise à jour du prix d’un produit existant.

2. Déclencheur (Input)
   - productId: string (UUID)
   - newPrice: number (> 0)
   - updatedBy: string (userId)

3. Règles métier
   - Le produit doit exister.
   - Le prix doit être strictement positif.
   - Le changement doit être historisé.
   - L’utilisateur doit être autorisé à modifier le prix.

4. Ports utilisés
   - ProductRepository
   - PriceHistoryRepository
   - UserAuthorizationService

5. Processus détaillé
   1. Charger le produit via ProductRepository.findById
   2. Vérifier les droits via UserAuthorizationService.canUpdatePrice
   3. Appeler product.updatePrice(newPrice)
   4. Sauvegarder via ProductRepository.save
   5. Enregistrer l’historique via PriceHistoryRepository.recordChange
   6. Retourner le produit mis à jour

6. Sortie (Output)
   - productId
   - oldPrice
   - newPrice
   - updatedAt
   - updatedBy

7. Erreurs possibles
   - ProductNotFound
   - UnauthorizedUser
   - InvalidPrice
   - RepositoryError

8. Scénarios (Given / When / Then) :

Scénario nominal : Mise à jour réussie du prix
    Given un produit existe avec l'identifiant "product-123"
    And son prix actuel est de 100.00
    And l'utilisateur "user-456" est autorisé à modifier les prix

    When l'utilisateur demande la mise à jour du prix à 120.00

    Then le produit est récupéré depuis le ProductRepository
    And le prix du produit est mis à jour à 120.00
    And le produit est sauvegardé
    And un historique de changement est enregistré
    And les informations de mise à jour sont retournées

Scénario d'erreur : Produit introuvable
    Given aucun produit n'existe avec l'identifiant demandé

    When l'utilisateur demande la mise à jour du prix

    Then l'erreur ProductNotFound est retournée
    And aucune modification n'est effectuée
    And aucun historique n'est enregistré

Scénario d'erreur : Prix invalide
    Given le produit existe
    And l'utilisateur est autorisé

    When l'utilisateur fournit un prix inférieur ou égal à zéro

    Then l'erreur InvalidPrice est retournée
    And le produit n'est pas modifié
    And aucun historique n'est enregistré


9. Critères d'acceptation

Le système doit permettre la mise à jour du prix d'un produit existant.
Le système doit refuser toute valeur de prix inférieure ou égale à zéro.
Le système doit vérifier les droits de l'utilisateur avant toute modification.
Le système doit retourner une erreur ProductNotFound si le produit n'existe pas.
Le système doit retourner une erreur UnauthorizedUser si l'utilisateur n'est pas autorisé.
Le système doit retourner une erreur InvalidPrice si le prix fourni est invalide.
Le système doit sauvegarder le nouveau prix dans le référentiel des produits.
Le système doit enregistrer l'ancien prix et le nouveau prix dans l'historique.
Le système doit enregistrer l'identifiant de l'utilisateur ayant effectué la modification.
Le système doit enregistrer la date et l'heure de la modification.
Le système doit retourner les informations de mise à jour après un traitement réussi.
Aucun historique ne doit être créé lorsqu'une règle métier est violée.

10. Non-objectifs

Ce use case ne couvre pas :

La création d'un produit.
La suppression d'un produit.
La modification d'autres attributs du produit (nom, description, stock, catégorie, etc.).
Les mises à jour massives de prix sur plusieurs produits.
La gestion des promotions ou remises temporaires.
La planification d'un changement de prix à une date future.
La gestion des devises ou des taux de conversion.
Le calcul automatique de taxes ou de marges.
La notification des utilisateurs suite à un changement de prix.
La synchronisation avec des systèmes externes de facturation ou de catalogue.


# exemple de SAGA : 

- Spécification de la Saga en mermaid
- Matrice des Compensations de la Saga
    - Étape
    - Action Nominale
    - Action de Compensation (Rollback)
    - Déclencheur du Rollback
    - Criticité
    - Idempotente
    - Retryable
    - Timeout



# sortie attendue :
   - sortie d'un json uniquement (pas de blabla, pas d'explication, pas de texte, pas de code block)
   - sortie de type : 
 {
  "boundedContexts": [
    {
      "name": "",
      "description": "",
      "useCases": [
        {
          "name": "",
          "objective": "",
          "trigger": {},  // en jsonschemas mais sans attribut "\$schema"
          "businessRules": [],   // tableau des règles métier en string
          "ports": [],    // tableau des ports en string
          "detailedProcess": [],  // tableau des étapes détaillées du processus en string
          "output": {},    // en jsonschemas mais sans attribut "\$schema"
          "possibleErrors": [],  // tableau des erreurs possibles en string
          "scenarios": [
            {
              "type": "Nominal",
              "title": "",
              "given": "",
              "when": "",
              "then": ""
            }
          ],
          "acceptanceCriteria": [],  // tableau des critères d'acceptation en string
          "nonGoals": [],  // tableau des non-objectifs en string
          "sagas": [
            {
              "name": "",
              "description": "",
              "mermaidDiagram": "",
              "textDiagram": "",  // version textuelle markdown du diagramme 
              "compensationMatrix": [
                {
                  "step": "",
                  "nominalAction": "",
                  "compensationAction": "",
                  "rollbackTrigger": "",
                  "criticality": "",  // niveau de criticité de l'étape CRITICAL, HIGH, MEDIUM, LOW
                  "idempotent": false,
                  "retryable": false,
                  "timeout": ""   // durée au format ISO 8601
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}

# MODE STRICT - CONTRAINTES BLOQUANTES : 
  - vérification de la conformité du JSON des trigger et des output
  - vérification de la conformité du global du JSON renvoyé. Il doit etre parsable par flutter.
  - correction automatique des erreurs JSON avant de renvoyer la sortie.
''';

String promptUseCase =
    '''
---
$promptHeader
---
# Contexte techniques :  
Tu es un expert en architecture hexagonale, DDD, CQRS et NestJS.
Génère la couche **Application** complète pour le module <{{module}}> et aggregates <{{aggregates}}> suivants :

La couche Application doit être totalement indépendante de NestJS et de toute technologie.
Elle doit uniquement dépendre du domaine (entities, value objects, aggregates, domain services, domain events, repository ports).

# MODE STRICT - CONTRAINTES BLOQUANTES

Tu dois appliquer ces règles AVANT de coder.  
Si une seule règle ne peut pas être respectée, STOP, n’écris aucun fichier, et demande validation.

## 1) Arborescence obligatoire (hard requirement)
Tous les fichiers créés/modifiés DOIVENT être uniquement sous :

Structure obligatoire à générer :
src/
  core/
    <module>/
      ports/
        gateways/            # role: services externes
        messaging/           # role: publication/consommation de messages
        storage/             # role: stockage objet (bucket, file)
        logging/             # role: journalisation 
        repositories/            
        read-model/          # lecture complexe multi aggregates optimisée (uniquement si nécessaire)
      
      application/           # role: orchestration des cas d'usage
        commands/            # role: intentions d'ecriture
        queries/             # role: intentions de lecture
        sagas/               # role: processus longs ou distribues
        services/            # role: orchestration applicative
        events/              # role: evenements applicatifs
        errors/              # gestion des erreurs applicatives 

Interdiction absolue de créer/modifier en dehors de cette arborescence.

Détails attendus pour chaque dossier :

1. commands/
   - Générer une classe par action métier qui modifie l'état.
   - Classes simples, immuables, sans logique.
   - Exemple : CreateUser.command.ts, PlaceOrder.command.ts.

2. queries/
   - Générer une classe par action de lecture.
   - Classes simples, immuables, sans logique.
   - Exemple : GetUserById.query.ts, ListOrders.query.ts.

3. les fichiers handlers dans commands et queries (<command>.handler.ts, <query>.handler.ts)
   - Générer un handler par command et par query.
   - Chaque handler doit :
     - Injecter les ports (repositories, services externes).
     - Orchestrer le domaine.
     - Garantir les invariants applicatifs.
     - Ne contenir aucune logique technique.
   - Méthode obligatoire : execute().

4. services/
   - Générer des services applicatifs pour les workflows complexes.
   - Ils orchestrent plusieurs aggregates ou plusieurs use cases.
   - Ne contiennent aucune logique métier, seulement de l'orchestration.
   - orchestration courte, synchrone, dans une seule transaction.
   - orchestration bout en bout (validation, ports, persistance, events)

5. sagas/
   - orchestration longue, asynchrone, multi‑événements, multi‑aggregates, avec compensation.
   - tu as un processus multi‑étapes
   - tu dois écouter des événements
   - tu dois déclencher plusieurs commands
   - tu dois gérer des échecs
   - tu dois compenser (rembourser, annuler, rollback métier)

6. events/
   - Générer les événements applicatifs déclenchés après un use case.
   - Exemple : UserRegisteredEvent, OrderPlacedEvent.
   - Ne pas confondre avec les domain events.

7. ports/
   - Générer les interfaces nécessaires à l'infrastructure :
     - Gateways externes
     - Read models
     - Services techniques 
          - ApplicationEventPublisherPort.publish()
          - CommandDispatcherPort.dispath()
          - UnitOfWorkPort.runInTransaction()

   - Ces ports doivent être utilisés par les handlers et services applicatifs.

8. errors/
   - Générer les exceptions applicatives spécifiques à chaque workflow/use case.
   - Exemple : UserAlreadyExistsException, OrderNotFoundException.

## 2) Politique d’exécution
- Étape 1: proposer le plan + liste exacte des fichiers ciblés.
- Étape 2: attendre ma validation explicite “GO”.
- Étape 3: coder.
- Étape 4: vérifier build/tests.
- Étape 5: afficher checklist de conformité.
- Étape 6: archiver les prompts UNIQUEMENT si checklist = 100%.

## 3) Checklist de conformité obligatoire
- [ ] Aucun fichier hors arborescence imposée.
- [ ] Domaine en TypeScript pur (pas de décorateurs NestJS, pas de framework).
- [ ] Ports/domain/services/events/errors présents selon besoin.
- [ ] Invariants métier implémentés.
- [ ] Build OK.
- [ ] Diff final listé fichier par fichier.

## 4) Règle d’ambiguïté
Si une contrainte est ambiguë ou contradictoire avec le code existant:
- STOP
- Pose 1 question précise
- N’écris rien tant que je n’ai pas répondu.

## 5) Règle d’archivage
Ne déplace les prompts en archive qu’après:
- build OK
- checklist complète validée
- mon message “ARCHIVE OK”.

## 6) Contexte de code source :
- Le domaine est déjà défini.

## 7) Contraintes techniques :
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
1. Exemple de flux complet (command → handler → domaine → event).
2. Conseils pour maintenir une couche Application propre et scalable.
    ''';
