String promptCron = '''
# Contexte techniques :
Tu es un expert NestJS, MongoDB, Kubernetes et architectures distribuées.

Génère un module complet NestJS appelé "LockModule" qui implémente un design pattern de Distributed Lock pour exécuter une tâche cron une seule fois, même en environnement multi-pods Kubernetes.

Contraintes techniques :
- Backend : MongoDB
- Le lock doit être acquis via une opération atomique utilisant une transaction Mongo
- Le lock doit contenir : taskName, lockedBy, expiresAt
- lockedBy doit être le hostname du pod (process.env.HOSTNAME)
- expiresAt doit permettre un TTL automatique (index TTL)
- Le lock doit expirer automatiquement via expireAfterSeconds
- Le code doit inclure un système de retry avec exponential backoff pour l’acquisition du lock
- ne pas gerer le retryWrites=true de la connection mongo 
- Le code doit être robuste aux race conditions
- Le code doit être compatible avec un cluster Mongo répliqué
- Le code doit être idempotent
- Le code doit être entièrement typé TypeScript

Structure demandée :
1. LockModule
2. LockSchema (avec TTL index)
3. LockService
   - acquireLock(taskName: string, ttlSeconds: number)
   - utilise une transaction Mongo
   - utilise findOneAndUpdate ou updateOne avec session
   - retry + exponential backoff configurable
4. CronTaskService
   - @Cron('*/5 * * * *')
   - tente d’acquérir le lock
   - si lock obtenu → exécute executeTask()
   - sinon → log "lock not acquired"
5. Un exemple de configuration du TTL dans le schema
6. Un exemple de configuration du module Mongoose
7. Un exemple de test unitaire pour LockService

Livrables :
- Code complet, prêt à coller dans un projet NestJS
- Aucun placeholder, aucun pseudo-code
- Code propre, structuré, commenté
- Respect des bonnes pratiques NestJS
- Respect des bonnes pratiques MongoDB transactions
- Respect des bonnes pratiques Kubernetes multi-pods

Objectif final :
→ Avoir un design pattern complet permettant d’exécuter une tâche cron unique dans un cluster NestJS multi-pods grâce à un distributed lock Mongo robuste, transactionnel, avec retry + backoff.
''';
