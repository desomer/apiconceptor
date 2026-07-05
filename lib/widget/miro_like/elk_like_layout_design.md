# Conception finale auto layout Mermaid Like (choix recommandé)

## 1. Références Git Mermaid prises en compte

Le design ci dessous suit les moteurs réellement utilisés dans Mermaid :

- Mermaid flowchart supporte Dagre et ELK ; ELK est recommandé pour graphes larges et complexes.
- Mermaid expose un renderer flowchart configurable (dagre d3, dagre wrapper, elk).
- Mermaid expose des réglages de qualité liés au layout : nodeSpacing, rankSpacing, optimizeRanksByCrossings.
- Côté ELK, Mermaid expose des options de stabilité d ordre modèle : forceNodeModelOrder et considerModelOrder.

Conclusion pratique : le meilleur choix est un pipeline hybride Sugiyama + contraintes dures + réparation de routage, avec sélection adaptative Dagre Like ou ELK Like selon la complexité.

## 2. Choix d algorithme (meilleur compromis qualité temps)

Approche recommandée : Hybrid Layered Constraint Layout.

1. Base layered type Sugiyama (Dagre Like).
2. Mode ELK Like pour cas complexes (beaucoup de croisements potentiels, subgraphs imbriqués, densité forte).
3. Post optimisation géométrique sous contraintes dures :
	- aucun overlap noeud noeud,
	- aucun non membre dans un subgraph,
	- minimisation forte des edge crossings,
	- minimisation des edge over node.

Pourquoi ce choix :

- Force directed pur est trop instable pour les contraintes de subgraphs et la reproductibilité.
- Sugiyama seul est rapide mais insuffisant sur les graphes denses avec contraintes fortes de routing.
- ELK seul peut être coûteux et peut produire des sorties qui nécessitent une réparation locale selon les règles produit.
- Hybride permet robustesse visuelle et contrôle fin par profils.

## 3. Pipeline algorithmique complet

### 3.1 Préparation

Entrées :

- Nodes avec tailles.
- Edges orientées et non orientées utiles à la métrique.
- Subgraphs et hiérarchie parent enfant.
- Seeds facultatives.
- Contraintes globales : padding, nodeSpacing, layerSpacing.

Étapes :

1. Nettoyage et déduplication des arêtes.
2. Construction voisins, degrés, tailles.
3. Normalisation des groupes de subgraph.

### 3.2 Layout principal

1. Bris de cycles (feedback arc set glouton).
2. Assignation de couches (longest path avec passes de rééquilibrage).
3. Minimisation de croisements inter couches (median barycenter + swaps locaux).
4. Placement des coordonnées.
5. Packing des composants et sous graphes.
6. Résolution overlap noeud noeud et overlap subgraph subgraph.

### 3.3 Contraintes dures après layout

1. Exclusion stricte des non membres de subgraph.
2. Anti edge over node.
3. Réduction des crossings par passes locales.
4. Réparation de routage plus agressive si crossing bloqué.
5. Uncross forcé par kick d endpoint si nécessaire.

### 3.4 Alignement et compaction

1. Alignement top top et left left selon priorité.
2. Mode dense : compaction des paires liées et internes aux subgraphs.
3. Re passage overlap + exclusion subgraph pour conserver la validité.

### 3.5 Arbitrage seed

Si seed active, accepter ou rejeter la sortie selon règles multi critères.

Important : pour éviter de restaurer systématiquement une géométrie croisée, introduire ce garde fou :

- si crossings de la solution seed dépasse un seuil et que la solution calculée réduit crossings sans violer les contraintes dures critiques, ne pas restaurer seed.

## 4. Fonction objectif et priorités

Utiliser une fonction objectif lexicographique pondérée :

1. edgeCrossings (priorité maximale),
2. edgeOverNodeHits,
3. nodeOverlapPairs,
4. subgraphMembershipViolations,
5. edgeLength total,
6. alignment penalties.

Règle d arbitrage recommandée :

- par défaut : crossings avant edge over node,
- si un profil strict routing est activé : edge over node avant crossings,
- dans tous les cas : node overlap et violation de subgraph sont des contraintes dures, jamais acceptées à la hausse au stade final.

## 5. Règles de routage d arêtes

