import 'package:flutter/material.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/async_api/pan_attribut_editor_async.dart';
import 'package:jsonschema/feature/async_api/property_editor_mixin.dart';

class WidgetAppSheet extends StatelessWidget with PropertyEditorMixin {
  final ModelSchema model;
  const WidgetAppSheet({super.key, required this.model});

  @override
  Widget build(BuildContext context) {


    List<AttributeEditorAsync> listProp = [
      AttributeEditorAsync(name: 'identity.logo', type: 'logo'),
      AttributeEditorAsync(name: 'identity.acronym', type: 'string'), // Ex: APP
      // AttributeEditorAsync(
      //   name: 'identity.business_domain',
      //   type: 'string',
      // ), // Ex: Finance | RH | Supply | Sales
      AttributeEditorAsync(
        name: 'identity.type',
        type: 'string',
      ), // Ex: SaaS | Web | Mobile | Legacy | Microservice | Batch | API
      AttributeEditorAsync(
        name: 'identity.business_owner',
        type: 'string',
      ), // Ex: Nom
      AttributeEditorAsync(
        name: 'identity.it_owner',
        type: 'string',
      ), // Ex: Nom

      AttributeEditorAsync(
        name: 'technologies.language',
        type: 'string',
      ), // Ex: Java 17
      AttributeEditorAsync(
        name: 'technologies.framework',
        type: 'string',
      ), // Ex: Spring Boot 3
      AttributeEditorAsync(
        name: 'technologies.database',
        type: 'string',
      ), // Ex: PostgreSQL 14
      AttributeEditorAsync(
        name: 'technologies.infrastructure',
        type: 'string',
      ), // Ex: Kubernetes | VM | On-prem | Cloud
      AttributeEditorAsync(
        name: 'technologies.environments',
        type: 'string',
      ), // Ex: Dev | QA | Prod


      AttributeEditorAsync(
        name: 'role_and_function.description',
        type: 'string',
      ), // Ex: Description courte de l'application
      AttributeEditorAsync(
        name: 'role_and_function.key_functions',
        type: 'string',
      ), // Ex: Fonction 1 | Fonction 2 | Fonction 3
      AttributeEditorAsync(
        name: 'role_and_function.supported_processes',
        type: 'string',
      ), // Ex: Processus 1 | Processus 2
      AttributeEditorAsync(
        name: 'role_and_function.handled_data',
        type: 'string',
      ), // Ex: Client | Produit | Commande

      AttributeEditorAsync(
        name: 'criticality_and_value.business_criticality',
        type: 'string',
      ), // Ex: Haute | Moyenne | Faible
      AttributeEditorAsync(
        name: 'criticality_and_value.business_value',
        type: 'string',
      ), // Ex: Forte | Moyenne | Faible
      AttributeEditorAsync(
        name: 'criticality_and_value.availability',
        type: 'string',
      ), // Ex: 24/7 | Heures ouvrees
      AttributeEditorAsync(
        name: 'criticality_and_value.sla',
        type: 'string',
      ), // Ex: 99.5%

      AttributeEditorAsync(
        name: 'risks_and_breakpoints.obsolescence.technology_eol',
        type: 'bool',
      ), // Ex: false
      AttributeEditorAsync(
        name: 'risks_and_breakpoints.obsolescence.details',
        type: 'string',
      ), // Ex: ""
      AttributeEditorAsync(
        name: 'risks_and_breakpoints.technical_spof.present',
        type: 'bool',
      ), // Ex: false
      AttributeEditorAsync(
        name: 'risks_and_breakpoints.technical_spof.details',
        type: 'string',
      ), // Ex: ""
      AttributeEditorAsync(
        name: 'risks_and_breakpoints.human_spof.present',
        type: 'bool',
      ), // Ex: false
      AttributeEditorAsync(
        name: 'risks_and_breakpoints.human_spof.details',
        type: 'string',
      ), // Ex: ""
      AttributeEditorAsync(
        name: 'risks_and_breakpoints.contract_dependency.critical',
        type: 'bool',
      ), // Ex: false
      AttributeEditorAsync(
        name: 'risks_and_breakpoints.contract_dependency.details',
        type: 'string',
      ), // Ex: ""
      AttributeEditorAsync(
        name: 'risks_and_breakpoints.security.sensitive_data',
        type: 'bool',
      ), // Ex: false
      AttributeEditorAsync(
        name: 'risks_and_breakpoints.security.gdpr',
        type: 'bool',
      ), // Ex: false

      AttributeEditorAsync(
        name: 'architecture_and_dependencies.incoming_dependencies',
        type: 'string',
      ), // Ex: Application A | Application B
      AttributeEditorAsync(
        name: 'architecture_and_dependencies.outgoing_dependencies',
        type: 'string',
      ), // Ex: API Pricing | Base PostgreSQL | Service S3
      AttributeEditorAsync(
        name: 'architecture_and_dependencies.critical_flows',
        type: 'string',
      ), // Ex: Sync client | Export comptable

      AttributeEditorAsync(
        name: 'costs.licenses',
        type: 'string',
      ), // Ex: 120kEUR/an
      AttributeEditorAsync(
        name: 'costs.maintenance',
        type: 'string',
      ), // Ex: 50kEUR/an
      AttributeEditorAsync(
        name: 'costs.infrastructure',
        type: 'string',
      ), // Ex: 30kEUR/an
      AttributeEditorAsync(name: 'costs.tco', type: 'string'), // Ex: 200kEUR/an

      AttributeEditorAsync(
        name: 'compliance_and_security.personal_data',
        type: 'bool',
      ), // Ex: true
      AttributeEditorAsync(
        name: 'compliance_and_security.sensitivity',
        type: 'string',
      ), // Ex: Haute
      AttributeEditorAsync(
        name: 'compliance_and_security.authentication',
        type: 'string',
      ), // Ex: SSO | OAuth2 | LDAP
      AttributeEditorAsync(
        name: 'compliance_and_security.compliance',
        type: 'string',
      ), // Ex: RGPD | PCI-DSS

      AttributeEditorAsync(
        name: 'roadmap.current_state',
        type: 'string',
      ), // Ex: OK | A risque | Obsolete
      AttributeEditorAsync(
        name: 'roadmap.plan',
        type: 'string',
      ), // Ex: Maintien | Modernisation | Refonte | Retrait
      AttributeEditorAsync(
        name: 'roadmap.deadline',
        type: 'string',
      ), // Ex: 2026-Q4
      AttributeEditorAsync(
        name: 'roadmap.estimated_budget',
        type: 'string',
      ), // Ex: 300kEUR
    ];

    return getTabProp(listProp, model.selectedAttr!, model, <Widget>[]);
  }
}
