import 'package:flutter/material.dart';
import 'package:jsonschema/authorization_manager.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/json_browser/browse_api.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/async_api/pan_attribut_editor_async.dart';
import 'package:jsonschema/feature/async_api/property_editor_mixin.dart';

class WidgetAppSheet extends StatelessWidget with PropertyEditorMixin {
  const WidgetAppSheet({super.key});

  @override
  Widget build(BuildContext context) {
    ModelSchema model = ModelSchema(
      category: Category.api,
      headerName: '',
      id: '',
      infoManager: InfoManagerAPI(),
      refDomain: null,
    );

    var mapEntryEmpty = const MapEntry('', null);
    model.selectedAttr = NodeAttribut(
      yamlNode: mapEntryEmpty,
      info: AttributInfo(),
      parent: null,
    );

    var info = model.selectedAttr!;

    List<AttributeEditorAsync> listProp = [
      AttributeEditorAsync(
        name: 'identite.nom',
        type: 'string',
      ), // Ex: Nom de l'application
      AttributeEditorAsync(
        name: 'identite.acronyme',
        type: 'string',
      ), // Ex: APP
      AttributeEditorAsync(
        name: 'identite.domaine_metier',
        type: 'string',
      ), // Ex: Finance | RH | Supply | Sales
      AttributeEditorAsync(
        name: 'identite.type',
        type: 'string',
      ), // Ex: SaaS | Web | Mobile | Legacy | Microservice | Batch | API
      AttributeEditorAsync(
        name: 'identite.business_owner',
        type: 'string',
      ), // Ex: Nom
      AttributeEditorAsync(
        name: 'identite.it_owner',
        type: 'string',
      ), // Ex: Nom

      AttributeEditorAsync(
        name: 'role_et_fonction.description',
        type: 'string',
      ), // Ex: Description courte de l'application
      AttributeEditorAsync(
        name: 'role_et_fonction.fonctions_principales',
        type: 'string',
      ), // Ex: Fonction 1 | Fonction 2 | Fonction 3
      AttributeEditorAsync(
        name: 'role_et_fonction.processus_supportes',
        type: 'string',
      ), // Ex: Processus 1 | Processus 2
      AttributeEditorAsync(
        name: 'role_et_fonction.donnees_manipulees',
        type: 'string',
      ), // Ex: Client | Produit | Commande

      AttributeEditorAsync(
        name: 'criticite_et_valeur.criticite_metier',
        type: 'string',
      ), // Ex: Haute | Moyenne | Faible
      AttributeEditorAsync(
        name: 'criticite_et_valeur.valeur_metier',
        type: 'string',
      ), // Ex: Forte | Moyenne | Faible
      AttributeEditorAsync(
        name: 'criticite_et_valeur.disponibilite',
        type: 'string',
      ), // Ex: 24/7 | Heures ouvrees
      AttributeEditorAsync(
        name: 'criticite_et_valeur.sla',
        type: 'string',
      ), // Ex: 99.5%

      AttributeEditorAsync(
        name: 'risques_et_points_de_rupture.obsolescence.techno_eol',
        type: 'bool',
      ), // Ex: false
      AttributeEditorAsync(
        name: 'risques_et_points_de_rupture.obsolescence.details',
        type: 'string',
      ), // Ex: ""
      AttributeEditorAsync(
        name: 'risques_et_points_de_rupture.spof_technique.present',
        type: 'bool',
      ), // Ex: false
      AttributeEditorAsync(
        name: 'risques_et_points_de_rupture.spof_technique.details',
        type: 'string',
      ), // Ex: ""
      AttributeEditorAsync(
        name: 'risques_et_points_de_rupture.spof_humain.present',
        type: 'bool',
      ), // Ex: false
      AttributeEditorAsync(
        name: 'risques_et_points_de_rupture.spof_humain.details',
        type: 'string',
      ), // Ex: ""
      AttributeEditorAsync(
        name: 'risques_et_points_de_rupture.dependance_contrat.critique',
        type: 'bool',
      ), // Ex: false
      AttributeEditorAsync(
        name: 'risques_et_points_de_rupture.dependance_contrat.details',
        type: 'string',
      ), // Ex: ""
      AttributeEditorAsync(
        name: 'risques_et_points_de_rupture.securite.donnees_sensibles',
        type: 'bool',
      ), // Ex: false
      AttributeEditorAsync(
        name: 'risques_et_points_de_rupture.securite.rgpd',
        type: 'bool',
      ), // Ex: false

      AttributeEditorAsync(
        name: 'architecture_et_dependances.dependances_entrantes',
        type: 'string',
      ), // Ex: Application A | Application B
      AttributeEditorAsync(
        name: 'architecture_et_dependances.dependances_sortantes',
        type: 'string',
      ), // Ex: API Pricing | Base PostgreSQL | Service S3
      AttributeEditorAsync(
        name: 'architecture_et_dependances.flux_critiques',
        type: 'string',
      ), // Ex: Sync client | Export comptable

      AttributeEditorAsync(
        name: 'technologies.langage',
        type: 'string',
      ), // Ex: Java 17
      AttributeEditorAsync(
        name: 'technologies.framework',
        type: 'string',
      ), // Ex: Spring Boot 3
      AttributeEditorAsync(
        name: 'technologies.base_de_donnees',
        type: 'string',
      ), // Ex: PostgreSQL 14
      AttributeEditorAsync(
        name: 'technologies.infrastructure',
        type: 'string',
      ), // Ex: Kubernetes | VM | On-prem | Cloud
      AttributeEditorAsync(
        name: 'technologies.environnements',
        type: 'string',
      ), // Ex: Dev | QA | Prod

      AttributeEditorAsync(
        name: 'couts.licences',
        type: 'string',
      ), // Ex: 120kEUR/an
      AttributeEditorAsync(
        name: 'couts.maintenance',
        type: 'string',
      ), // Ex: 50kEUR/an
      AttributeEditorAsync(
        name: 'couts.infrastructure',
        type: 'string',
      ), // Ex: 30kEUR/an
      AttributeEditorAsync(name: 'couts.tco', type: 'string'), // Ex: 200kEUR/an

      AttributeEditorAsync(
        name: 'conformite_et_securite.donnees_personnelles',
        type: 'bool',
      ), // Ex: true
      AttributeEditorAsync(
        name: 'conformite_et_securite.sensibilite',
        type: 'string',
      ), // Ex: Haute
      AttributeEditorAsync(
        name: 'conformite_et_securite.authentification',
        type: 'string',
      ), // Ex: SSO | OAuth2 | LDAP
      AttributeEditorAsync(
        name: 'conformite_et_securite.conformite',
        type: 'string',
      ), // Ex: RGPD | PCI-DSS

      AttributeEditorAsync(
        name: 'roadmap.etat_actuel',
        type: 'string',
      ), // Ex: OK | A risque | Obsolete
      AttributeEditorAsync(
        name: 'roadmap.plan',
        type: 'string',
      ), // Ex: Maintien | Modernisation | Refonte | Retrait
      AttributeEditorAsync(
        name: 'roadmap.echeance',
        type: 'string',
      ), // Ex: 2026-Q4
      AttributeEditorAsync(
        name: 'roadmap.budget_estime',
        type: 'string',
      ), // Ex: 300kEUR
    ];

    return getListProp(listProp, info, model, <Widget>[]);
  }
}
