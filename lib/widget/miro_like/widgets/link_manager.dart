import 'package:flutter/material.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:url_launcher/url_launcher.dart';

/// Represents a web link with type and metadata
class WebLink {
  final String id;
  final String name;
  final LinkType type;
  final String url;

  WebLink({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
  });

  WebLink copyWith({String? id, String? name, LinkType? type, String? url}) {
    return WebLink(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      url: url ?? this.url,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'type': type.name, 'url': url};
  }

  static WebLink? fromJson(dynamic value) {
    if (value is! Map) {
      return null;
    }
    final id = value['id']?.toString() ?? '';
    final name = value['name']?.toString() ?? '';
    final url = value['url']?.toString() ?? '';
    final typeRaw = value['type']?.toString() ?? '';
    final type = LinkType.values.where((e) => e.name == typeRaw).firstOrNull;
    if (id.isEmpty || name.isEmpty || url.isEmpty || type == null) {
      return null;
    }
    return WebLink(id: id, name: name, type: type, url: url);
  }
}

/// Link type enumeration
enum LinkType {
  model('Model', Color(0xFF2196F3)),
  topic('Topic', Color(0xFF4CAF50)),
  api('API', Color(0xFFFF9800)),
  file('File', Color(0xFF9C27B0));

  final String label;
  final Color color;

  const LinkType(this.label, this.color);
}

Future<void> openWebLink(WebLink link, BuildContext context) async {

  if (link.url.trim().startsWith(Pages.modelDetail.urlpath)) {
    await prepareDeepLinking(Uri.parse(link.url));
    // ignore: use_build_context_synchronously
    RouteManager.goto(link.url, context);
    return;
  }


  final uri = Uri.tryParse(link.url.trim());
  if (uri == null) {
    return;
  }
  await launchUrl(uri, mode: LaunchMode.platformDefault);
}

Future<void> openWebLinks(
  BuildContext context,
  List<WebLink> links, {
  Color? backgroundColor,
  Color titleColor = Colors.white,
  Color subtitleColor = const Color.fromARGB(179, 255, 255, 255),
}) async {
  if (links.isEmpty) {
    return;
  }

  if (links.length == 1) {
    await openWebLink(links.first, context);
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: backgroundColor,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'Choisir un lien',
                style: TextStyle(color: titleColor),
              ),
            ),
            for (final entry in links)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: entry.type.color,
                  foregroundColor: Colors.white,
                  child: Text(entry.type.label[0]),
                ),
                title: Text(entry.name, style: TextStyle(color: titleColor)),
                subtitle: Text(
                  entry.url,
                  style: TextStyle(color: subtitleColor),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await openWebLink(entry, context);
                },
              ),
          ],
        ),
      );
    },
  );
}

/// Widget to manage a list of typed web links displayed as wrap tags
class WebLinkManager extends StatefulWidget {
  final List<WebLink> links;
  final ValueChanged<List<WebLink>> onLinksChanged;

  const WebLinkManager({
    super.key,
    required this.links,
    required this.onLinksChanged,
  });

  @override
  State<WebLinkManager> createState() => _WebLinkManagerState();
}

class _WebLinkManagerState extends State<WebLinkManager> {
  late List<WebLink> _links;

  @override
  void initState() {
    super.initState();
    _links = List.from(widget.links);
  }

  @override
  void didUpdateWidget(WebLinkManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.links != widget.links) {
      _links = List.from(widget.links);
    }
  }

  void _addLink() {
    showDialog(
      context: context,
      builder: (context) => _LinkDialog(
        onSave: (name, type, url) {
          setState(() {
            _links.add(
              WebLink(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                type: type,
                url: url,
              ),
            );
          });
          widget.onLinksChanged(_links);
        },
      ),
    );
  }

  void _removeLink(WebLink link) {
    setState(() {
      _links.removeWhere((l) => l.id == link.id);
    });
    widget.onLinksChanged(_links);
  }

  void _editLink(WebLink link) {
    showDialog(
      context: context,
      builder: (context) => _LinkDialog(
        initialLink: link,
        onSave: (name, type, url) {
          setState(() {
            final index = _links.indexWhere((l) => l.id == link.id);
            if (index == -1) {
              return;
            }
            _links[index] = link.copyWith(name: name, type: type, url: url);
          });
          widget.onLinksChanged(_links);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._links.map(
              (link) => _LinkTag(
                link: link,
                onTap: () => _editLink(link),
                onDoubleTap: () => openWebLink(link, context),
                onRemove: () => _removeLink(link),
              ),
            ),

            TextButton.icon(
              onPressed: _addLink,
              icon: const Icon(Icons.add),
              label: const Text('Add Link'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Widget for individual link tag
class _LinkTag extends StatelessWidget {
  final WebLink link;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onRemove;

  const _LinkTag({
    required this.link,
    required this.onTap,
    required this.onDoubleTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${link.url}\nClick: edit\nDouble-click: open',
      child: GestureDetector(
        onDoubleTap: onDoubleTap,
        child: InputChip(
          label: Text(link.name),
          backgroundColor: link.type.color.withValues(alpha: 0.2),
          side: BorderSide(color: link.type.color),
          avatar: CircleAvatar(
            backgroundColor: link.type.color,
            foregroundColor: Colors.white,
            child: Text(
              link.type.label[0],
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          onPressed: onTap,
          onDeleted: onRemove,
        ),
      ),
    );
  }
}

/// Dialog for adding/editing a link
class _LinkDialog extends StatefulWidget {
  final Function(String name, LinkType type, String url) onSave;
  final WebLink? initialLink;

  const _LinkDialog({required this.onSave, this.initialLink});

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late LinkType _selectedType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialLink?.name ?? '',
    );
    _urlController = TextEditingController(text: widget.initialLink?.url ?? '');
    _selectedType = widget.initialLink?.type ?? LinkType.model;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.isEmpty || _urlController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }
    widget.onSave(_nameController.text, _selectedType, _urlController.text);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialLink == null ? 'Add Link' : 'Edit Link'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<LinkType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: LinkType.values
                  .map(
                    (type) =>
                        DropdownMenuItem(value: type, child: Text(type.label)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
