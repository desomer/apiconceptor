class HeaderSpec {
  final String kind;
  final String name;
  final String title;
  final String domain;
  final String description;
  final String created;
  final String updated;
  final String tags;
  final String generationDomain;
  final String version;

  HeaderSpec({
    required this.kind,
    required this.name,
    required this.title,
    required this.domain,
    required this.description,
    required this.created,
    required this.updated,
    required this.tags,
    required this.generationDomain,
    required this.version,
  });   
}

String fillHeader(String md, HeaderSpec kind) {
  return md
      .replaceAll('{{kind}}', kind.kind)
      .replaceAll('{{name}}', kind.name)
      .replaceAll('{{title}}', kind.title)
      .replaceAll('{{domain}}', kind.domain)
      .replaceAll('{{description}}', kind.description)
      .replaceAll('{{created}}', kind.created)
      .replaceAll('{{updated}}', kind.updated)
      .replaceAll('{{tags}}', kind.tags)
      .replaceAll('{{generationDomain}}', kind.generationDomain)
      .replaceAll('{{version}}', kind.version);
}

String promptHeader = '''```
kind: {{kind}}

name: {{name}}
title: {{title}}
version: {{version}}

domain: {{domain}}

description:
    {{description}}

owner: {{domain}}-team
status: approved

tags:
{{tags}}

security:
    classification: internal

ai:
    searchable: true
    embeddable: true

generation:
{{generationDomain}}

metadata:
    created: {{created}}
    updated: {{updated}}
```''';
