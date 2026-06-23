import 'package:flutter/material.dart';
import 'block_model.dart';
import 'link_model.dart';

// Theme colors (same as in widget_miro_like.dart)
const Color colorPropertiesPanelBg = Color.fromARGB(255, 24, 24, 27);
const Color colorPanelBorder = Color.fromARGB(255, 71, 71, 74);
const Color colorBlockBackground = Color.fromARGB(255, 33, 33, 36);
const Color colorTextPrimary = Colors.white;
const Color colorTextSecondary = Color.fromARGB(179, 255, 255, 255);

/// Properties panel widget that displays block or link properties
class PropertiesPanel extends StatefulWidget {
  final Block? selectedBlock;
  final BlockLink? selectedLink;
  final Function(String, String)? onBlockTitleChanged;
  final Function(BlockLink, String)? onLinkNameChanged;
  final Function(BlockLink, String?)? onLinkLabelIconChanged;
  final Function(BlockLink, double)? onLinkParticleDensityChanged;
  final Function(BlockLink, double)? onLinkParticleSpeedChanged;
  final Function(BlockLink, double)? onLinkLabelPositionChanged;
  final Function(BlockLink, Offset)? onLinkLabelOffsetChanged;
  final Function(BlockLink)? onReverseLink;
  final Function(BlockLink)? onDeleteLink;
  final Function(BlockLink, ConnectorType)? onConnectorTypeChanged;

  const PropertiesPanel({
    super.key,
    this.selectedBlock,
    this.selectedLink,
    this.onBlockTitleChanged,
    this.onLinkNameChanged,
    this.onLinkLabelIconChanged,
    this.onLinkParticleDensityChanged,
    this.onLinkParticleSpeedChanged,
    this.onLinkLabelPositionChanged,
    this.onLinkLabelOffsetChanged,
    this.onReverseLink,
    this.onDeleteLink,
    this.onConnectorTypeChanged,
  });

  @override
  State<PropertiesPanel> createState() => _PropertiesPanelState();
}

class _PropertiesPanelState extends State<PropertiesPanel> {
  late TextEditingController _blockTitleController;
  late TextEditingController _linkNameController;

  @override
  void initState() {
    super.initState();
    _blockTitleController = TextEditingController();
    _linkNameController = TextEditingController();
    if (widget.selectedBlock != null) {
      _blockTitleController.text = widget.selectedBlock!.title;
    }
    if (widget.selectedLink != null) {
      _linkNameController.text = widget.selectedLink!.name;
    }
  }