Routage polyligne orthogonal recommandé.

Étapes :

1. Segment source vers canal de sortie.
2. Segment principal dans un canal libre.
3. Segment d entrée vers cible.

Règles :

- Interdire intersection segment rectangle de noeud hors endpoints.
- Pour arêtes longues inter couches, réserver des canaux par bande et trier les arêtes par ordre local pour limiter tresses.
- Si conflit persiste : déplacer endpoint le moins connecté (uncross forcé) puis rerouter localement.

## 6. Gestion des subgraphs

1. Calculer bounds de chaque subgraph depuis ses membres + padding.
2. Pour hiérarchie, packer récursivement de l intérieur vers l extérieur.
3. Appliquer exclusion stricte : un non membre ne peut pas intersecter les bounds d un subgraph.
4. Autoriser alignement interne configurable (top top, left left) tant que crossings globaux n explosent pas.

## 7. Heuristiques anti crossing retenues

Niveau 1 : median barycenter et swaps locaux en couches.

Niveau 2 : réduction locale des crossings par déplacement d arête (translation ou endpoint only).

Niveau 3 : réparation de routage par mouvement de noeuds candidats avec scoring global.

Niveau 4 : uncross forcé déterministe sur paires croisées (kick endpoint faible degré).

Tradeoff :

- niveaux 1 et 2 rapides,
- niveaux 3 et 4 plus coûteux mais nécessaires pour sortir de minima locaux sur graphes denses.

## 8. Paramètres réglables recommandés

Paramètres de base :

- nodeSpacing
- layerSpacing
- padding
- maxPassesCrossing
- maxPassesRoutingRepair
- maxPassesForceUncross

Poids objectifs :

- wCrossings
- wEdgeOverNode
- wNodeOverlap
- wSubgraphViolation
- wEdgeLength
- wAlignment

Stabilité seed :

- seedPenaltyTolerance
- seedLengthTolerance
- seedCrossingOverrideThreshold

Profils conseillés :

1. Fast : peu de passes, pas de force uncross.
2. Balanced : passes locales + routing repair.
3. Strict Routing : force uncross actif, priorités dures routing.
4. Dense : compaction forte + anti crossing renforcé.

## 9. Complexité

Notations :

- n nombre de noeuds,
- m nombre d arêtes,
- p nombre de passes.

Ordres principaux :

- Layering et ordering : environ O(p * m log n) selon implémentation.
- Comptage crossings naïf : O(m²).
- Routing repair par candidats : O(p * n * C * m²) (C = nb candidats déplacement).
- Uncross forcé : O(p * m² * K * m²) naïf ; en pratique réduit par early stop et limites de taille.

Recommandation perf :

- utiliser index spatial pour edge over node,
- limiter niveaux 3/4 aux graphes petits à moyens,
- couper tôt si crossings atteint 0.

## 10. Version optimisation itérative (boucle pratique)

Boucle globale recommandée :

1. Layout principal.
2. Évaluer score S.
3. Appliquer opérateurs locaux (align, compaction, anti edge over node, anti crossing).
4. Réévaluer S.
5. Accepter si S diminue selon ordre lexicographique.
6. Arrêter sur stagnation, budget temps, ou crossings = 0 et violations dures = 0.

Critère d arrêt robuste :

- aucune amélioration sur k passes,
- ou budget itérations atteint,
- ou objectif cible atteint.

## 11. Choix final recommandé pour ce projet

Le meilleur choix pour ce codebase est :

1. Pipeline layered ELK.
2. Contrainte dure exclusion non membres subgraph.
3. Priorité objective crossings puis edge over node, avec bascule profil strict si demandé.
4. Garde seed intelligent pour ne pas restaurer une solution trop croisée.
5. Étages de réparation gradués :
	- reduceEdgeCrossings,
	- repairRoutingByNodeMoves,
	- forceUncrossByEndpointKick.

Cette stratégie est cohérente avec la pratique Mermaid (Dagre par défaut, ELK pour cas complexes) et couvre les exigences produit de stabilité visuelle, contraintes subgraph et qualité de routage.

## 12. Matrice de décision prête à coder

### 12.1 Variables à mesurer à chaque layout

