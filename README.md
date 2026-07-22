https://alomana.com/research


# jsonschema

A new Flutter project.

## Getting Started

Roadmap Business Model 
- gestion du changement de type => retrait des prob
- gestion des tag  (sensible; personal; restricted)
- notion de propriétaire
- gestion de glossary pour eviter de nommer x fois la même notion
- pouvoir choisir les bloc a faire apparaitre des exemple de json / API
- faire un ticket de modification
- Knowledge Center

- gerer l'ordre de Object dans le swagger (Ordre identique au YAML)
- gerer le inputSearch apres une recherche
- remettre à page à 1 si rechercher
- attendre l'affectation asynchrone de param avant la recherche sur un btn 'load param' 
- logger les stacktrace des compute
- mettre le bug en mode text
- mettre en text les requetes volumineuse (avec Trunc)

API
- mettre en internal

https://github.com/google/diff-match-patch


Topic: order.created
  - subscription: billing-service
  - subscription: analytics-pipeline
  - subscription: fraud-detector
attrubut : 
    tenantId = "t123"
    eventType = "order.created"
    schemaVersion = "v2"
    traceId = "abc-123"
    orderingKey = "t123"

## Supabase Edge Function (delete-user)

Une fonction API minimaliste a ete ajoutee dans:
- supabase/functions/delete-user/index.ts

Configuration locale Supabase:
- supabase/config.toml

### Lancer en local

```bash
supabase start
supabase functions serve delete-user
```

### Tester l'API

```bash
curl -i -X POST http://127.0.0.1:54321/functions/v1/delete-user \\
  -H "Authorization: Bearer <ACCESS_TOKEN>" \\
  -H "Content-Type: application/json" \\
  -d '{"confirm":true}'
```

Suppression d'un autre utilisateur (admin uniquement):

```bash
curl -i -X POST http://127.0.0.1:54321/functions/v1/delete-user \\
  -H "Authorization: Bearer <ACCESS_TOKEN>" \\
  -H "Content-Type: application/json" \\
  -d '{"confirm":true,"user_id":"<USER_ID>"}'
```

### Appel depuis Flutter

La methode `callDeleteUserApi()` est disponible dans `lib/core/bdd/data_acces.dart`.

### Deployer

```bash
supabase functions deploy delete-user
```

### Appel en production

```bash
curl -i https://<PROJECT-REF>.supabase.co/functions/v1/delete-user
```
