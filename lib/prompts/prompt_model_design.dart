String listbalise = '''
- required : boolean
- format
- enum
- description
- title
- default
- example
- minLength
- maxLength
- minimum
- exclusiveMinimum : boolean
- maximum
- exclusiveMaximum : boolean
- pattern
- const   
- uniqueItems
- minItems
- maxItems
- multipleOf
- minProperties
- maxProperties
- dependentRequired
- contentEncoding
- contentMediaType
- readOnly
- writeOnly
- deprecated
- search_references : boolean
- \$comment
- oneOf
- anyOf
- allOf
''';

var typeModelContraint = '''
préférer des objets imbriqués plutôt que de longues listes d'attributs, sauf si c'est vraiment nécessaire.
Gérer un maximum de 3 niveaux d'imbrication, sauf si c'est vraiment nécessaire (les items d'un array repartent de zero).
Proposer des enums en majuscule pour les attributs qui ont un nombre limité de valeurs possibles.

Positionne attribut search_references (si pertinent) de type boolean sur les notions qui sont susceptibles d'être utilisés pour filtrer les données.
''';

var typeFileContraint = '''
comme cela doit représenter un fichier plat, préférer des objets une longues listes d'attributs 
met un attribut recordType (attribut de type const d'une longueur de 2 caractères majuscules) pour typer chaque bloc de données.
Gérer un maximum de 3 niveaux d'imbrication, pour représenter correctement les array. 
Proposer des enums en majuscule pour les attributs qui ont un nombre limité de valeurs possibles.
''';

var promptModelDesign =
    '''
Tu es un expert en modélisation de données (dataSteward). 
donne moi un jsonschemas (version draft = "2020-12") complet pour modéliser un {{modelname}} du domaine {{subdomain}}.
il doit être le représentatif d'un {{type}}.

donne un title, description et un example (si interresant) et pattern (si interessant) pour chaque attribut
donne également si required et les valeurs par défaut (si pertinent).
ne donne pas de regex si un pattern est déjà fourni.

{{typeConstraints}}

voici le contexte et contraintes de modélisation :
{{contraints}}

voici les balises jsonschema possibles :
$listbalise

interdit les balises jsonschema : 
- if
- then
- else

utilise, de préférence, ce catalogue de notion pour nommer les propriétés (d'autres sont acceptables si nouvelle notion) :
- id : identifiant unique, type string, format uuid
- name : nom de l'objet
- description : description de l'objet
- status : statut de l'objet

Sortie attendue :
   - format de sortie de type jsonschemas 
   - sortie d'un jsonschemas uniquement (pas de blabla, pas d'explication, pas de texte, pas de code block)
''';

var promptModelChange =
    '''
Tu es un expert en modélisation de données (dataSteward). 

voici un jsonschemas existant qui modélise un {{modelname}} de type {{type}} :

{{jsonschema}}

Modifie moi ce jsonschemas (version draft = "2020-12").

voici le besoin de modification :
{{contraints}}

donne un title, description et un example (si interresant) et pattern (si interessant) pour chaque attribut
donne également si required et les valeurs par défaut (si pertinent).
ne donne pas de regex si un pattern est déjà fourni.

{{typeConstraints}}

voici les balises jsonschema possibles :
$listbalise

interdit les balises jsonschema : 
- if
- then
- else

utilise, de préférence, ce catalogue de notion pour nommer les propriétés (d'autres sont acceptables si nouvelle notion) :
- id : identifiant unique, type string, format uuid
- name : nom de l'objet
- description : description de l'objet
- status : statut de l'objet

Sortie attendue :
   - format de sortie de type jsonschemas 
   - sortie d'un json uniquement (pas de blabla, pas d'explication, pas de texte, pas de code block)
   - sortie de type : 
      {
        "id": "msg_1",
        "role": "assistant",
        "responseType": "response"  // ou "change" si demande de modification du jsonschema
        "content": [
            {
            "type": "text",
            "text": "<ici une explication du changement ou reponse à la question>"
            },
            {
            "type": "jsonschema",
            "jsonschema": { <ICI LE JSONSCHEMA MODIFIÉ> }
            }            
        ],
        "createdAt": "2026-09-20T15:00:01Z" //ici la date de la réponse
      }
      - responseType  "response" si réponse normale, "change" si demande de modification du jsonschema
      - ne pas inclure le bloc jsonschema si responseType est "response"
      - ne pas modifier le jsonschema si la demande n'est pas une modification
''';
