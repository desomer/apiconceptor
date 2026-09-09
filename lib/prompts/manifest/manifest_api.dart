var a = '''
api_manifest:
  metadata:
    name: "enterprise-api-governance"
    version: "1.0.0"
    generated_by: "AI Agent Governance Framework"
    last_update: "2026-08-04"

  conventions:
    naming:
      route_style: kebab-case
      resource_plural: true
      allowed_http_verbs: ["get", "post", "put", "patch", "delete"]
      id_param_name: "id"
      collection_suffix: ""
      examples:
        valid: "/v1/products/{id}"
        invalid: "/getProductInfo"

    json_schema:
      field_style: lowerCamelCase
      id_format: uuid
      date_format: iso8601
      required_fields: ["id", "createdAt"]
      forbidden_fields: ["internalId", "debug"]
      max_depth: 5
      allow_additional_properties: false

    versioning:
      strategy: uri
      prefix: "/v1"
      deprecated_versions: []
      rules:
        - "Toute nouvelle API doit être publiée sous /v1"
        - "Les breaking changes nécessitent /v2"

    errors:
      format: rfc7807
      required_fields: ["type", "title", "status", "detail"]
      examples:
        not_found:
          type: "https://api.example.com/errors/not-found"
          title: "Resource not found"
          status: 404
          detail: "The requested resource does not exist"

  security:
    authentication:
      type: oauth2
      flows: ["client_credentials", "authorization_code"]
    authorization:
      model: rbac
      scopes:
        - "product.read"
        - "product.write"
        - "customer.read"
        - "customer.write"
    data_protection:
      pii_allowed: false
      encryption_in_transit: true
      encryption_at_rest: true

  governance:
    dto_binding:
      enforce_dto_models: true
      dto_source: "enterprise-dto-v3"
      rules:
        - "Les champs générés doivent exister dans le DTO"
        - "Les types doivent correspondre au DTO"
        - "Les relations doivent respecter les cardinalités DTO"

    policy_engine:
      validations:
        - "route_naming"
        - "schema_structure"
        - "required_fields"
        - "versioning"
        - "security_scopes"
        - "dto_alignment"
        - "rgpd_compliance"
      reject_on_failure: true

    audit:
      enabled: true
      store: "immutable-ledger"
      trace_fields:
        - "route"
        - "schema"
        - "version"
        - "agent_id"
        - "timestamp"
        - "policy_results"

  constraints:
    forbidden_capabilities:
      - "raw_http"
      - "shell_exec"
      - "dynamic_route_generation"
      - "direct_database_access"
    rate_limits:
      default: "1000/min"
      sensitive_routes: "100/min"

  ci_cd:
    validation_steps:
      - "lint_manifest"
      - "validate_schema"
      - "check_versioning"
      - "policy_engine_gate"
      - "audit_registration"
    reject_if:
      - "missing_required_fields"
      - "non_dto_compliant"
      - "security_scope_violation"
      - "invalid_version_prefix"

  examples:
    valid_route: "/v1/products/{id}"
    valid_schema:
      type: object
      properties:
        id:
          type: string
          format: uuid
        title:
          type: string
        createdAt:
          type: string
          format: date-time
      required: ["id", "title", "createdAt"]
''';

// ignore: slash_for_doc_comments
/**


| Critère                      | DTO                      | JSON Schema |
| ---                          | ---                      | ---         |
| **Nature**                   | Métier                   | Technique           |
| **Finalité**                 | Décrire l’organisation   | Décrire un payload  |
| **Portée**                   | Enterprise-wide          | API-specific        |
| **Relations**                | Oui (Product → Category) | Non (juste structure JSON) |
| **Règles métier**            | Oui                      | Non                 |
| **Conformité AI Act / RGPD** | Oui                      | Non                 |
| **Utilisation par IA**       | Source de vérité         | Contrat d’API       |
| **Versioning**               | Organisationnel          | API par API         |
 
 */

