import 'dart:convert';

import 'package:flutter/material.dart';

/// Displays a list of Use Cases grouped by Bounded Context.
///
/// Expects a JSON string matching:
/// `{ "boundedContexts": [ { "name", "description", "useCases": [...] } ] }`
class WidgetUseCaseList extends StatelessWidget {
  const WidgetUseCaseList({super.key, required this.jsonSource});

  final String jsonSource;

  @override
  Widget build(BuildContext context) {
    List<BoundedContextData> boundedContexts;
    try {
      boundedContexts = parseBoundedContexts(jsonSource);
    } catch (e) {
      return Center(child: Text('JSON invalide : $e'));
    }

    if (boundedContexts.isEmpty) {
      return const Center(child: Text('Aucun bounded context à afficher'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: boundedContexts.length,
      itemBuilder: (context, index) {
        return _BoundedContextTile(boundedContext: boundedContexts[index]);
      },
    );
  }

  static List<BoundedContextData> parseBoundedContexts(String source) {
    if (source.trim().isEmpty) return [];
    final decoded = json.decode(source) as Map<String, dynamic>;
    return ((decoded['boundedContexts'] as List?) ?? [])
        .map((e) => BoundedContextData.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

List<String> _stringList(dynamic value) {
  return ((value as List?) ?? []).map((e) => e.toString()).toList();
}

Map<String, dynamic> _map(dynamic value) {
  return Map<String, dynamic>.from((value as Map?) ?? {});
}

String _sanitizeMermaidLabel(String text) {
  return text
      .replaceAll('"', "'")
      .replaceAll('\n', ' ')
      .replaceAll(RegExp(r'[\[\]{}()]'), '')
      .trim();
}

/// Converts the `{ "boundedContexts": [...] }` JSON payload into a Mermaid
/// flowchart: bounded context -> use case -> scenarios / sagas -> saga steps.
String useCasesToMermaid(String jsonSource) {
  final boundedContexts = WidgetUseCaseList.parseBoundedContexts(jsonSource);
  final buffer = StringBuffer('flowchart TD\n');

  for (var bcIndex = 0; bcIndex < boundedContexts.length; bcIndex++) {
    final boundedContext = boundedContexts[bcIndex];
    final bcId = 'BC$bcIndex';
    buffer.writeln('  $bcId["${_sanitizeMermaidLabel(boundedContext.name)}"]');

    for (var ucIndex = 0; ucIndex < boundedContext.useCases.length; ucIndex++) {
      final useCase = boundedContext.useCases[ucIndex];
      final ucId = '${bcId}_UC$ucIndex';
      buffer.writeln(
        '  $bcId --> $ucId["${_sanitizeMermaidLabel(useCase.name)}"]',
      );

      for (var scIndex = 0; scIndex < useCase.scenarios.length; scIndex++) {
        final scenario = useCase.scenarios[scIndex];
        final scId = '${ucId}_SC$scIndex';
        final label = '${scenario.type}: ${scenario.title}';
        buffer.writeln(
          '  $ucId --> $scId{{"${_sanitizeMermaidLabel(label)}"}}',
        );
      }

      for (var sagaIndex = 0; sagaIndex < useCase.sagas.length; sagaIndex++) {
        final saga = useCase.sagas[sagaIndex];
        final sagaId = '${ucId}_SAGA$sagaIndex';
        buffer.writeln(
          '  $ucId --> $sagaId(["${_sanitizeMermaidLabel(saga.name)}"])',
        );

        for (
          var stepIndex = 0;
          stepIndex < saga.compensationMatrix.length;
          stepIndex++
        ) {
          final step = saga.compensationMatrix[stepIndex];
          final stepId = '${sagaId}_S$stepIndex';
          buffer.writeln(
            '  $sagaId --> $stepId["${_sanitizeMermaidLabel(step.step)}"]',
          );
        }
      }
    }
  }

  return buffer.toString();
}

/// Converts the `{ "boundedContexts": [...] }` JSON payload into a Markdown document.
String useCasesToMarkdown(String jsonSource) {
  final boundedContexts = WidgetUseCaseList.parseBoundedContexts(jsonSource);
  final buffer = StringBuffer();
  const encoder = JsonEncoder.withIndent('  ');

  void writeBullets(String title, List<String> items) {
    if (items.isEmpty) return;
    buffer.writeln('**$title**\n');
    for (final item in items) {
      buffer.writeln('- $item');
    }
    buffer.writeln();
  }

  void writeJsonBlock(String title, Map<String, dynamic> data) {
    if (data.isEmpty) return;
    buffer.writeln('**$title**\n');
    buffer.writeln('```json');
    buffer.writeln(encoder.convert(data));
    buffer.writeln('```\n');
  }

  for (final boundedContext in boundedContexts) {
    buffer.writeln('# ${boundedContext.name}\n');
    if (boundedContext.description.isNotEmpty) {
      buffer.writeln('${boundedContext.description}\n');
    }

    for (final useCase in boundedContext.useCases) {
      buffer.writeln('## ${useCase.name}\n');
      if (useCase.objective.isNotEmpty) {
        buffer.writeln('${useCase.objective}\n');
      }

      writeJsonBlock('Trigger', useCase.trigger);
      writeBullets('Règles métier', useCase.businessRules);
      writeBullets('Ports', useCase.ports);
      writeBullets('Processus détaillé', useCase.detailedProcess);
      writeJsonBlock('Output', useCase.output);
      writeBullets('Erreurs possibles', useCase.possibleErrors);

      if (useCase.scenarios.isNotEmpty) {
        buffer.writeln('**Scénarios**\n');
        for (final scenario in useCase.scenarios) {
          buffer.writeln('- **${scenario.type}: ${scenario.title}**');
          buffer.writeln('  - Given: ${scenario.given}');
          buffer.writeln('  - When: ${scenario.when}');
          buffer.writeln('  - Then: ${scenario.then}');
        }
        buffer.writeln();
      }

      writeBullets("Critères d'acceptation", useCase.acceptanceCriteria);
      writeBullets('Non-objectifs', useCase.nonGoals);

      for (final saga in useCase.sagas) {
        buffer.writeln('### Saga: ${saga.name}\n');
        if (saga.description.isNotEmpty) {
          buffer.writeln('${saga.description}\n');
        }
        if (saga.textDiagram.isNotEmpty) {
          buffer.writeln('${saga.textDiagram}\n');
        }
        if (saga.mermaidDiagram.isNotEmpty) {
          buffer.writeln('```mermaid');
          buffer.writeln(saga.mermaidDiagram);
          buffer.writeln('```\n');
        }

        if (saga.compensationMatrix.isNotEmpty) {
          buffer.writeln(
            '| Étape | Action nominale | Compensation | Déclencheur rollback | '
            'Criticité | Idempotent | Retryable | Timeout |',
          );
          buffer.writeln('|---|---|---|---|---|---|---|---|');
          for (final row in saga.compensationMatrix) {
            buffer.writeln(
              '| ${row.step} | ${row.nominalAction} | ${row.compensationAction} | '
              '${row.rollbackTrigger} | ${row.criticality} | ${row.idempotent} | '
              '${row.retryable} | ${row.timeout} |',
            );
          }
          buffer.writeln();
        }
      }
    }
  }

  return buffer.toString();
}

class BoundedContextData {
  final String name;
  final String description;
  final List<UseCaseData> useCases;

  BoundedContextData({
    required this.name,
    required this.description,
    required this.useCases,
  });

  factory BoundedContextData.fromJson(Map<String, dynamic> json) {
    return BoundedContextData(
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      useCases: ((json['useCases'] as List?) ?? [])
          .map((e) => UseCaseData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class UseCaseData {
  final String name;
  final String objective;
  final Map<String, dynamic> trigger;
  final List<String> businessRules;
  final List<String> ports;
  final List<String> detailedProcess;
  final Map<String, dynamic> output;
  final List<String> possibleErrors;
  final List<ScenarioData> scenarios;
  final List<String> acceptanceCriteria;
  final List<String> nonGoals;
  final List<SagaData> sagas;

  UseCaseData({
    required this.name,
    required this.objective,
    required this.trigger,
    required this.businessRules,
    required this.ports,
    required this.detailedProcess,
    required this.output,
    required this.possibleErrors,
    required this.scenarios,
    required this.acceptanceCriteria,
    required this.nonGoals,
    required this.sagas,
  });

  factory UseCaseData.fromJson(Map<String, dynamic> json) {
    return UseCaseData(
      name: json['name']?.toString() ?? '',
      objective: json['objective']?.toString() ?? '',
      trigger: _map(json['trigger']),
      businessRules: _stringList(json['businessRules']),
      ports: _stringList(json['ports']),
      detailedProcess: _stringList(json['detailedProcess']),
      output: _map(json['output']),
      possibleErrors: _stringList(json['possibleErrors']),
      scenarios: ((json['scenarios'] as List?) ?? [])
          .map((e) => ScenarioData.fromJson(e as Map<String, dynamic>))
          .toList(),
      acceptanceCriteria: _stringList(json['acceptanceCriteria']),
      nonGoals: _stringList(json['nonGoals']),
      sagas: ((json['sagas'] as List?) ?? [])
          .map((e) => SagaData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ScenarioData {
  final String type;
  final String title;
  final String given;
  final String when;
  final String then;

  ScenarioData({
    required this.type,
    required this.title,
    required this.given,
    required this.when,
    required this.then,
  });

  factory ScenarioData.fromJson(Map<String, dynamic> json) {
    return ScenarioData(
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      given: json['given']?.toString() ?? '',
      when: json['when']?.toString() ?? '',
      then: json['then']?.toString() ?? '',
    );
  }
}

class SagaData {
  final String name;
  final String description;
  final String mermaidDiagram;
  final String textDiagram;
  final List<CompensationRowData> compensationMatrix;

  SagaData({
    required this.name,
    required this.description,
    required this.mermaidDiagram,
    required this.textDiagram,
    required this.compensationMatrix,
  });

  factory SagaData.fromJson(Map<String, dynamic> json) {
    return SagaData(
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      mermaidDiagram: json['mermaidDiagram']?.toString() ?? '',
      textDiagram: json['textDiagram']?.toString() ?? '',
      compensationMatrix: ((json['compensationMatrix'] as List?) ?? [])
          .map((e) => CompensationRowData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CompensationRowData {
  final String step;
  final String nominalAction;
  final String compensationAction;
  final String rollbackTrigger;
  final String criticality;
  final bool idempotent;
  final bool retryable;
  final String timeout;

  CompensationRowData({
    required this.step,
    required this.nominalAction,
    required this.compensationAction,
    required this.rollbackTrigger,
    required this.criticality,
    required this.idempotent,
    required this.retryable,
    required this.timeout,
  });

  factory CompensationRowData.fromJson(Map<String, dynamic> json) {
    return CompensationRowData(
      step: json['step']?.toString() ?? '',
      nominalAction: json['nominalAction']?.toString() ?? '',
      compensationAction: json['compensationAction']?.toString() ?? '',
      rollbackTrigger: json['rollbackTrigger']?.toString() ?? '',
      criticality: json['criticality']?.toString() ?? '',
      idempotent: json['idempotent'] == true,
      retryable: json['retryable'] == true,
      timeout: json['timeout']?.toString() ?? '',
    );
  }
}

class _BoundedContextTile extends StatelessWidget {
  const _BoundedContextTile({required this.boundedContext});

  final BoundedContextData boundedContext;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        title: Text(
          boundedContext.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: boundedContext.description.isEmpty
            ? null
            : Text(boundedContext.description),
        childrenPadding: const EdgeInsets.only(left: 12, bottom: 8),
        expandedAlignment: Alignment.centerLeft,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: boundedContext.useCases
            .map((useCase) => _UseCaseTile(useCase: useCase))
            .toList(),
      ),
    );
  }
}

class _UseCaseTile extends StatelessWidget {
  const _UseCaseTile({required this.useCase});

  final UseCaseData useCase;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(useCase.name)),
          if (useCase.sagas.isNotEmpty) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Contient ${useCase.sagas.length} saga(s)',
              child: const Icon(
                Icons.sync_alt,
                size: 16,
                color: Colors.deepPurple,
              ),
            ),
          ],
        ],
      ),
      subtitle: useCase.objective.isEmpty ? null : Text(useCase.objective),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      expandedAlignment: Alignment.centerLeft,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _JsonSection(title: 'Trigger', data: useCase.trigger),
        _BulletSection(title: 'Règles métier', items: useCase.businessRules),
        _BulletSection(title: 'Ports', items: useCase.ports),
        _BulletSection(
          title: 'Processus détaillé',
          items: useCase.detailedProcess,
        ),
        _JsonSection(title: 'Output', data: useCase.output),
        _BulletSection(
          title: 'Erreurs possibles',
          items: useCase.possibleErrors,
        ),
        _ScenariosSection(scenarios: useCase.scenarios),
        _BulletSection(
          title: "Critères d'acceptation",
          items: useCase.acceptanceCriteria,
        ),
        _BulletSection(title: 'Non-objectifs', items: useCase.nonGoals),
        _SagasSection(sagas: useCase.sagas),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue),
      ),
    );
  }
}

class _BulletSection extends StatelessWidget {
  const _BulletSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('•  $item'),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _JsonSection extends StatelessWidget {
  const _JsonSection({required this.title, required this.data});

  final String title;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    const encoder = JsonEncoder.withIndent('  ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: SelectableText(
            encoder.convert(data),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _ScenariosSection extends StatelessWidget {
  const _ScenariosSection({required this.scenarios});

  final List<ScenarioData> scenarios;

  @override
  Widget build(BuildContext context) {
    if (scenarios.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Scénarios'),
        ...scenarios.map(
          (scenario) => Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(label: Text(scenario.type)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          scenario.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Given: ${scenario.given}'),
                  Text('When: ${scenario.when}'),
                  Text('Then: ${scenario.then}'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SagasSection extends StatelessWidget {
  const _SagasSection({required this.sagas});

  final List<SagaData> sagas;

  @override
  Widget build(BuildContext context) {
    if (sagas.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Sagas'),
        ...sagas.map((saga) => _SagaCard(saga: saga)),
      ],
    );
  }
}

class _SagaCard extends StatelessWidget {
  const _SagaCard({required this.saga});

  final SagaData saga;

  static const _criticalityColors = {
    'CRITICAL': Colors.red,
    'HIGH': Colors.orange,
    'MEDIUM': Colors.amber,
    'LOW': Colors.green,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              saga.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (saga.description.isNotEmpty) Text(saga.description),
            if (saga.textDiagram.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(saga.textDiagram),
            ],
            if (saga.mermaidDiagram.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  saga.mermaidDiagram,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
            if (saga.compensationMatrix.isNotEmpty) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Étape')),
                    DataColumn(label: Text('Action nominale')),
                    DataColumn(label: Text('Compensation')),
                    DataColumn(label: Text('Déclencheur rollback')),
                    DataColumn(label: Text('Criticité')),
                    DataColumn(label: Text('Idempotent')),
                    DataColumn(label: Text('Retryable')),
                    DataColumn(label: Text('Timeout')),
                  ],
                  rows: saga.compensationMatrix
                      .map(
                        (row) => DataRow(
                          cells: [
                            DataCell(Text(row.step)),
                            DataCell(Text(row.nominalAction)),
                            DataCell(Text(row.compensationAction)),
                            DataCell(Text(row.rollbackTrigger)),
                            DataCell(
                              Text(
                                row.criticality,
                                style: TextStyle(
                                  color:
                                      _criticalityColors[row.criticality
                                          .toUpperCase()],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Icon(
                                row.idempotent ? Icons.check : Icons.close,
                                size: 16,
                              ),
                            ),
                            DataCell(
                              Icon(
                                row.retryable ? Icons.check : Icons.close,
                                size: 16,
                              ),
                            ),
                            DataCell(Text(row.timeout)),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
