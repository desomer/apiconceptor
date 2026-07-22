String promptTest = ''' 
# Contexte techniques :  
Tu es un expert TypeScript, DDD et tests unitaires.
Je veux que tu génères (ou modifies) et implémentes les tests unitaires de la couche domaine de mon module <{{module}}> suivant cette spécification :.

{{definition du domaine}}

## Contexte du code source : 
- Le domaine est déjà défini.

Objectif :
Couvrir 100% des règles métier du domaine (pas de tests e2e, pas d'infra, pas de NestJS).
Tester uniquement les comportements métier et les invariants.
Utiliser une approche claire Arrange / Act / Assert.
Périmètre à tester :
- Aggregate
- Entity 
- Value Object
- Domain Service
- Erreurs métier avec neverthrow (Result ok/err)

## Exigences de test :

- les cas nominaux
- les cas invalides

- propagation des erreurs repository
- logger appelé sur succès
- Vérifier explicitement le contenu des erreurs (code + message), pas seulement isErr.
- Ajouter des mocks/fakes simples pour repository et logger.
- Fournir des tests lisibles, isolés et déterministes.

## Livrables attendus :

- Arborescence de fichiers de test proposée.
- Code complet des fichiers de test.
- Commandes npm à ajouter pour exécuter les tests.
- mets a jour, si besoin, le task.json
- Si nécessaire, les dépendances de test à installer.
- Petit résumé final de la couverture métier obtenue.

## Contraintes techniques :

TypeScript strict.
Aucun décorateur NestJS.
Aucun accès DB, HTTP ou framework.
Pas de refactor fonctionnel du domaine sans justification.
''';