  @override
  void didUpdateWidget(PropertiesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedBlock != null &&
        oldWidget.selectedBlock?.id != widget.selectedBlock?.id) {
      _blockTitleController.text = widget.selectedBlock!.title;
    }
    if (widget.selectedLink != null &&
        (oldWidget.selectedLink?.fromBlockId !=
                widget.selectedLink?.fromBlockId ||
            oldWidget.selectedLink?.toBlockId !=
                widget.selectedLink?.toBlockId)) {
      _linkNameController.text = widget.selectedLink!.name;
    }
  }

  @override
  void dispose() {
    _blockTitleController.dispose();
    _linkNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.selectedBlock;
    final link = widget.selectedLink;

    if (block != null) {
      return _buildBlockProperties(block);
    }

    if (link != null) {
      return _buildLinkProperties(link);
    }

    return _buildEmptyProperties();
  }

  Widget _buildBlockProperties(Block block) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: colorPropertiesPanelBg,
        border: Border(left: BorderSide(color: colorPanelBorder)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Proprietes du bloc',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'ID: ${block.id}',
            style: const TextStyle(color: colorTextSecondary),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('block-title-${block.id}'),
            controller: _blockTitleController,
            style: const TextStyle(color: colorTextPrimary),
            decoration: InputDecoration(
              labelText: 'Titre',
              labelStyle: const TextStyle(color: colorTextSecondary),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: colorPanelBorder),
              ),
              isDense: true,
            ),
            onChanged: (value) {
              widget.onBlockTitleChanged?.call(block.id, value);
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Position X: ${block.position.dx.toStringAsFixed(1)}',
            style: const TextStyle(color: colorTextSecondary),
          ),
          Text(
            'Position Y: ${block.position.dy.toStringAsFixed(1)}',
            style: const TextStyle(color: colorTextSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Largeur: ${block.size.width.toStringAsFixed(1)}',
            style: const TextStyle(color: colorTextSecondary),
          ),
          Text(
            'Hauteur: ${block.size.height.toStringAsFixed(1)}',
            style: const TextStyle(color: colorTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkProperties(BlockLink link) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: colorPropertiesPanelBg,
        border: Border(left: BorderSide(color: colorPanelBorder)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Proprietes du lien',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Source: ${link.fromBlockId}',
            style: const TextStyle(color: colorTextSecondary),
          ),
          Text(
            'Cible: ${link.toBlockId}',
            style: const TextStyle(color: colorTextSecondary),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('link-name-${link.fromBlockId}-${link.toBlockId}'),
            controller: _linkNameController,
            style: const TextStyle(color: colorTextPrimary),
            decoration: InputDecoration(
              labelText: 'Nom du lien',
              labelStyle: const TextStyle(color: colorTextSecondary),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: colorPanelBorder),
              ),
              isDense: true,
            ),
            onChanged: (value) {
              widget.onLinkNameChanged?.call(link, value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: link.labelIconKey,
            dropdownColor: colorBlockBackground,
            style: const TextStyle(color: colorTextPrimary),
            decoration: InputDecoration(
              labelText: 'Icone du label',
              labelStyle: const TextStyle(color: colorTextSecondary),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: colorPanelBorder),
              ),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  'Aucune',
                  style: TextStyle(color: colorTextPrimary),
                ),
              ),
              ...kLinkLabelIconMap.entries.map((entry) {
                final label = kLinkLabelIconLabelMap[entry.key] ?? entry.key;
                return DropdownMenuItem<String?>(
                  value: entry.key,
                  child: Row(
                    children: [
                      Icon(entry.value, size: 16, color: colorTextPrimary),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(color: colorTextPrimary),
                      ),
                    ],
                  ),
                );
              }),
            ],
            onChanged: (value) {
              widget.onLinkLabelIconChanged?.call(link, value);
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Densité particules: ${(link.particleDensity * 100).round()}%',
            style: const TextStyle(color: colorTextSecondary),
          ),
          Slider(
            value: link.particleDensity.clamp(0.2, 3.0),
            min: 0.2,
            max: 3.0,
            divisions: 28,
            label: '${(link.particleDensity * 100).round()}%',
            onChanged: (value) {
              widget.onLinkParticleDensityChanged?.call(link, value);
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Vitesse particules: ${(link.particleSpeed * 100).round()}%',
            style: const TextStyle(color: colorTextSecondary),
          ),
          Slider(
            value: link.particleSpeed.clamp(0.2, 3.0),
            min: 0.2,
            max: 3.0,
            divisions: 28,
            label: '${(link.particleSpeed * 100).round()}%',
            onChanged: (value) {
              widget.onLinkParticleSpeedChanged?.call(link, value);
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Position du label: ${(link.labelPosition * 100).round()}%',
            style: const TextStyle(color: colorTextSecondary),
          ),
          Slider(
            value: link.labelPosition.clamp(0.0, 1.0),
            min: 0.0,
            max: 1.0,
            divisions: 20,
            label: '${(link.labelPosition * 100).round()}%',
            onChanged: (value) {
              widget.onLinkLabelPositionChanged?.call(link, value);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Décalage label: ${link.labelOffset.dx.toStringAsFixed(1)}, ${link.labelOffset.dy.toStringAsFixed(1)}',
                  style: const TextStyle(color: colorTextSecondary),
                ),
              ),
              IconButton(
                onPressed: () {
                  widget.onLinkLabelOffsetChanged?.call(link, Offset.zero);
                },
                icon: const Icon(Icons.restart_alt),
                iconSize: 18,
                tooltip: 'Remettre à zéro',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<ConnectorType>(
            initialValue: link.connectorType,
            dropdownColor: colorBlockBackground,
            style: const TextStyle(color: colorTextPrimary),
            decoration: InputDecoration(
              labelText: 'Type de lien',
              labelStyle: const TextStyle(color: colorTextSecondary),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: colorPanelBorder),
              ),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(
                value: ConnectorType.bezier,
                child: Text(
                  'Bezier',
                  style: TextStyle(color: colorTextPrimary),
                ),
              ),
              DropdownMenuItem(
                value: ConnectorType.orthogonal,
                child: Text(
                  'Orthogonale',
                  style: TextStyle(color: colorTextPrimary),
                ),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                widget.onConnectorTypeChanged?.call(link, value);
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Points d\'inflexion: ${link.inflectionPoints.length}',
            style: const TextStyle(color: colorTextSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Ancre source: ${link.sourceAnchorUnit?.toString() ?? 'auto'}',
            style: const TextStyle(color: colorTextSecondary),
          ),
          Text(
            'Ancre cible: ${link.targetAnchorUnit?.toString() ?? 'auto'}',
            style: const TextStyle(color: colorTextSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => widget.onReverseLink?.call(link),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Inverser'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => widget.onDeleteLink?.call(link),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyProperties() {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: colorPropertiesPanelBg,
        border: Border(left: BorderSide(color: colorPanelBorder)),
      ),
      padding: const EdgeInsets.all(16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proprietes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorTextPrimary,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Selectionnez un bloc ou un lien.',
            style: TextStyle(color: colorTextSecondary),
          ),
        ],
      ),
    );
  }
}
