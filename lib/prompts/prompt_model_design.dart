var promptModelDesign = '''
Tu es un expert en modélisation de données (dataSteward). 
donne moi un jsonschemas (version draft = "2020-12") complet pour modéliser un {{modelname}} du domaine {{subdomain}}.
donne un title, description et un example (si interresant) et pattern (si interessant) pour chaque attribut

préférer des objets imbriqués plutôt que de longues listes d'attributs, sauf si c'est vraiment nécessaire.
Gérer un maximum de 3 niveaux d'imbrication, sauf si c'est vraiment nécessaire (les items d'un array repartent de zero).
Proposer des enums en majuscule pour les attributs qui ont un nombre limité de valeurs possibles.
Positionne des facets de recherche search_references (si pertinent) sur les notions qui sont susceptibles d'être utilisés pour filtrer les données.

voici le contexte et contraintes de modélisation :
{{contraints}}

interdit les balises if, then et else

utilise, de préférence, ce catalogue de notion pour nommer les propriétés (d'autres sont acceptables si nouvelle notion) :
- id : identifiant unique, type string, format uuid
- name : nom de l'objet
- description : description de l'objet
- status : statut de l'objet

Sortie attendue :
   - format de sortie de type jsonschemas 
   - sortie d'un jsonschemas uniquement (pas de blabla, pas d'explication, pas de texte, pas de code block)
''';


var promptModelChange = '''
Tu es un expert en modélisation de données (dataSteward). 

voici un jsonschemas existant qui modélise un {{modelname}}:

{{jsonschema}}

Modifie moi ce jsonschemas (version draft = "2020-12").

voici le besoin de modification :
{{contraints}}

donne un title, description et un example (si interresant) et pattern (si interessant) pour chaque nouveaux attributs.

préférer des objets imbriqués plutôt que de longues listes d'attributs, sauf si c'est vraiment nécessaire.
Gérer un maximum de 3 niveaux d'imbrication, sauf si c'est vraiment nécessaire (les items d'un array repartent de zero).
Proposer des enums en majuscule pour les attributs qui ont un nombre limité de valeurs possibles.
Positionne des facets de recherche search_references (si pertinent) sur les notions qui sont susceptibles d'être utilisés pour filtrer les données.

interdit les balises if, then et else

utilise, de préférence, ce catalogue de notion pour nommer les propriétés (d'autres sont acceptables si nouvelle notion) :
- id : identifiant unique, type string, format uuid
- name : nom de l'objet
- description : description de l'objet
- status : statut de l'objet

Sortie attendue :
   - format de sortie de type jsonschemas 
   - sortie d'un jsonschemas uniquement (pas de blabla, pas d'explication, pas de texte, pas de code block)
''';
