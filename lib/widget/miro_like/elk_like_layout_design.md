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

Au niveau UI, l assignation finale des ancres et le respect de la contrainte dure anti-survol des noeuds restent geres dans le code de geometrie des liens existant.

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
- Privilegier une empreinte globale proche d un rectangle.
- Eviter un layout trop etire en largeur ou trop etire en hauteur.

Formulation (contrainte trés douce recommandee):
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
- Il faut utiliser une contrainte souple, pas une contrainte dure,
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

Le controle global d evitement des noeuds reste dans la phase de geometrie UI.
Le coeur ELK-like conserve une generation orthogonale port-aware pour reduire la pression de croisements residuels,
mais la priorite finale est la contrainte dure anti-survol des noeuds.

### 5.4 Routage Base Sur Les Ports

Les ports source/cible sont choisis depuis la relation directionnelle (`dx`, `dy`) et les normales de cote.

### 5.5 Minimisation Des Segments Et Croisements Residuels

Dans l implementation actuelle:
- Les candidats favorisent des structures courtes (moins de segments).
- Le layering + placement reduisent les croisements residuels avant le routage final des connecteurs.

### 5.6 Contrainte Dure Anti-Survol Des Noeuds

Exigence:
- Un path de lien ne doit pas traverser la bbox d un noeud (hors noeud source et noeud cible).
- Cette regle est de priorite tres elevee, devant les preferences cosmetiques de courbure.

Regle de validation:
1. Construire le path effectif du lien (bezier).
2. Echantillonner ou tester les segments contre les obstacles (bboxes des noeuds non terminaux).
3. Si intersection detectee, reoptimiser le placement des noeuds/subgraphs jusqu a suppression du survol.

Strategie recommandee:
- Garder les liens en bezier par defaut.
- Deplacer prioritairement les noeuds obstructeurs (ou leur subgraph) plutot que modifier le type du connecteur.
- Reexecuter une passe courte de non-recouvrement pour conserver les separations minimales.

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

### 6.6 Non-Superposition Des Subgraphs Et Gap Minimal

Exigence:
- Deux subgraphs sans relation ancetre/descendant ne doivent jamais se superposer visuellement.
- Un gap minimal doit etre maintenu entre subgraphs voisins.
- Un gap parent/enfant doit etre maintenu entre bord parent et bord enfant.

Regles pratiques:
1. Si `A` et `B` sont disjoints ou se recouvrent partiellement sans relation hierarchique stricte:
  - imposer `distanceBBox(A,B) >= gapSubgraph`.
2. Si `A` contient `B` (relation parent/enfant):
  - imposer `insetParentChild(B in A) >= gapParentChild`.
3. Si l espace parent est insuffisant:
  - agrandir l empreinte parent (via deplacement des noeuds parent-only) avant de deplacer l enfant.

Valeurs recommandees:
- `gapSubgraph`: `max(64 px, 1.6 * gapNoeud)`.
- `gapParentChild`: `max(32 px, 0.9 * gapNoeud)`.

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
- generation orthogonale port-aware + enforcement aval de la contrainte anti-survol des noeuds.

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

### 7.1 Contraintes Dures (Obligatoires)

Ces contraintes doivent toujours etre satisfaites:
- Aucune intersection noeud/noeud.
- Containment strict parent/enfant pour les subgraphs imbriques.
- Respect des tailles minimales de noeuds et de subgraphs.
- Aucune superposition de subgraphs non lies hierarchiquement.
- Respect d un gap minimal inter-subgraphs et parent/enfant.
- Aucun survol de noeud par un path de lien (hors source/cible).


### 7.2 Contraintes Souples (Preferentielles)

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
- Sinon, conserver le layout precedent (sauf violation d une contrainte dure).

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
- Conserver en priorite les contraintes dures.
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
- Mesurer automatiquement `Q`, temps de calcul, nombre de violations de contraintes dures.
- Rejeter un changement si regression au-dela de `+5%` sur les metriques critiques.

## 8. Renforcement Anti-Superposition Et Anti-Survol

Objectif:
- Completer le pipeline actuel par un noyau de reparation robuste pour garantir, en sortie, l absence de superposition et l absence de survol de blocs par les liens bezier.

### 8.1 Priorisation Formelle Des Contraintes

Definir explicitement trois niveaux de priorite:

1. Niveau 1 (contraintes dures absolues):
- Non-superposition rectangle/rectangle entre blocs.
- Non-superposition des subgraphs non ancetre/descendant.
- Containment parent/enfant avec marge minimale.

2. Niveau 2 (contraintes dures de routage):
- Aucun segment echantillonne du path bezier d un lien ne traverse la bbox d un bloc non terminal (hors source/cible), avec marge de securite.

