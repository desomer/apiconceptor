# ARCHI v3

## Principes
- Le domaine contient uniquement la logique metier pure.
- L'application orchestre les cas d'usage.
- L'infrastructure implemente les details techniques.
- Les DTO existent uniquement aux frontieres.
- La structure privilegie la lisibilite et limite la profondeur des dossiers.

## Arborescence simplifiee

core/
  <module>/                # role: regroupe le noyau fonctionnel d'un domaine
    domain/                # role: logique metier pure sans dependance technique
      models/              # role: entites, value objects et regles proches du coeur
      services/            # role: logique metier transverse
      events/              # role: evenements du domaine
      errors/              # role: erreurs metier

    application/           # role: orchestration des cas d'usage
      commands/            # role: intentions d'ecriture
      queries/             # role: intentions de lecture
      sagas/               # role: processus longs ou distribues
      services/            # role: orchestration applicative
      events/              # role: evenements applicatifs
      errors/              # role: erreurs de cas d'usage

    ports/                 # role: contrats d'entree/sortie du core
      repositories/        # role: persistance
      gateways/            # role: services externes
      messaging/           # role: publication/consommation de messages
      storage/             # role: stockage objet (bucket, file)
      logging/             # role: journalisation

infrastructure/
  <module>/                # role: details techniques du module
    inbound/               # role: adaptateurs entrants
      http/                # role: transport HTTP
        <v1>/                # role: version d'API publique
          controllers/     # role: reception et orchestration transport
          dto/             # role: objets de transport entrants/sortants
      cli/                 # role: commandes en ligne
      scheduler/           # role: declenchement planifie

    outbound/              # role: adaptateurs sortants
      persistence/         # role: acces aux donnees
        repositories/      # role: implementations de persistance
        read-model/        # role: lectures optimisees
      external-api/        # role: integration de services externes
        clients/           # role: clients techniques HTTP ou SDK
      messaging/           # role: transport de messages
        consumers/        # role: consommation de messages
        publishers/       # role: publication de messages
      storage/             # role: acces au stockage objet
      logging/             # role: journalisation technique

    config/                # role: configuration du module

contracts/
  events/                  # role: contrats d'evenements inter-services
  api/                     # role: contrats d'API publiques

## Regles de placement
1. Le domaine ne depend jamais de l'infrastructure.
2. L'application appelle le domaine et les ports.
3. L'infrastructure implemente les ports et gere le transport.
4. Les DTO et mappers restent aux frontieres.
5. Une seule arborescence par responsabilite, pas de sous-decoupage inutile.

## Convention generale
- Garder des noms techniques en anglais pour les dossiers.
- Utiliser `v1`, `v2`, `v3` uniquement pour les contrats externes versionnes.
- Preferer des dossiers courts et stables plutot que des arborescences tres fines.