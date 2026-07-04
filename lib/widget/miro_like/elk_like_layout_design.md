# Moteur De Layout ELK-like (Flutter) - Conception Technique

Ce document decrit le pipeline de placement en couches implemente dans `auto_layout_engine.dart`, sous `_ElkLikeLayoutEngine`.

Perimetre:
- Placement de graphe oriente hierarchique dans Flutter.
- pas Contraintes de direction.
- Placement recursif avec prise en compte des subgraphs.
- Verification de routage orthogonal/polyline avec prise en compte des ports.
- Reduction des croisements et placement sans recouvrement de noeuds.

Note:
- Il s agit d une implementation ELK-like (famille Sugiyama), pas du code Java ELK exact.
- Le chemin de production est maintenant strictement ELK-like: le fallback legacy force-layout a ete retire de `AutoLayoutEngine.computeMermaidAutoLayout`.

## 1. Suppression Des Cycles

### 1.1 Suppression Gloutonne Des Cycles

Implementation: `_greedyFeedbackOrder` + reorientation des aretes dans `_breakCycles`.

Algorithme:
1. Construire les ensembles entrants/sortants.
2. Retirer iterativement les puits (ajoutes a droite).
3. Retirer les sources (ajoutees a gauche).
4. S il n y en a pas, retirer le sommet qui maximise `(outDegree - inDegree)`.
5. L ordre final est `left + reverse(right)`.
6. Toute arete qui va a l encontre de cet ordre est inversee.

Esquisse de correction:
- Un ordre total est produit.
- Les aretes reorientees verifient `rank(from) <= rank(to)`.
- L orientation finale est donc acyclique (aucun cycle ne peut exister dans un ordre topologique non decroissant).

Complexite:
- Version naive: `O(V^2 + E*V)` au pire, a cause des filtrages repetes.
- En pratique: comportement proche du lineaire sur des graphes clairsemes en couches.

### 1.2 Suppression Type Network Simplex

Implementation: `_networkSimplexLikeOrder` + reorientation dans `_breakCycles`.

Algorithme:
1. Initialiser des potentiels de noeuds a partir du desequilibre entrant/sortant.
2. Lisser iterativement les scores via les moyennes de voisinage (relaxation dual-like).
3. Trier les noeuds par potentiel.
4. Inverser les aretes qui violent cet ordre.

Esquisse de correction:
- Les aretes conservees/reorientees respectent un ordre total.
- Le graphe final est acyclique par construction.

Complexite:
- Relaxation: `O(I*(V+E))` pour `I` iterations (constante dans le code).
- Tri: `O(V log V)`.
- Reorientation: `O(E)`.

### 1.3 Detection Des Aretes A Inverser

Implementation dans `_breakCycles` en comparant les rangs des extremites.
- Si `rank(from) > rank(to)`, l arete est inversee et marquee `wasReversed = true`.

Cela permet de tracer explicitement les feedback arcs.

## 2. Assignation Des Couches

### 2.1 Longest Path Layering

Implementation dans `_assignLayers` (passe de base).

Algorithme:
1. Parcours topologique.
2. `layer[v] = max(layer[p] + 1)` pour tout predecesseur `p`.

Garantie:
- Pour chaque arete `(u,v)`, `layer[v] >= layer[u] + 1`.

Complexite:
- `O(V + E)`.

### 2.2 Layering Type Network Simplex (Pragmatique)

Implementation dans `_assignLayers` avec `_LayeringMethod.networkSimplex`.

Algorithme:
1. Partir des rangs longest-path.
2. Projeter iterativement chaque noeud dans un intervalle faisable:
   - borne basse des predecesseurs,
   - borne haute des successeurs.
3. Deplacer le rang vers le milieu de l intervalle (relaxation contrainte).

Garantie:
- Les contraintes de faisabilite sont preservees a chaque mise a jour.

Complexite:
- `O(I*(V+E))`, avec `I` constant dans l implementation.

### 2.3 Equilibrage De Couches Brandes-Kopf

Implementation par `_brandesKopfLayerBalance`.

Objectif:
- Reduire les couches surchargees en conservant les contraintes de precedence.

Methode:
- Pour chaque noeud, calculer l intervalle de rang faisable depuis les contraintes predecessor/successor.
- Deplacer vers des couches moins chargees quand c est possible.

Complexite:
- `O(P*(V+E))`, avec petit `P` fixe.


### 2.5 Subgraphs Dans Le Layering

Les subgraphs sont traites comme des noeuds composites a chaque niveau hierarchique:
- Layout interne d abord (recursif).
- Le composite prend une taille basee sur sa bounding box.
- Le graphe parent travaille avec composites + noeuds feuilles.

