
String promptModel = '''
# Contexte techniques :  
Tu es un expert en architecture hexagonale et en DDD.  
Ajoute ou modifie la couche **Domaine** pour le module <{{module}}> suivant cette spécification :

{{definition du domaine}}

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
 
  2. Le dossier services :
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

# Format attendu :
- Arborescence des fichiers de type
   src/
     core/                # Domaine pur (DDD)
       <module>/
            ports/
              logger/
              repositories/ 
            domain/
              aggregates/
              entities/
              value-objects/
              services/       # services métier stateless
              errors/      

- Explications des choix métier''';