var dtoManifest = r'''
dto:
  metadata:
    name: "enterprise-dto"
    version: "3.1.0"
    description: "Digital Twin of Organization with business rules for API governance"
    last_update: "2026-08-04"

  types:
    uuid:
      type: string
      format: uuid

    isoDateTime:
      type: string
      format: date-time

    money:
      type: number
      minimum: 0

    localizedString:
      type: object
      patternProperties:
        "^[a-z]{2}(-[A-Z]{2})?$":
          type: string

  resources:

    Product:
      description: "Core product entity"
      fields:
        id: { $ref: "#/dto/types/uuid", required: true }
        title: { type: string, required: true }
        description: { type: string, required: false }
        price: { $ref: "#/dto/types/money", required: true }
        market: { type: string, enum: ["FR", "DE", "ES", "IT"], required: true }
        createdAt: { $ref: "#/dto/types/isoDateTime", required: true }
        updatedAt: { $ref: "#/dto/types/isoDateTime", required: false }

      relations:
        categories:
          type: array
          items: { $ref: "#/dto/resources/Category" }

      business_rules:
        - id: "product.title.length"
          description: "Le titre produit doit être inférieur à 80 caractères pour le marché DE"
          applies_to: "title"
          condition: "market == 'DE'"
          constraint:
            max_length: 80

        - id: "product.price.min"
          description: "Le prix doit être supérieur à 0"
          applies_to: "price"
          constraint:
            min: 0

        - id: "product.market.allowed"
          description: "Le marché doit être une valeur autorisée"
          applies_to: "market"
          constraint:
            enum: ["FR", "DE", "ES", "IT"]

        - id: "product.description.required_for_ES"
          description: "La description est obligatoire pour le marché ES"
          applies_to: "description"
          condition: "market == 'ES'"
          constraint:
            required: true

        - id: "product.price.max_for_IT"
          description: "Le prix ne peut pas dépasser 500€ pour le marché IT"
          applies_to: "price"
          condition: "market == 'IT'"
          constraint:
            max: 500

      compliance:
        rgpd:
          contains_pii: false
        ai_act:
          risk_level: "limited"
          autonomy_level: 2
          required_controls:
            - "audit"
            - "traceability"
            - "human_validation_on_critical_changes"

    Category:
      description: "Product category"
      fields:
        id: { $ref: "#/dto/types/uuid", required: true }
        name: { type: string, required: true }
        createdAt: { $ref: "#/dto/types/isoDateTime", required: true }

      relations:
        parent:
          type: object
          $ref: "#/dto/resources/Category"

      business_rules:
        - id: "category.name.not_empty"
          description: "Le nom de la catégorie ne peut pas être vide"
          applies_to: "name"
          constraint:
            min_length: 1

      compliance:
        rgpd:
          contains_pii: false
        ai_act:
          risk_level: "minimal"

    Customer:
      description: "Customer entity"
      fields:
        id: { $ref: "#/dto/types/uuid", required: true }
        firstName: { type: string, required: true }
        lastName: { type: string, required: true }
        email: { type: string, format: email, required: true }
        createdAt: { $ref: "#/dto/types/isoDateTime", required: true }

      business_rules:
        - id: "customer.email.valid"
          description: "L'email doit être valide"
          applies_to: "email"
          constraint:
            format: "email"

        - id: "customer.name.min_length"
          description: "Les noms doivent contenir au moins 2 caractères"
          applies_to: ["firstName", "lastName"]
          constraint:
            min_length: 2

      compliance:
        rgpd:
          contains_pii: true
          required_controls:
            - "consent"
            - "data_minimization"
            - "encryption"
        ai_act:
          risk_level: "high"
          autonomy_level: 1
          required_controls:
            - "human_supervision"
            - "restricted_agent_actions"

''';

var dtoModel = r'''
dto:
  metadata:
    name: "enterprise-dto"
    version: "3.0.0"
    description: "Digital Twin of Organization for REST API governance"
    last_update: "2026-08-04"

  types:
    uuid:
      type: string
      format: uuid
    isoDateTime:
      type: string
      format: date-time
    isoDate:
      type: string
      format: date
    money:
      type: number
      minimum: 0
    localizedString:
      type: object
      patternProperties:
        "^[a-z]{2}(-[A-Z]{2})?$":
          type: string

  resources:

    Product:
      description: "Core product entity"
      fields:
        id: { $ref: "#/dto/types/uuid", required: true }
        title: { $ref: "#/dto/types/localizedString", required: true }
        description: { $ref: "#/dto/types/localizedString", required: false }
        price: { $ref: "#/dto/types/money", required: true }
        market: { type: string, enum: ["FR", "DE", "ES", "IT"], required: true }
        createdAt: { $ref: "#/dto/types/isoDateTime", required: true }
        updatedAt: { $ref: "#/dto/types/isoDateTime", required: false }
      relations:
        categories:
          type: array
          items: { $ref: "#/dto/resources/Category" }
        variants:
          type: array
          items: { $ref: "#/dto/resources/ProductVariant" }

    ProductVariant:
      description: "Variant of a product"
      fields:
        id: { $ref: "#/dto/types/uuid", required: true }
        sku: { $ref: "#/dto/types/localizedString", required: true }
        color: { $ref: "#/dto/types/localizedString", required: false }
        size: { $ref: "#/dto/types/localizedString", required: false }
        stock: { type: number, required: true }
      relations:
        parentProduct:
          type: object
          $ref: "#/dto/resources/Product"

    Category:
      description: "Product category"
      fields:
        id: { $ref: "#/dto/types/uuid", required: true }
        name: { $ref: "#/dto/types/localizedString", required: true }
        createdAt: { $ref: "#/dto/types/isoDateTime", required: true }
      relations:
        parent:
          type: object
          $ref: "#/dto/resources/Category"
        children:
          type: array
          items: { $ref: "#/dto/resources/Category" }

    Customer:
      description: "Customer entity"
      fields:
        id: { $ref: "#/dto/types/uuid", required: true }
        firstName: { $ref: "#/dto/types/localizedString", required: true }
        lastName: { $ref: "#/dto/types/localizedString", required: true }
        email: { type: string, format: email, required: true }
        createdAt: { $ref: "#/dto/types/isoDateTime", required: true }
      relations:
        orders:
          type: array
          items: { $ref: "#/dto/resources/Order" }

    Order:
      description: "Order entity"
      fields:
        id: { $ref: "#/dto/types/uuid", required: true }
        totalAmount: { $ref: "#/dto/types/money", required: true }
        status: { type: string, enum: ["pending", "paid", "shipped", "cancelled"], required: true }
        createdAt: { $ref: "#/dto/types/isoDateTime", required: true }
      relations:
        customer:
          type: object
          $ref: "#/dto/resources/Customer"
        items:
          type: array
          items: { $ref: "#/dto/resources/OrderItem" }

    OrderItem:
      description: "Line item of an order"
      fields:
        id: { $ref: "#/dto/types/uuid", required: true }
        quantity: { type: number, minimum: 1, required: true }
        unitPrice: { $ref: "#/dto/types/money", required: true }
      relations:
        product:
          type: object
          $ref: "#/dto/resources/Product"
''';