Les contraintes hierarchiques restent ainsi explicites pendant l assignation des rangs.

## 3. Minimisation Des Croisements

### 3.1 Heuristique Median

Utilisee dans `_orderByRef(..., useMedian: true)`.

- Score de position d un noeud = mediane des indices des voisins dans la couche de reference adjacente.
- Stable sur des voisinages asymetriques et robuste aux outliers.

Complexite par sweep:
- Tri + traitement de voisinage: proche de `O(E + V log V)`.

### 3.2 Heuristique Barycenter

Utilisee dans `_orderByRef(..., useMedian: false)`.

- Score = moyenne des indices des voisins.
- Plus sensible aux outliers, souvent efficace sur des topologies fluides.

### 3.3 Heuristique Greedy Switch

Implementation dans `_greedySwitchLayer`.

- Tester iterativement les swaps de paires adjacentes.
- Conserver le swap si le nombre local de croisements diminue.

Complexite:
- Cout local borne par un petit nombre de passes.
- Le pire cas (voisinages denses) peut couter cher, mais reste acceptable en taille editeur.

### 3.4 Layer Sweep (Haut->Bas Et Bas->Haut)

Implementation dans:
- `_buildOrderedLayers` (passes initiales).
- `_minimizeCrossingsMultiPhase` (passes alternees).

Schema:
1. Passe descendante avec la couche precedente comme reference.
2. Passe montante avec la couche suivante comme reference.

### 3.5 Optimisation Multi-phase

- Alternance median/barycenter selon les phases.
- Application de greedy switch a chaque phase.

Benefice:
- Sort plus facilement des minima locaux qu une seule passe.

### 3.6 Complexite Et Cas Pathologiques

Facteurs de pire cas:
- Connectivite bipartite dense inter-couches (type `K_{m,n}`).
- Nombreux ex aequo de score (symetrie), provoquant des permutations instables.
- Aretes longues traversant de nombreuses couches.

Mitigations implementees:
- Tie-breakers stables par id de noeud.
- Alternance median/barycenter.
- Amelioration locale gloutonne avec iterations bornees.

## 4. Placement Des Noeuds

### 4.1 Placement Inspire Brandes-Kopf

Implementation dans `_placeNodes`:
- Placement de base couche par couche avec ecarts dependants des tailles.
- Cible d alignement via mediane des voisins.

### 4.2 Compaction Type Network Simplex

Egalement dans `_placeNodes`:
- Compaction contrainte intra-couche avec inegalites:
  `x[j] - x[i] >= sep(i,j)` pour les noeuds consecutifs.
- Projection vers les cibles medianes tout en conservant l absence de recouvrement.

### 4.3 Gestion Des Ports

La preference de cote de port est modelee dans `_routeOrthogonalForResidualCheck`:
- Choix source/cible selon la geometrie relative.
- Offset de port applique depuis le bord des noeuds.

Au niveau UI, l assignation finale des ancres et le routage obstacle-aware restent geres dans le code de geometrie des liens existant.

### 4.4 Contraintes De Taille Minimale

Chaque sommet utilise sa taille explicite issue du modele (`sizeByNode`).
Toutes les contraintes d espacement/compaction sont size-aware.

### 4.5 Subgraphs Comme Noeuds Composites

Implementation dans `_layoutCluster`:
- Layout du subgraph enfant en premier.
- La bbox enfant + padding devient la taille du composite dans le parent.
- Le parent place le composite via sa position cible.
- Le contenu enfant est translate rigidement pour conserver son layout interne.

### 4.6 Strategies D Alignement

Pile actuelle:
1. Assignation coherente de la coordonnee primaire par couche.
2. Raffinement secondaire guide par mediane.
3. Compaction contrainte avec inegalites d espacement.
4. Resolution des recouvrements en post-placement.

### 4.7 Preference De Compacite Rectangulaire

Objectif:
- Privilegier une empreinte globale proche d un rectangle compact.
- Eviter un layout trop etire en largeur ou trop etire en hauteur.

Formulation (contrainte douce recommandee):
- Soit `W` la largeur de la bounding box globale et `H` sa hauteur.
- Definir un ratio `R = W / H`.
- Cibler un intervalle prefere, par exemple `R in [0.65, 1.60]`.
- Ajouter une penalite de forme a la fonction de cout:
  - penalite nulle si `R` est dans l intervalle cible,
  - penalite croissante quand `R` sort de l intervalle.

