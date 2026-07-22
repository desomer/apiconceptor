String promptPersistence = '''
# Contexte techniques :  
Tu es un expert en architecture hexagonale, NestJS et MongoDB.
Ajoute ou modifie la couche **Infrastructure → Persistence (MongoDB)** <{{module}}> suivant cette spécification :

{{definition du domaine}}

## Contexte de code source :
- Le domaine est déjà défini.
- Les ports de repository sont dans : core/<module>/domain/repository-ports/
- Le repository MongoDB doit implémenter ces ports.
- n'ajoute pas de controle déja present dans le domaine, mais tu peux ajouter des validations techniques si nécessaire.

## Contraintes techniques :
- Utiliser NestJS uniquement dans l'infrastructure.
- Utiliser MongoDB via Mongoose.
- Respecter strictement les interfaces du domaine.
- Ne jamais mettre de logique métier dans l'infrastructure.
- Mapper correctement :
  - Domain → Persistence
  - Persistence → Domain
- Ne jamais retourner un domaine invalide (respect des invariants métier).
- Le repository doit être une classe NestJS annotée avec @Injectable().
- Le module doit fournir :
  - Schema MongoDB
  - Model Mongoose
  - Repository implémentant le port
  - Mappers
  - Module NestJS pour assembler le tout
- Génère ou réutilise les classes si elles existent déjà dans le domaine.
- un port Logger (pour pipo) pour le debug log de la base de données
- utilise Neverthrow pour les erreurs  

## Format attendu :
1. Arborescence complète :
   infrastructure/<module>/repositories/
   infrastructure/<module>/schemas/
   infrastructure/<module>/mappers/
   infrastructure/<module>/<module>.module.ts

2. Code complet pour :
   - Schema MongoDB
   - Repository MongoDB (implémentation du port)
   - Mappers (domain ↔ persistence)
   - Module NestJS

3. Explication du câblage :
   - Injection du modèle MongoDB
   - Injection du repository dans les use cases
   - Rôle de chaque fichier

4. Bonus :
   - Conseils pour éviter les pièges MongoDB dans l'hexagonal
   - Comment garantir les invariants métier côté persistance
   ''';