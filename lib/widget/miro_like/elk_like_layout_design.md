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
6. Contrainte dure de gap noeud bord de subgraph (interne et externe).

Definition de la contrainte de gap :

- Noeud interne : distance minimale entre le rectangle du noeud et le bord interne du subgraph parent >= minInnerGapSubgraph.
- Noeud externe : distance minimale entre le rectangle du noeud et le bord externe de tout subgraph non parent >= minOuterGapSubgraph.
- Subgraphs imbriques : le gap effectif se calcule par niveau, avec accumulation de padding et marges minimales sur chaque ancetre traverse.

### 3.4 Alignement et compaction

1. Alignement top top et left left selon priorité.
2. Mode dense : compaction des paires liées et internes aux subgraphs.
3. Re passage overlap + exclusion subgraph pour conserver la validité.

### 3.5 Arbitrage seed

Si seed active, accepter ou rejeter la sortie selon règles multi critères.

Important : pour éviter de restaurer systématiquement une géométrie croisée, introduire ce garde fou :

- si crossings de la solution seed dépasse un seuil et que la solution calculée réduit crossings sans violer les contraintes dures critiques, ne pas restaurer seed.

### 3.6 Phase finale d alignement inter noeuds (lignes et colonnes)

Objectif : appliquer une passe d alignement globale apres le layout et les reparations, en alignant des noeuds en ligne (axe Y commun) et en colonne (axe X commun), independamment de leur appartenance a un subgraph.

Regles de priorite (obligatoires) :

1. Cette phase ne doit jamais degrader les contraintes dures de post optimisation geometrique.
2. Interdiction d introduire un overlap noeud noeud.
3. Interdiction d introduire une violation d exclusion de subgraph (non membre dans bounds).
4. Interdiction d augmenter edge over node au dela d un seuil profil.
5. Si un alignement degrade les contraintes dures, le mouvement est rejete (rollback local).
6. Si un alignement viole le gap minimal noeud bord de subgraph (interne ou externe), le mouvement est rejete.

Strategie recommandee :

1. Construire des groupes candidats d alignement horizontal et vertical depuis les liens, proximites et intentions UI.
2. Evaluer chaque groupe avec un score local (crossings, edge over node, longueur totale, deplacement total).
3. Appliquer des snaps progressifs (petits deltas) sur axe X ou Y.
4. Re verifier immediatement les contraintes dures apres chaque snap.
5. Valider uniquement les snaps qui preservent les contraintes dures et ameliorent le score lexicographique.

Sortie attendue :

- des colonnes et lignes visuellement stables,
- aucun relachement des contraintes dures,
- compatibilite totale avec noeuds internes et externes aux subgraphs.

### 3.7 Contraintes de fidelite Mermaid (hors direction stricte)

Objectif : reproduire le comportement Mermaid flowchart sur la stabilite visuelle et la lecture, sans activer de mode direction stricte supplementaire.

Regles ajoutees :

1. Preserver l ordre declaratif Mermaid intra couche tant que le gain de crossing reste marginal.
2. Respecter une contrainte de longueur minimale de lien (min rank span) avant optimisation fine.
3. Reserver une bande titre dans les bounds des subgraphs pour eviter collision label/noeuds/edges.
4. Gerer explicitement self loops et multi edges paralleles pour eviter oscillations et fusions visuelles.
5. Inserer des points dummy pour labels d aretes longues afin de stabiliser le routing.

## 4. Fonction objectif et priorités

Utiliser une fonction objectif lexicographique pondérée :

1. edgeCrossings (priorité maximale),
2. edgeOverNodeHits,
3. nodeOverlapPairs,
4. subgraphMembershipViolations,
5. edgeLength total,
6. declarationOrderInversions,
7. minRankSpanViolations,
8. selfLoopAndParallelEdgePenalties,
9. alignment penalties.

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
- Self loop : router en boucle externe avec rayon minimal et eviter overlap sur le noeud source.
- Multi edges : appliquer un ecartement minimal constant entre aretes paralleles partageant la meme paire de noeuds.
- Labels d aretes longues : inserer un point dummy de stabilisation si la longueur depasse un seuil.

## 6. Gestion des subgraphs