Implementation pratique:
1. Apres placement initial, calculer `W`, `H`, puis `R`.
2. Si `R` est trop grand (trop large), compacter l axe X ou etendre moderement Y.
3. Si `R` est trop petit (trop haut), compacter l axe Y ou etendre moderement X.
4. Reexecuter une passe courte de non-recouvrement pour conserver les separations minimales.

Priorite:
- Cette preference reste secondaire par rapport a:
  1. l acyclicite et les contraintes de direction,
  2. la minimisation des croisements,
  3. le non-recouvrement et les contraintes de subgraphs/ports.

Remarque:
- Il faut utiliser une contrainte souple (soft constraint), pas une contrainte dure,
  pour eviter de degrader fortement le routage ou la lisibilite des flux.

### 4.8 Alignement Opportuniste Haut/Haut Et Gauche/Gauche

Exigence:
- Ajouter une passe d alignement opportuniste `haut/haut` et `gauche/gauche`.
- Cette passe doit s appliquer:
  - entre subgraphs (imbriques ou non),
  - entre blocs appartenant a un meme subgraph.

Principe:
1. Detecter des candidats proches sur X/Y selon une tolerance d alignement.
2. Proposer des cibles communes:
  - `haut/haut` (meme coordonnee Y du bord haut),
  - `gauche/gauche` (meme coordonnee X du bord gauche).
3. Accepter uniquement les deplacements qui ne violent pas:
  - les contraintes de containment parent/enfant,
  - le non-recouvrement,
  - les contraintes de direction majeures.

Priorite et ordre de passe:
- Passe a executer en fin de layout (post-traitement), apres le placement principal et la compaction.
- Rester opportuniste: gain visuel d alignement recherche, sans forcer une degradation des autres contraintes.

## 5. Routage Des Aretes

### 5.1 Routage Orthogonal

Implementation en generation de candidats dans `_routeOrthogonalForResidualCheck`:
- Entree/sortie par le bord des noeuds selon le port.
- Candidats a un coude ou dog-leg.

### 5.2 Routage Polyline

Des alternatives polyline sont evaluees via des candidats de coude.
Cela prepare une extension future vers un plus court chemin exact sur grille d obstacles.

### 5.3 Evitement D Obstacles

Le routage global obstacle-aware reste dans la phase de geometrie UI.
Le coeur ELK-like conserve une generation orthogonale port-aware pour controler la pression de croisements residuels.

### 5.4 Routage Base Sur Les Ports

Les ports source/cible sont choisis depuis la relation directionnelle (`dx`, `dy`) et les normales de cote.

### 5.5 Minimisation Des Segments Et Croisements Residuels

Dans l implementation actuelle:
- Les candidats favorisent des structures courtes (moins de segments).
- Le layering + placement reduisent les croisements residuels avant le routage final des connecteurs.

## 6. Gestion Des Subgraphs

### 6.1 Layout Interne Recursif

Implementation par recursion `_layoutCluster` sur `_SubgraphHierarchy`.

### 6.2 Calcul De Bounding Box

Calcule via `_boundsOf` (padding configurable).

### 6.3 Placement Dans Le Graphe Parent

Les enfants deviennent des vertices composites dans le graphe parent aplati.
Le layout en couches parent retourne les centres cibles des composites.

### 6.4 Reajustement Global

Apres placement parent:
- Les noeuds enfants sont translates rigidement.
- Une resolution locale des recouvrements est appliquee sur le contenu du cluster.

### 6.5 Preservation Des Contraintes Hierarchiques

- La relation parent/enfant est construite par inclusion stricte d ensembles (`fromGroups`).
- Les noeuds enfants ne sont jamais detaches de leur enveloppe parent subgraph.
- Les subgraphs imbriques conservent la containment sur toute la recursion.

## Cas Difficiles Couverts

1. Maillages de dependances cycliques:
- detection de feedback arcs + inversion avant layering.

2. Hubs denses (fan-in / fan-out):
- minimisation multi-phase des croisements + lissage median.

3. Tailles de noeuds heterogenes:
- compaction size-aware + resolution des recouvrements.

4. Subgraphs imbriques:
- layout composite recursif.

5. Inversions de direction (`RL`/`BT`):
- support rangs + transformation de coordonnees.

6. Pression sur les ports et clutter residuel:
- generation orthogonale port-aware + routage obstacle-aware aval.

## Resume De Complexite

Soient `V` = noeuds, `E` = aretes, `L` = nombre de couches, `I` = iterations fixes.

- Suppression des cycles:
  - Glouton: jusqu a `O(V^2 + E*V)` (naif).
  - Type simplex: `O(I*(V+E) + V log V)`.
