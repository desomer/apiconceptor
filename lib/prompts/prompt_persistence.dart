import 'package:jsonschema/prompts/prompt_header.dart';

String promptPersistence = '''
---
$promptHeader
---

# Contexte techniques :  
Tu es un expert en architecture hexagonale, NestJS et MongoDB.
Ajoute ou modifie la couche **Infrastructure → Persistence (MongoDB)** <{{module}}> suivant cette spécification :

{{spec}}

## Contexte de code source :
- Le domaine est déjà défini.
- Les ports de repository sont dans : core/<module>/ports/repositories
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


CONTRAT TECHNIQUE ET RÈGLES STRUCTURALES :

1. SCHÉMA MONGOOSE & INDEXATION :
   - Définis un schéma Mongoose (`@Schema()`) dans son propre fichier.
   - Utilise une `string` pour le champ `_id` (pas d'ObjectId native Mongo, les IDs sont gérés côté Domaine sous forme d'UUID).
   - Configure le schéma avec `timestamps: true` et active `versionKey: '__v'` (pour le verrouillage optimiste).
   - DÉCLARATION DES INDEX ET UNICITÉ :
     - Champs uniques simples : Déclare `@Prop({ unique: true, index: true })`.
     - Champs uniques optionnels/nullables : Utilise `sparse: true` ou `partialFilterExpression` pour éviter les conflits sur les valeurs nulles/absentes.
     - Index composés (multi-champs) : Déclare-les au niveau du schéma via `Schema.index({ field1: 1, field2: 1 }, { unique: true })`.
     - Ajoute les index de recherche simples non-uniques (`index: true`) sur les clés étrangères/IDs de rattachement.

2. MAPPER (Domain <-> Mongo) :
   - Crée un Mapper statique pur (ex: `[Entity]Mapper`).
   - Méthode `toDomain(raw: [Entity]MongoEntity): [Entity]` : Reconstitue l'entité métier.
   - Méthode `toPersistence(domain: [Entity]): [Entity]MongoEntity` : Extrait les données primitives du Domaine (y compris l'extraction des Value Objects).

3. REPOSITORY MONGOOSE (Adaptateur) :
   - Implémente le Port (Interface) défini par le Domaine.
   - Injecte le Modèle Mongoose via `@InjectModel()`.
   - Utilise OBLIGATOIREMENT `.lean()` sur toutes les requêtes en lecture (ex: `find`, `findById`) pour éviter la fuite du prototype Mongoose.
   - Gère le verrouillage optimiste lors des mises à jour (`updateOne` avec vérification du `__v` et `\$inc: { __v: 1 }`).
   - GESTION FINE DE L'UNICITÉ ET CODE 11000 :
     - Intercepte les erreurs avec `error.code === 11000` (Duplicate Key).
     - Inspecte `error.keyPattern` ou `error.keyValue` pour identifier PRÉCISÉMENT quel champ ou combinaison de champs a provoqué le doublon.
     - Lève l'exception Domaine spécifique associée à ce champ (ex: si le champ en conflit est `email` -> lever `EmailAlreadyInUseException`).
     - Gère les conflits de concurrence d'update (ex: `matchedCount === 0`) -> lever `ConcurrencyException`.

   - GESTION DES AUTRES CODES D'ERREUR MONGODB :
      Code 121 — DocumentValidationFailure
      Cause : Les données envoyées ne respectent pas le JSON Schema Validation défini directement sur la collection MongoDB (côté serveur BDD).
      Traduction Métier : InvalidDataException ou DomainValidationException.
      Utilisation : Si tu as configuré des contraintes de validation directement dans MongoDB.

      Code 112 — WriteConflict
      Cause : Deux transactions concurrentes ont essayé de modifier le même document en même temps au niveau du moteur de stockage WiredTiger.
      Traduction Métier : ConcurrencyException ou RetryableOperationException.
      Utilisation : Utile si tu utilises des transactions ACID multi-documents dans MongoDB (session.withTransaction()).

      Code 50 — ExceededTimeLimit / MaxTimeMSExpired
      Cause : L'opération a dépassé le temps limite défini par `maxTimeMS`.
      Traduction Métier : TimeoutException ou RetryableOperationException.
      Utilisation : Utile pour les opérations longues sur de grandes collections.


4. INJECTION DE DÉPENDANCE NESTJS :
   - Fournis le snippet du module NestJS (`[Entity]InfrastructureModule`) montrant le provider avec le token du Port (`{ provide: PORT_TOKEN, useClass: RepositoryImpl }`).


# MODE STRICT - CONTRAINTES BLOQUANTES

Tu dois appliquer ces règles AVANT de coder.  
Si une seule règle ne peut pas être respectée, STOP, n’écris aucun fichier, et demande validation.

## 1) Arborescence obligatoire (hard requirement)
Tous les fichiers créés/modifiés DOIVENT être uniquement sous :

src/infrastructure/<module>/outbound/persistence/repositories/
src/infrastructure/<module>/outbound/persistence/read-model/  #lecture complexe multi aggregates optimisée si port existe
src/infrastructure/<module>/outbound/persistence/schemas/
src/infrastructure/<module>/outbound/persistence/mappers/
src/infrastructure/<module>/<module>.module.ts

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
- [ ] Schema MongoDB
- [ ] Repository MongoDB (implémentation du port)
- [ ] Mappers (domain ↔ persistence)
- [ ] Module NestJS
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

String promptModelDesc = '''
ENTRÉES FOURNIES :

--- ENTITÉ/AGRÉGAT DOMAINE ---
[Colle le code de ton Entité / Aggregate Domaine ici]

--- PORT DE REPOSITORY (INTERFACE) ---
[Colle l'interface TypeScript de ton Port de Repository ici]

--- RÈGLES D'UNICITÉ ET INDEX SOUHAITÉS ---
- Champs uniques simples : [ex: email, username]
- Champs uniques optionnels (sparse) : [ex: phoneNumber]
- Index composés d'unicité : [ex: (organizationId + slug)]
- Index de recherche : [ex: ownerId]

--- EXCEPTIONS DU DOMAINE DISPONIBLES ---
[Liste ou colle tes exceptions métier, ex: EmailAlreadyInUseException, SlugAlreadyExistsException, ConcurrencyException]

Génère un code propre, fortement typé, sans raccourcis, prêt pour la production et réparti dans des fichiers distincts bien identifiés.
''';
