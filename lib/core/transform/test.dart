import 'dart:convert';

import 'package:jsonschema/core/transform/engine.dart';
import 'package:jsonschema/core/transform/enrichment.dart';


var spec = r'''# mapping_customer.yaml
mapping_id: customer_v1_to_dw_v1
version: 1.0
source:
  format: json
target:
  format: json
fields:
  - id: f00
    source: city_code
    target: city_code

  - id: f01
    source: id
    target: customer_id
    transforms:
      - name: cast
        args: { to: "string" }

  - id: f02
    source: firstName
    target: first_name
    transforms:
      - name: trim
      - name: lowercase

  - id: f03
    source: lastName
    target: last_name
    transforms:
      - name: trim
      - name: uppercase

  - id: f04
    source: birthDate
    target: dob
    transforms:
      - name: parse_date
        args: { format: "dd/MM/yyyy", on_error: "null" }

  - id: f05
    source: address.city
    target: city
    transforms:
      - name: trim

  - id: f06
    source: email
    target: email
    transforms:
      - name: lowercase
      - name: validate_regex
        args:
          pattern: "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$"
          on_error: "dlq"

conditional_mappings:
  - id: C001
    condition: "country == 'FR' && status == 'active'"
    then:
      - target: is_eu
        value: true
    otherwise:
      - target: is_eu
        value: false

derived_fields:
  - id: d01
    target: full_name
    type: string
    expression: "first_name + ' ' + last_name"
    on_error: "dlq"


validations:
  # validation par champ avec niveau et action
  - id: V_EMAIL_FORMAT
    scope: field
    field: email
    rule: regex
    pattern: "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$"
    level: fail
    action: dlq

  - id: V_FIRSTNAME_NOT_EMPTY
    scope: field
    field: first_name
    rule: not_null
    level: fail
    action: dlq

  - id: V_DOB_RANGE
    scope: field
    field: dob
    rule: cel
    expression: "dob >= '2000-01-01' && dob <= '2020-12-31'"
    level: warn
    action: coerce_null

enrichments:
  - id: E_CITY_LOOKUP
    type: lookup
    description: "Enrich city and region from city_code via cache + fallback"
    input: city_code
    input_lookup:
      - city
      - region    
    outputs:
      - address.city
      - address.region
    provider: geo_table
    cache:
      type: in_memory
      ttl_seconds: 3600
    fallback:
      type: default
      values:
        address.city: "UNKNOWN"
        address.region: "UNKNOWN"
    on_error: fallback

          ''';

// - id: E_IP_GEO
//   type: api
//   description: "Enrich IP with geo info via external API (async, circuit breaker)"
//   input: ip_address
//   outputs:
//     - country
//     - region
//     - city
//   provider: "https://geo.example.com/lookup"
//   timeout_ms: 300
//   cache:
//     type: redis
//     ttl_seconds: 600
//   fallback:
//     type: null
//   on_error: dlq

void main() async {
  final registry = EnrichmentRegistry();
  // table provider example
  registry.register(
    'geo_table',
    TableLookupProvider({
      '75056': {'city': 'Paris', 'region': 'Île-de-France'},
      // add more rows or load from file/db
    }),
  );

  // http provider example (implement fetch with real HTTP client)
  registry.register(
    'https://geo.example.com/lookup',
    HttpEnrichmentProvider('https://geo.example.com/lookup'),
  );

  final enrichmentEngine = EnrichmentEngine(registry);

  final mappingYaml = spec;
  final mapping = loadMappingFromYaml(mappingYaml);
  final engine = TransformEngine(mapping, enrichmentEngine);

  final inputJson = {
    "id": 123,
    "city_code": "75056",
    "country": "FR",
    "status": "active",
    "firstName": " John ",
    "lastName": "Doe ",
    "birthDate": "31/12/2010",
    "address": {"city": " New York "},
    "email": "john.doe@example.com",
  };

  final inputJson2 = {
    "id": 456,
    "city_code": "99999",
    "country": "US",
    "status": "inactive",
    "firstName": " Jane ",
    "lastName": "Smith ",
    "birthDate": "15/08/1985",
    "address": {"city": " Los Angeles "},
    "email": "invalid-email",
  }; 

  final out =  await engine.transformBatch([inputJson, inputJson2]);

  String prettyPrintJson(dynamic input) {
    const JsonEncoder encoder = JsonEncoder.withIndent('   ');
    return encoder.convert(input);
  }

  print(prettyPrintJson(out));




}