- n = nombre de noeuds
- m = nombre d arêtes
- crossingCountSeed = crossings sur seed
- crossingCountCandidate = crossings sur layout candidat
- edgeOverNodeSeed = edge over node sur seed
- edgeOverNodeCandidate = edge over node sur candidat
- hardViolationSeed = node overlap + subgraph violation sur seed
- hardViolationCandidate = node overlap + subgraph violation sur candidat
- density = m / max(1, n)

### 12.2 Choix renderer (Dagre Like vs ELK Like)

Utiliser ELK Like si au moins une condition est vraie :

1. n >= 45
2. m >= 70
3. density >= 1.6
4. subgraph imbriqué profondeur >= 2
5. nombre de subgraphs >= 3

Sinon, utiliser Dagre Like.

Règle de fallback dynamique :

- si renderer choisi donne crossingCountCandidate > max(4, 0.08 * m), relancer une fois avec ELK Like.

### 12.3 Activation des passes de réparation

Activer reduceEdgeCrossings si :

- crossingCountCandidate >= 1

Activer repairRoutingByNodeMoves si :

- crossingCountCandidate >= 2
- ou edgeOverNodeCandidate >= 1

Activer forceUncrossByEndpointKick si :

- crossingCountCandidate >= 3
- ou repairRoutingByNodeMoves n a pas réduit crossings sur 2 passes consécutives.

### 12.4 Bypass seed fallback (règle anti restauration toxique)

Ne pas restaurer seed si toutes les conditions suivantes sont vraies :

1. hardViolationCandidate <= hardViolationSeed
2. crossingCountCandidate <= crossingCountSeed - 1
3. edgeOverNodeCandidate <= edgeOverNodeSeed + 1
4. totalEdgeLengthCandidate <= totalEdgeLengthSeed * 1.35

Bypass forcé encore plus strict (profil strict routing) :

- si crossingCountSeed >= 3 et crossingCountCandidate < crossingCountSeed, ignorer gate_rejected.

### 12.5 Profil par mode utilisateur

Fast :

- reduceEdgeCrossings oui
- repairRoutingByNodeMoves non
- forceUncrossByEndpointKick non
- maxPassesCrossing 4

Balanced :

- reduceEdgeCrossings oui
- repairRoutingByNodeMoves oui
- forceUncrossByEndpointKick si crossings >= 4
- maxPassesCrossing 8
- maxPassesRoutingRepair 10

Dense :

- compaction active
- reduceEdgeCrossings oui
- repairRoutingByNodeMoves oui
- forceUncrossByEndpointKick si crossings >= 3
- maxPassesRoutingRepair 16
- maxPassesForceUncross 18

Strict Routing :

- edge over node prioritaire
- reduceEdgeCrossings oui
- repairRoutingByNodeMoves oui
- forceUncrossByEndpointKick oui dès crossings >= 2
- seed fallback bypass actif

### 12.6 Pseudocode de pilotage

1. Choisir renderer via 12.2
2. Calculer layout candidat
3. Mesurer métriques seed et candidat
4. Appliquer reduceEdgeCrossings si nécessaire
5. Appliquer repairRoutingByNodeMoves si nécessaire
6. Appliquer forceUncrossByEndpointKick si nécessaire
7. Réévaluer métriques
8. Décider restore seed ou keep layout via 12.4
9. Appliquer post passes dures : overlap, subgraph exclusion, edge over node
10. Retourner layout final

### 12.7 Logs obligatoires pour tuning

Ajouter ces audits systématiquement :

- stage=renderer_choice renderer=... n=... m=... density=...
- stage=seed_compare crossingsSeed=... crossingsCandidate=...
- stage=seed_compare edgeOverNodeSeed=... edgeOverNodeCandidate=...
- stage=seed_decision bypass=true|false reason=...
- stage=force_uncross acceptedMoves=... crossings=...

### 12.8 Valeurs initiales recommandées

- maxPassesCrossing = 10
- maxPassesRoutingRepair = 14
- maxPassesForceUncross = 24
- seedCrossingOverrideThreshold = 3
- seedLengthMaxFactorWhenBypass = 1.35

Ces seuils sont volontairement orientés qualité visuelle sur petits graphes flowchart, puis peuvent être abaissés pour des contraintes temps strictes.