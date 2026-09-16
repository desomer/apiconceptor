

import 'package:jsonschema/prompts/prompt_header.dart';

var headerModel = '''
identifiers:
  primary:
    - customerId
  alternate:
    - email
  external:
    - crmCustomerId

contracts:
   schema: schemas/customer.schema.json

relations:
  - type: hasMany
    target: Order
  - type: belongsTo
    target: Company
''';

String promptModel = '''
---
$promptHeader
---

# Contexte techniques :  
Tu es un expert en architecture hexagonale et en DDD.  
Ajoute ou modifie la couche **Domaine** pour le module <{{module}}> suivant cette spécification :

{{spec}}

# Contraintes techniques :
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

# Rappel : 
  1. Un agrégat :
  - ne peut pas appeler une méthode d’un autre agrégat
  - ne peut pas charger un autre agrégat
  - ne peut pas vérifier une règle qui dépend d’un autre agrégat
  - ne peut pas accéder à un repository d’un autre agrégat
  - ne peut pas modifier un autre agrégat
  - il peut référencer l’ID d’un autre agrégat
  - publier un événement que d’autres agrégats écouteront
  - laisser un Use Case orchestrer la collaboration
  - laisser un Domain Service appliquer une règle inter‑agrégats
 
  2. Le dossier read-model :
  - Lecture optimisée pour les cas d’usage
  - Contient des projections de données pour les cas d’usage

  3. Le dossier services :
  - Logique métier qui ne rentre pas dans un Aggregate
    Exemples :
    calculs complexes
    règles métier transverses
    validation métier multi‑aggregates
    politiques métier (pricing, eligibility, scoring)
  - Services métier stateless
    Exemples :
      PasswordPolicyService
      PricingService
      EligibilityService
      UserDomainService (si plusieurs aggregates doivent collaborer)
  - Règles métier réutilisables
    Exemples :
      calcul de TVA
      calcul de réduction
      règles de sécurité métier
      règles de validation métier
  - Opérations métier qui ne doivent pas être dans un handler
    Parce qu’un handler = orchestration, pas logique métier.


# MODE STRICT - CONTRAINTES BLOQUANTES

Tu dois appliquer ces règles AVANT de coder.  
Si une seule règle ne peut pas être respectée, STOP, n’écris aucun fichier, et demande validation.

## 1) Arborescence obligatoire (hard requirement)
Tous les fichiers créés/modifiés DOIVENT être uniquement sous :

src/
  core/                # Domaine pur (DDD)
    <module>/
          ports/
            logging/
            repositories/ 
            read-model/     # lecture complexe multi aggregates optimisée (uniquement si nécessaire)
            messaging/  
          domain/
            models/
              aggregates/
              entities/
              value-objects/
            services/       # services métier stateless
            events/
            errors/  

Interdiction absolue de créer/modifier en dehors de cette arborescence.

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

''';