3. Niveau 3 (contraintes souples):
- Compacite rectangulaire.
- Alignements opportunistes.
- Regularite esthetique et minimisation additionnelle de longueur.

Regle de precedence:
- Une contrainte souple ne doit jamais provoquer de violation d une contrainte dure.

### 8.2 Corridors De Liens Bezier Reserves

Principe:
- Conserver le type de connecteur bezier.
- Reserver un corridor geometrique autour des liens pour guider le deplacement des obstacles (blocs/subgraphs), au lieu de modifier le style des liens.

Specification:
1. Pour chaque lien, echantillonner la courbe bezier sur `N` points (recommande: `N in [24, 40]`, adapte a la longueur).
2. Construire un tube de clearance de rayon `rClear` autour de la polyligne echantillonnee.
3. Interdire l intersection entre ce tube et toute bbox de bloc non terminal.
4. En cas de conflit:
- deplacer d abord le plus petit obstacle mobile,
- puis elargir au subgraph parent si le deplacement local est insuffisant.

Valeurs de depart:
- `rClear = max(10 px, 0.35 * gapNoeud)`.
- `maxLocalMovesPerConflict = 3`.

### 8.3 Solveur Local De Reparation Iteratif

Apres le placement principal, executer une boucle de reparation a iterations bornees.

Boucle type:
1. Detecter tous les conflits actifs:
- bloc/bloc,
- subgraph/subgraph,
- lien(bloc non terminal).
2. Calculer, pour chaque conflit, un vecteur minimal de separation.
3. Agreger les vecteurs par objet mobile.
4. Appliquer un pas amorti (damping) avec projection des contraintes hierarchiques.
5. Revalider les contraintes dures.
6. Arreter si plus de conflit ou nombre max d iterations atteint.

Parametrage recommande:
- `repairMaxIterations = 12`.
- `repairDamping = 0.60`.
- `repairEpsilon = 0.5 px`.

Condition de succes:
- Toutes les metriques de conflits durs doivent etre a `0`.

### 8.4 Acceleration Par Index Spatial

Pour maintenir un runtime interactif, utiliser un index spatial (R-tree ou quadtree) dans les passes de detection:
- requetes de voisinage bbox/bbox en `O(log n)` attendu,
- reduction du cout des tests lien/bloc,
- meilleure scalabilite sur grands graphes et subgraphs denses.

### 8.5 Renforcement Hierarchique Parent/Enfant

Introduire des marges dynamiques pour limiter les collisions recurrentes dans les structures imbriquees:

Formule proposee:
- `gapParentChildDynamic = baseGap + depthFactor * profondeur + densityFactor * densiteLocale`.

Regles:
1. Si un enfant est pousse contre un bord parent:
- agrandir prioritairement le parent avant de deplacer globalement le voisinage.
2. Si deux parents se penetrent:
- separer selon l axe de penetration minimale,
- ajouter une hysteresis pour eviter les oscillations inter-iterations.

Valeurs initiales utiles:
- `depthFactor = 4 px`.
- `densityFactor in [6, 14] px` selon charge locale.
- `hysteresis = 2 px`.

### 8.6 Detection D Infaisabilite Et Fallback

Cas cible:
- Le solveur ne trouve pas de solution satisfaisant simultanement toutes les contraintes dures dans la zone courante.

Strategie:
1. Detecter l infaisabilite (stagnation de conflits durs apres `K` iterations).
2. Augmenter automatiquement l espace disponible (canvas virtuel / bbox globale).
3. Reexecuter la reparation avec gaps majores moderement.
4. Relacher uniquement les contraintes souples si necessaire (jamais les contraintes dures).

Parametres:
- `infeasibleAfterIterations = 6`.
- `areaScaleStep = 1.15`.
- `maxAreaScale = 1.60`.

### 8.7 Ordre D Integration Recommande

Pour limiter le risque de regression:
1. Integrer d abord le solveur local de reparation iteratif.
2. Ajouter les corridors bezier reserves et la clearance tube/bloc.
3. Renforcer les marges dynamiques parent/enfant.
4. Ajouter la detection d infaisabilite et fallback d expansion.
5. Finaliser par le tuning des poids et seuils.

### 8.8 Metriques Additionnelles Obligatoires

En plus de `Q`, suivre explicitement:
- `hardNodeOverlaps` (bloc/bloc).
- `hardSubgraphOverlaps` (subgraph/subgraph hors hierarchie).
- `hardLinkBlockIntersections` (lien/bloc non terminal).
- `avgDisplacementPerIteration`.
- `layoutRuntimeMs`.

Critere de validation production:
- `hardNodeOverlaps = 0`.
- `hardSubgraphOverlaps = 0`.
- `hardLinkBlockIntersections = 0`.
- Respect des SLO de la section 7.6.
