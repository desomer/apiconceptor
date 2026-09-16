import 'package:jsonschema/prompts/prompt_header.dart';

String promptUseCase = '''
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