1. Calculer bounds de chaque subgraph depuis ses membres + padding.
2. Pour hiérarchie, packer récursivement de l intérieur vers l extérieur.
3. Appliquer exclusion stricte : un non membre ne peut pas intersecter les bounds d un subgraph.
4. Autoriser alignement interne configurable (top top, left left) tant que crossings globaux n explosent pas.
5. Appliquer un gap minimal noeud bord pour les noeuds membres (distance au bord interne) et non membres (distance au bord externe).
6. En cas de subgraphs imbriques, calculer la marge minimale par chaine d ancetres et valider le gap a chaque niveau.
7. Reserver subgraphTitleBandHeight + subgraphTitlePadding en tete de chaque subgraph, y compris en imbrication.
8. Evaluer les contraintes de gap noeud bord sur la surface utile (hors bande titre reservee).

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
- maxPassesFinalAlignment
- alignmentSnapToleranceX
- alignmentSnapToleranceY
- alignmentMaxNodeShift
- minInnerGapSubgraph
- minOuterGapSubgraph
- nestedSubgraphGapAccumulator
- preserveDeclarationOrder
- crossingSwapMinGain
- edgeMinRankSpanDefault
- subgraphTitleBandHeight
- subgraphTitlePadding
- selfLoopMinRadius
- parallelEdgeSeparation
- edgeLabelDummyThreshold

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
- subgraphBorderGapViolationsSeed = violations gap noeud bord sur seed
- subgraphBorderGapViolationsCandidate = violations gap noeud bord sur candidat
- declarationOrderInversionsSeed = inversions ordre declaratif sur seed
- declarationOrderInversionsCandidate = inversions ordre declaratif sur candidat
- minRankSpanViolationsSeed = violations longueur minimale lien sur seed
- minRankSpanViolationsCandidate = violations longueur minimale lien sur candidat
- subgraphTitleOverlapViolationsSeed = collisions dans bande titre sur seed
- subgraphTitleOverlapViolationsCandidate = collisions dans bande titre sur candidat
- selfLoopOverlapHitsCandidate = collisions self loop sur candidat
- parallelEdgeMergeHitsCandidate = fusions visuelles multi edges sur candidat
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

Mermaid Compatible :

- preserveDeclarationOrder actif
- min rank span actif
- title band subgraph active
- self loop et multi edges avec separation dediee
- compaction limitee si elle augmente declarationOrderInversions

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
4. Appliquer contrainte ordre declaratif et min rank span avant crossings
5. Appliquer reduceEdgeCrossings si nécessaire
6. Appliquer repairRoutingByNodeMoves si nécessaire
7. Appliquer forceUncrossByEndpointKick si nécessaire
8. Appliquer routing self loop et multi edges (ecartement + dummy labels)
9. Réévaluer métriques
10. Décider restore seed ou keep layout via 12.4
11. Appliquer phase finale alignement lignes/colonnes inter subgraph (3.6)
12. Re appliquer post passes dures : overlap, subgraph exclusion, edge over node, gap noeud bord subgraph, bande titre subgraph
13. Retourner layout final

### 12.7 Logs obligatoires pour tuning

Ajouter ces audits systématiquement :

- stage=renderer_choice renderer=... n=... m=... density=...
- stage=seed_compare crossingsSeed=... crossingsCandidate=...
- stage=seed_compare edgeOverNodeSeed=... edgeOverNodeCandidate=...
- stage=seed_decision bypass=true|false reason=...
- stage=force_uncross acceptedMoves=... crossings=...
- stage=final_alignment axis=x|y acceptedMoves=... rejectedMoves=... hardViolations=...
- stage=final_alignment groups=... snapToleranceX=... snapToleranceY=...
- stage=subgraph_gap innerViolations=... outerViolations=... nestedViolations=...
- stage=subgraph_gap minInnerGap=... minOuterGap=... nestedAccumulator=...
- stage=model_order preserved=... inverted=... swapMinGain=...
- stage=min_rank_span violations=... edgeMinRankSpanDefault=...
- stage=subgraph_title_band collisions=... titleBandHeight=... titlePadding=...
- stage=self_loop routingApplied=... overlapHits=... minRadius=...
- stage=parallel_edges bundles=... mergeHits=... separation=...

### 12.8 Valeurs initiales recommandées

- maxPassesCrossing = 10
- maxPassesRoutingRepair = 14
- maxPassesForceUncross = 24
- maxPassesFinalAlignment = 12
- alignmentSnapToleranceX = 6
- alignmentSnapToleranceY = 6
- alignmentMaxNodeShift = 18
- minInnerGapSubgraph = 12
- minOuterGapSubgraph = 10
- nestedSubgraphGapAccumulator = additive
- preserveDeclarationOrder = true
- crossingSwapMinGain = 2
- edgeMinRankSpanDefault = 1
- subgraphTitleBandHeight = 24
- subgraphTitlePadding = 8
- selfLoopMinRadius = 18
- parallelEdgeSeparation = 10
- edgeLabelDummyThreshold = 280
- seedCrossingOverrideThreshold = 3
- seedLengthMaxFactorWhenBypass = 1.35

Ces seuils sont volontairement orientés qualité visuelle sur petits graphes flowchart, puis peuvent être abaissés pour des contraintes temps strictes.