- Layering:
  - Longest path: `O(V+E)`.
  - Raffinement type simplex: `O(I*(V+E))`.
- Minimisation des croisements:
  - Sweeps multi-phases: environ `O(P*(E + V log V + localSwapCost))`.
- Placement des noeuds:
  - Base + compaction: `O(P*(V+E))` avec passes bornees.
- Recursion subgraph:
  - Somme des couts par cluster sur les niveaux hierarchiques.

## Notes Pratiques

- Le minimum exact de croisements et le minimum exact de feedback arcs sont NP-difficiles en general.
- Les heuristiques implementees privilegient un runtime deterministe, adapte a un editeur interactif.
- L architecture est prete a remplacer des phases individuelles par des solveurs plus stricts (LP/MIP) ou des noyaux network-simplex exacts.
- Le runtime est mono-moteur (ELK-like uniquement), ce qui simplifie la predictibilite lors des reorganisations successives.
- Pour les graphes tres desequilibres, une penalite de ratio de bounding box (`W/H`) ameliore nettement la compacite visuelle et evite les layouts en bande trop longue.

## 7. Contraintes De Qualite Professionnelle

Objectif:
- Definir des exigences mesurables pour garantir un rendu stable, lisible et industrialisable.

### 7.1 Contraintes Dures (Hard Constraints)

Ces contraintes doivent toujours etre satisfaites:
- Aucune intersection noeud/noeud.
- Containment strict parent/enfant pour les subgraphs imbriques.
- Respect des tailles minimales de noeuds et de subgraphs.


### 7.2 Contraintes Souples (Soft Constraints)

Ces contraintes optimisent la qualite sans bloquer la faisabilite:
- Minimisation des croisements d aretes.
- Minimisation de la longueur totale des aretes.
- Compacite rectangulaire (ratio `W/H` cible).
- Alignement opportuniste (`haut/haut`, `gauche/gauche`).
- Preservation de la mental map (stabilite inter-runs).

### 7.3 Score De Qualite Global

Definir un score compose pour comparer les layouts:

`Q = w1*Cross + w2*EdgeLen + w3*DirPenalty + w4*AspectPenalty + w5*MovePenalty + w6*PortCongestion`

Recommandation de poids par defaut:
- `w1=1.00`, `w2=0.35`, `w3=0.60`, `w4=0.30`, `w5=0.45`, `w6=0.25`.

Regle de decision:
- Accepter un nouveau layout si `Q_new <= Q_old * 1.02`.
- Sinon, conserver le layout precedent (sauf violation hard constraint).

### 7.4 Seuils Cibles (QA)

Seuils typiques pour graphes d architecture IT:
- Ratio global: `W/H in [0.65, 1.60]`.
- Croisements normalises: `< 0.08` (nombre de croisements / nombre d aretes).
- Back-edges directionnels: `< 5%`.
- Deplacement median inter-runs (meme graphe): `< 12 px`.
- Deplacement P95 inter-runs: `< 40 px`.
- Overlap labels/noeuds: `0`.

### 7.5 Stabilite Incrementale (Mental Map)

En cas de mise a jour locale:
- Si moins de `10%` du graphe change, au moins `85%` des noeuds doivent rester dans un rayon de `30 px`.
- Penaliser fortement les inversions de rang de couches non necessaires.

### 7.6 SLO De Performance

Budgets indicatifs de calcul:
- `<= 80 noeuds`: `< 120 ms`.
- `<= 200 noeuds`: `< 450 ms`.
- `<= 500 noeuds`: `< 1500 ms`.

Comportement en depassement:
- Reduire le nombre de phases de crossing minimization.
- Conserver en priorite les hard constraints.
- Reporter les optimisations cosmetiques (alignement opportuniste fin, routage secondaire avance).

### 7.7 Modes Metier Recommandes

Prevoir des profils de priorite:
- `Lisibilite`: favorise crossings et monotonicite directionnelle.
- `Compacite`: favorise ratio bbox et longueur totale d aretes.
- `Stabilite`: favorise preservation de la mental map.
- `Performance`: borne agressivement les iterations.

### 7.8 Jeux De Tests De Reference

Maintenir un corpus de graphes de non-regression:
- DAG clairseme, DAG dense, graphe cyclique converti, hubs fan-in/fan-out, subgraphs imbriques multi-niveaux.
- Mesurer automatiquement `Q`, temps de calcul, nombre de violations hard constraints.
- Rejeter un changement si regression au-dela de `+5%` sur les metriques critiques.
