import 'package:jsonschema/prompts/prompt_header.dart';

String promptTestDomain = '''
---
$promptHeader
---

# Contexte techniques :  
Tu es un expert TypeScript, DDD et tests unitaires.
Je veux que tu génères (ou modifies) et implémentes les tests unitaires de la couche domaine de mon module <{{module}}> suivant cette spécification :.

{{spec}}

## Contexte du code source : 
- Le domaine est déjà défini.

Objectif :
Couvrir 100% des règles métier du domaine (pas de tests e2e, pas d'infra, pas de NestJS).
Tester uniquement les comportements métier et les invariants.
Utiliser une approche claire Arrange / Act / Assert.

## Exigences de test :

- propagation des erreurs repository
- logger appelé sur succès
- Vérifier explicitement le contenu des erreurs (code + message), pas seulement isErr.
- Ajouter des mocks/fakes simples pour repository et logger.
- Fournir des tests lisibles, isolés et déterministes.


CONTRAINTES TESTS OBLIGATOIRES (NON NÉGOCIABLES)

- Convention de nommage imposée
    Tous les tests unitaires doivent être en .spec.ts.
    Refus de .test.ts.

- Portée de test minimale obligatoire
   Tester les aggregates.
   Tester les domain services et policy services.
   Tester les use cases/handlers applicatifs.
   Tester les mappers critiques.
   Tester les adapters/repositories avec doubles si nécessaire.
   Tester les erreurs métier et transitions invalides.

- Couverture fonctionnelle attendue
    Cas nominal.
    Cas limites.
    Cas d’erreur.
    Invariants métier.
    Transitions d’état autorisées et interdites.
    Événements émis par le domaine si présents.

- Critères de validation
    Chaque méthode publique d’aggregate doit avoir au moins un test nominal et un test d’échec.
    Chaque service métier doit avoir tests succès et échec.

- Critères de livraison obligatoires
    Générer la liste exacte des fichiers .spec.ts créés/modifiés.
    Ajouter ou mettre à jour les scripts npm de test.
    Exécuter build + tests.
    Fournir le résultat d’exécution (pass/fail, nombre de tests).

- Les fichiers .spec.ts ne doivent pas être embarqués dans l’artefact de production.
- Prévoir explicitement l’exclusion des tests du build de prod.


Definition of done:

- tests en .spec.ts obligatoires
- tests aggregates + services + handlers obligatoires
- cas nominal + erreur + invariants obligatoires


## Livrables attendus :

- Code complet des fichiers de test.
- Commandes npm à ajouter pour exécuter les tests.
- mets a jour, si besoin, le task.json
    créer une tâche VS Code dédiée “npm: test:domain” dans /.vscode/tasks.json.
- Si nécessaire, les dépendances de test à installer.
- Petit résumé final de la couverture métier obtenue.

## Contraintes techniques :

TypeScript strict.
Aucun décorateur NestJS.
Aucun accès DB, HTTP ou framework.
Pas de refactor fonctionnel du domaine sans justification.
''';
