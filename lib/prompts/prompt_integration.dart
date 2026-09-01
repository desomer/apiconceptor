String promptIntegration = '''
Intègre (ou met à jour) les couches Infrastructure MongoDB, Application (usecase) et Interface HTTP du module <{{MODULE}}> dans l’application NestJS existante.

Contexte :
- Le domaine et l'infrastructure <{{MODULE}}> existent déjà.
- La couche application/usecase <{{MODULE}}> existe déjà.
- La couche interface HTTP <{{MODULE}}> existe déjà.
- Le repository MongoDB implémente le port du domaine via le token xxxxx_REPOSITORY_PORT.

À faire :
1. Modifier AppModule pour importer :
   - MongooseModule.forRoot(...) avec une configuration propre et centralisée
   - l'infrastructure du module <{{MODULE}}>
   - l'interface du module <{{MODULE}}>
2. Vérifier que le repository MongoDB est bien injectable via xxxx_REPOSITORY_PORT dans les use cases / handlers applicatifs.
3. Vérifier que les providers nécessaires aux use cases sont bien câblés :
   - repository port
   - logger port
   - event bus applicatif
   - read model port
4. Vérifier que la couche interface peut injecter correctement :
   - command bus / query bus
   - handlers applicatifs
   - adapters read model
   - logger pino
   - model Mongoose nécessaire aux adapters
5. Ajouter un contrôle d'injection explicite :
   - s'assurer que tous les tokens exportés par les modules infrastructure sont bien exportés/importés là où ils sont consommés
   - ajouter un contrôle simple au bootstrap ou au module pour détecter rapidement les dépendances manquantes
   - éviter les injections implicites fragiles quand un token explicite est nécessaire
   - si `emitDecoratorMetadata` est désactivé, utiliser `@Inject(...)` explicitement pour tous les providers sensibles (ex: `PinoLogger`, tokens Symbol, adapters, handlers injectés par classe si nécessaire)
   - importer explicitement `LoggerModule` dans les modules NestJS qui consomment `PinoLogger` (controllers, adapters, probes), ne pas supposer que l'import racine suffit toujours
   - pour les schémas Mongoose imbriqués, ne pas utiliser directement une classe dans `@Prop({ type: ... })` si cela casse au runtime ; générer et utiliser les sous-schémas via `SchemaFactory.createForClass(...)`
   - si un probe d'intégration dépend de tokens application + infrastructure, le déclarer dans le module qui importe effectivement tous ces tokens
6. Ne pas ajouter de logique métier dans l'infrastructure.
7. Ne pas toucher au domaine sauf si un ajustement de contrat est strictement nécessaire.
8. Garder du TypeScript pur côté domaine et respecter la structure hexagonale.

Contraintes techniques :
- NestJS uniquement dans l'infrastructure et l'interface.
- MongoDB via Mongoose.
- Les use cases / handlers applicatifs doivent rester sans dépendance NestJS.
- Les DTO et mappings HTTP restent dans la couche interface.
- Pas de logique de persistance dans le domaine.
- Pas de logique métier dans les controllers.
- Préserver la compatibilité runtime avec un projet lancé via `tsx`/watch et `emitDecoratorMetadata: false`.
- Considérer `emitDecoratorMetadata: false` comme un garde-fou d'architecture : le câblage doit rester explicite et ne jamais dépendre implicitement de la réflexion TypeScript pour fonctionner au runtime.
- Ne pas se contenter d'un build TypeScript vert si le bootstrap NestJS peut encore casser au runtime.

Livrable attendu :
- Les fichiers modifiés
- Une explication courte du câblage
- Une explication courte du contrôle d'injection mis en place
- Validation par build TypeScript
- Validation par bootstrap runtime minimum : l'application Nest démarre, les modules se chargent, les routes du module sont bien mappées, et le contrôle d'injection ne remonte aucune dépendance manquante
''';