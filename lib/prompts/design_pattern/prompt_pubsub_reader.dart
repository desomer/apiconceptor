String promptPubSubReader =
    '''
Rôle : Tu es un développeur expert NestJS, MongoDB (Mongoose) et architectures distribuées.

Objectif :
Rédige un module NestJS complet, typé et prêt pour la production pour consommer un service Pub/Sub avec limitation de débit distribuée (multi-pod), paramétrage Mongo par subscriber et routage automatique via un décorateur de méthode `@PubSubListener('subscriptionId')`.

Architecture et composants à fournir :

1. DÉCORATEUR ET EXPLORATEUR DE MÉTHODES :
   - Décorateur `@PubSubListener(subscriptionId: string)` utilisant `SetMetadata`.
   - Service `PubSubRegistryService` stockant la carte des handlers `Map<string, { instance, methodName }>`.
   - Service `PubSubExplorerService` implémentant `OnModuleInit`, utilisant `DiscoveryService`, `MetadataScanner` et `Reflector` pour scanner l'application et enregistrer automatiquement les méthodes annotées par `@PubSubListener`.

2. SCHÉMAS MONGOOSE :
   - `subscriber-config.schema.ts` : `subscriberId` (unique), `maxPerMinute` (number), `concurrency` (number), `isActive` (boolean).
   - `rate-limit-window.schema.ts` : `_id` composite (`\${subscriberId}-window-\${Math.floor(Date.now() / 60000)}`), `subscriberId`, `count`, `createdAt` avec index TTL (`expires: 120`).

3. SERVICES DU MODULE :
   - `subscriber-config.service.ts` : Récupère la config Mongo par `subscriberId` ou retourne une config fallback (`maxPerMinute: 3`, `concurrency: 2`, `isActive: true`).
   - `pubsub-rate-limiter.service.ts` :
     * `tryAcquireTokens(subscriberId, requestedAmount, maxPerMinute)` : Réservation atomique via `findOneAndUpdate` sur la clé de fenêtre isolée par subscriber. Gère les collisions 11000.
     * `refundTokens(subscriberId, amount)` : Rembourse les jetons non utilisés en cas de file vide/incomplète.
   - `cron-pull.service.ts` :
     * Lit `PUBSUB_SUBSCRIBER_ID` depuis les variables d'environnement.
     * `@Cron(CronExpression.EVERY_10_SECONDS)`
     * Maintient `activeJobs = 0`. Calcule `freeSlots = config.concurrency - activeJobs`.
     * Tente de réserver jusqu'à `freeSlots` jetons.
     * Effectue le Pull synchrone de `maxMessages = tokensAcquired`.
     * Rembourse les jetons inutilisés via `refundTokens`.
     * Pour chaque message : `activeJobs++`, exécute la méthode récupérée depuis `PubSubRegistryService`, effectue `message.ack()` en cas de succès, et décrémente impérativement `activeJobs--` dans un bloc `finally`.

4. EXEMPLE D'UTILISATION :
   - Fournis un exemple de classe `@Injectable()` montrant une méthode métier annotée avec `@PubSubListener('order-created-sub')`.

5. MODULE NESTJS (`pubsub-limiter.module.ts`) :
   - Module complet important `DiscoveryModule` de `@nestjs/core`, `ScheduleModule`, `ConfigModule` et `MongooseModule`.

Fournis le code TypeScript complet, typé, documenté et modulaire.
''';
