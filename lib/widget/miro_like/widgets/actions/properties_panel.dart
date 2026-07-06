import 'package:flutter/material.dart';
import 'package:jsonschema/authorization_manager.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/miro_like/mermaid_sequence_codec.dart';
import 'package:jsonschema/widget/miro_like/models/link_manager.dart';
import 'package:jsonschema/widget/miro_like/widget_miro_like.dart';
import 'package:jsonschema/widget/miro_like/widgets/link_manager.dart';
import 'package:jsonschema/widget/widget_tooltip.dart';
import 'dart:convert';
import '../../models/block_model.dart';
import '../../models/link_model.dart';
import '../image2base64_widget.dart';

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
  final SequenceControlGroupInfo? selectedSequenceGroup;
  final int selectedBlockCount;
  final int selectedMessageCount;
  final bool canCreateSequenceGroupFromSelection;
  final String? createSequenceGroupValidationMessage;
  final Function(String kind, String label, bool nested)?
  onCreateSequenceGroupFromSelection;
  final bool canCreateSubgraphFromSelection;
  final Function(String label)? onCreateSubgraphFromSelection;
  final Function(SequenceControlGroupInfo, String, String)?
  onSequenceGroupChanged;
  final Function(SequenceControlGroupInfo)? onDeleteSequenceGroup;
  final Function(SequenceControlGroupInfo)? onAddElseToSequenceGroup;
  final Function(String, String)? onBlockTitleChanged;
  final Function(Block, String?)? onBlockColorChanged;
  final Function(Block, BlockNodeShape)? onBlockNodeShapeChanged;
  final Function(Block, List<String>)? onBlockTagsChanged;
  final Function(Block, String)? onBlockIconBase64Changed;
  final Function(Block, String)? onBlockPropertiesJsonChanged;
  final bool canToggleCurrentSubgraphMembership;
  final bool selectedBlockInCurrentSubgraph;
  final String? currentSubgraphTitle;
  final VoidCallback? onToggleCurrentSubgraphMembership;
  final Function(Block)? onZoneBringToFront;
  final Function(Block)? onZoneSendToBack;
  final Function(Block, bool)? onZoneTransparencyChanged;
  final Function(Block, ZoneBorderStyle)? onZoneBorderStyleChanged;
  final Function(BlockLink, String)? onLinkNameChanged;
  final Function(BlockLink, String?)? onLinkColorChanged;
  final Function(BlockLink, String?)? onLinkLabelIconChanged;
  final Function(BlockLink, double)? onLinkParticleDensityChanged;
  final Function(BlockLink, double)? onLinkParticleSpeedChanged;
  final Function(BlockLink, double)? onLinkLabelPositionChanged;
  final Function(BlockLink, Offset)? onLinkLabelOffsetChanged;
  final Function(BlockLink)? onReverseLink;
  final Function(BlockLink)? onDeleteLink;
  final Function(BlockLink, ConnectorType)? onConnectorTypeChanged;
  final Function(BlockLink, bool)? onLinkAutoLayoutLockChanged;
  final Function(BlockLink, String)? onLinkWebLinksJsonChanged;
  final Function(BlockLink, String?)? onLinkSequenceArrowTypeChanged;
  final bool isSequenceDiagramMode;

  const PropertiesPanel({
    super.key,
    this.selectedBlock,
    this.selectedLink,
    this.selectedSequenceGroup,
    this.selectedBlockCount = 0,
    this.selectedMessageCount = 0,
    this.canCreateSequenceGroupFromSelection = false,
    this.createSequenceGroupValidationMessage,
    this.onCreateSequenceGroupFromSelection,
    this.canCreateSubgraphFromSelection = false,
    this.onCreateSubgraphFromSelection,
    this.onSequenceGroupChanged,
    this.onDeleteSequenceGroup,
    this.onAddElseToSequenceGroup,
    this.onBlockTitleChanged,
    this.onBlockColorChanged,
    this.onBlockNodeShapeChanged,
    this.onBlockTagsChanged,
    this.onBlockIconBase64Changed,
    this.onBlockPropertiesJsonChanged,
    this.canToggleCurrentSubgraphMembership = false,
    this.selectedBlockInCurrentSubgraph = false,
    this.currentSubgraphTitle,
    this.onToggleCurrentSubgraphMembership,
    this.onZoneBringToFront,
    this.onZoneSendToBack,
    this.onZoneTransparencyChanged,
    this.onZoneBorderStyleChanged,
    this.onLinkNameChanged,
    this.onLinkColorChanged,
    this.onLinkLabelIconChanged,
    this.onLinkParticleDensityChanged,
    this.onLinkParticleSpeedChanged,
    this.onLinkLabelPositionChanged,
    this.onLinkLabelOffsetChanged,
    this.onReverseLink,
    this.onDeleteLink,
    this.onConnectorTypeChanged,
    this.onLinkAutoLayoutLockChanged,
    this.onLinkWebLinksJsonChanged,
    this.onLinkSequenceArrowTypeChanged,
    this.isSequenceDiagramMode = false,
  });

  @override
  State<PropertiesPanel> createState() => _PropertiesPanelState();
}

class _FlowArrowLegendPainter extends CustomPainter {
  final Color color;
  final bool dashed;
  final bool thick;
  final bool bidirectional;
  final bool headless;

  const _FlowArrowLegendPainter({
    required this.color,
    required this.dashed,
    required this.thick,
    required this.bidirectional,
    required this.headless,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final startX = 3.0;
    final endX = size.width - 3.0;
    final stroke = thick ? 2.4 : 1.5;

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    if (!dashed) {
      canvas.drawLine(Offset(startX, y), Offset(endX, y), linePaint);
    } else {
      const dash = 4.0;
      const gap = 2.4;
      var x = startX;
      while (x < endX) {
        final next = (x + dash).clamp(startX, endX).toDouble();
        canvas.drawLine(Offset(x, y), Offset(next, y), linePaint);
        x = next + gap;
      }
    }

    if (!headless) {
      _drawHead(canvas, Offset(endX, y), color, stroke, false);
      if (bidirectional) {
        _drawHead(canvas, Offset(startX, y), color, stroke, true);
      }
    }
  }

  void _drawHead(
    Canvas canvas,
    Offset tip,
    Color color,
    double stroke,
    bool left,
  ) {
    final headLen = 4.8;
    final headHalf = 2.7;
    final dir = left ? 1.0 : -1.0;
    final p1 = Offset(tip.dx + dir * headLen, tip.dy - headHalf);
    final p2 = Offset(tip.dx + dir * headLen, tip.dy + headHalf);

    final headPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(tip, p1, headPaint);
    canvas.drawLine(tip, p2, headPaint);
  }

  @override
  bool shouldRepaint(covariant _FlowArrowLegendPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dashed != dashed ||
        oldDelegate.thick != thick ||
        oldDelegate.bidirectional != bidirectional ||
        oldDelegate.headless != headless;
  }
}

class _PropertiesPanelState extends State<PropertiesPanel> {
  static const String _sequenceMessageKindMessage = 'message';
  static const String _sequenceMessageKindNoteOver = 'note-over';
  static const String _sequenceMessageKindNoteFlow = 'note-flow';

  static const List<String> _mermaidArrowTypeOptions = [
    '->>',
    '-->>',
    '->',
    '-->',
    '->x',
    '--x',
    '-)',
    '--)',
  ];

  static const List<String> _flowArrowTypeOptions = [
    '-->',
    '==>',
    '=>',
    '-.->',
    '.->',
    '==.=>',
    '=.=>',
    '---',
    '-.-',
    '<-->',
    '<.->',
  ];

  late TextEditingController _blockTitleController;
  late TextEditingController _blockJsonController;
  late TextEditingController _linkNameController;
  late TextEditingController _sequenceGroupLabelController;
  late TextEditingController _selectionGroupLabelController;
  late TextEditingController _selectionSubgraphLabelController;
  String _sequenceGroupKind = 'alt';
  String _selectionGroupKind = 'alt';
  String _selectionGroupPlacement = 'nested';
  String? _blockJsonError;

  @override
  void initState() {
    super.initState();
    _blockTitleController = TextEditingController();
    _blockJsonController = TextEditingController();
    _linkNameController = TextEditingController();
    _sequenceGroupLabelController = TextEditingController();
    _selectionGroupLabelController = TextEditingController();
    _selectionSubgraphLabelController = TextEditingController();
    if (widget.selectedBlock != null) {
      _blockTitleController.text = widget.selectedBlock!.title;
      _blockJsonController.text = widget.selectedBlock!.propertiesJson ?? '';
    }
    if (widget.selectedLink != null) {
      _linkNameController.text = widget.selectedLink!.name;
    }
    if (widget.selectedSequenceGroup != null) {
      final group = widget.selectedSequenceGroup!;
      final isElseBranchSelection =
          group.kind == 'alt' &&
          group.targetBranchIndex != null &&
          group.targetBranchIndex! > 0;
      if (isElseBranchSelection) {
        final elseIdx = group.targetBranchIndex! - 1;
        final elseLabel = elseIdx >= 0 && elseIdx < group.branchLabels.length
            ? group.branchLabels[elseIdx]
            : '';
        _sequenceGroupLabelController.text = elseLabel;
      } else {
        _sequenceGroupLabelController.text = group.label;
      }
      _sequenceGroupKind = widget.selectedSequenceGroup!.kind;
    }
  }

  @override
  void didUpdateWidget(PropertiesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedBlock != null &&
        oldWidget.selectedBlock?.id != widget.selectedBlock?.id) {
      _blockTitleController.text = widget.selectedBlock!.title;
      _blockJsonController.text = widget.selectedBlock!.propertiesJson ?? '';
      _blockJsonError = null;
    }
    if (widget.selectedLink != null &&
        (oldWidget.selectedLink?.fromBlockId !=
                widget.selectedLink?.fromBlockId ||
            oldWidget.selectedLink?.toBlockId !=
                widget.selectedLink?.toBlockId)) {
      _linkNameController.text = widget.selectedLink!.name;
    }
    if (widget.selectedSequenceGroup != null &&
        oldWidget.selectedSequenceGroup?.selectionKey !=
            widget.selectedSequenceGroup?.selectionKey) {
      final group = widget.selectedSequenceGroup!;
      final isElseBranchSelection =
          group.kind == 'alt' &&
          group.targetBranchIndex != null &&
          group.targetBranchIndex! > 0;
      if (isElseBranchSelection) {
        final elseIdx = group.targetBranchIndex! - 1;
        final elseLabel = elseIdx >= 0 && elseIdx < group.branchLabels.length
            ? group.branchLabels[elseIdx]
            : '';
        _sequenceGroupLabelController.text = elseLabel;
      } else {
        _sequenceGroupLabelController.text = group.label;
      }
      _sequenceGroupKind = group.kind;
    }
  }

  @override
  void dispose() {
    _blockTitleController.dispose();
    _blockJsonController.dispose();
    _linkNameController.dispose();
    _sequenceGroupLabelController.dispose();
    _selectionGroupLabelController.dispose();
    _selectionSubgraphLabelController.dispose();
    super.dispose();
  }

  void _applyBlockPropertiesJson(Block block) {
    final raw = _blockJsonController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _blockJsonError = null;
      });
      widget.onBlockPropertiesJsonChanged?.call(block, '');
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        setState(() {
          _blockJsonError = 'Le JSON doit être un objet (clé/valeur).';
        });
        return;
      }

      setState(() {
        _blockJsonError = null;
      });
      widget.onBlockPropertiesJsonChanged?.call(block, raw);
    } catch (_) {
      setState(() {
        _blockJsonError = 'JSON invalide.';
      });
    }
  }

  void _populateJsonFromBlock(Block block) {
    final resolvedIcon = _resolvedBlockIconBase64(block);
    final payload = <String, dynamic>{
      'title': block.title,
      'colorKey': block.colorKey,
      'tagColorKeys': List<String>.from(block.tagColorKeys),
      'iconBase64': resolvedIcon,
      'size': {'width': block.size.width, 'height': block.size.height},
    };

    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    setState(() {
      _blockJsonController.text = encoded;
      _blockJsonError = null;
    });
    widget.onBlockPropertiesJsonChanged?.call(block, encoded);
  }

  void _removeBlockIcon(Block block) {
    widget.onBlockIconBase64Changed?.call(block, '');

    final raw = _blockJsonController.text.trim();
    if (raw.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      if (!decoded.containsKey('iconBase64')) {
        return;
      }

      decoded.remove('iconBase64');
      final encoded = const JsonEncoder.withIndent('  ').convert(decoded);
      setState(() {
        _blockJsonController.text = encoded;
        _blockJsonError = null;
      });
      widget.onBlockPropertiesJsonChanged?.call(block, encoded);
    } catch (_) {
      // Keep behavior simple if JSON is currently invalid.
    }
  }

  String? _resolvedBlockIconBase64(Block block) {
    final rawJson = (block.propertiesJson ?? '').trim();
    if (rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map<String, dynamic>) {
          final dynamicIcon = decoded['iconBase64'];
          if (dynamicIcon != null) {
            final resolved = dynamicIcon.toString().trim();
            if (resolved.isNotEmpty) {
              return resolved;
            }
          }
        }
      } catch (_) {
        // Keep fallback behavior when JSON is invalid.
      }
    }

    final fallback = (block.iconBase64 ?? '').trim();
    return fallback.isEmpty ? null : fallback;
  }

  List<WebLink> _webLinksFromLink(BlockLink link) {
    final raw = (link.webLinksJson ?? '').trim();
    if (raw.isEmpty) {
      return const <WebLink>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <WebLink>[];
      }
      return decoded
          .map(WebLink.fromJson)
          .whereType<WebLink>()
          .toList(growable: false);
    } catch (_) {
      return const <WebLink>[];
    }
  }

  String _webLinksToJson(List<WebLink> links) {
    return jsonEncode(
      links.map((link) => link.toJson()).toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.selectedBlock;
    final link = widget.selectedLink;
    final sequenceGroup = widget.selectedSequenceGroup;
    final hasMultiSelection =
        widget.selectedBlockCount > 1 || widget.selectedMessageCount > 1;

    if (block != null) {
      return _buildBlockProperties(block);
    }

    if (link != null) {
      return _buildLinkProperties(link);
    }

    if (sequenceGroup != null) {
      return _buildSequenceGroupProperties(sequenceGroup);
    }

    if (hasMultiSelection) {
      return _buildSelectionProperties();
    }

    return _buildEmptyProperties();
  }

  Widget _buildSelectionProperties() {
    final blockCount = widget.selectedBlockCount;
    final messageCount = widget.selectedMessageCount;
    final totalCount = blockCount + messageCount;
    final groupKinds = <String>['alt', 'opt', 'loop'];
    final effectiveKind = groupKinds.contains(_selectionGroupKind)
        ? _selectionGroupKind
        : 'alt';

    return _buildPanelContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Proprietes de la selection',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Elements selectionnes: $totalCount',
            style: const TextStyle(color: colorTextSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'Blocs: $blockCount',
            style: const TextStyle(color: colorTextSecondary),
          ),
          Text(
            'Messages: $messageCount',
            style: const TextStyle(color: colorTextSecondary),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorBlockBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorPanelBorder),
            ),
            child: const Text(
              'Cette zone servira pour les actions de selection (ex: creation de cadre).',
              style: TextStyle(color: colorTextSecondary, fontSize: 12),
            ),
          ),
          if (widget.selectedBlockCount > 1) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _selectionSubgraphLabelController,
              style: const TextStyle(color: colorTextPrimary),
              decoration: InputDecoration(
                labelText: 'Nom du subgraph (optionnel)',
                labelStyle: const TextStyle(color: colorTextSecondary),
                hintText: 'ex: Auth domain',
                hintStyle: const TextStyle(color: colorTextSecondary),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: colorPanelBorder),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.canCreateSubgraphFromSelection
                    ? () {
                        FocusScope.of(context).unfocus();
                        widget.onCreateSubgraphFromSelection?.call(
                          _selectionSubgraphLabelController.text,
                        );
                      }
                    : null,
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('Creer un subgraph'),
              ),
            ),
          ],
          if (widget.selectedMessageCount > 0) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectionGroupPlacement,
              dropdownColor: colorBlockBackground,
              style: const TextStyle(color: colorTextPrimary),
              decoration: InputDecoration(
                labelText: 'Placement du cadre',
                labelStyle: const TextStyle(color: colorTextSecondary),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: colorPanelBorder),
                ),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem<String>(
                  value: 'nested',
                  child: Text('Interne (imbrique)'),
                ),
                DropdownMenuItem<String>(
                  value: 'outer',
                  child: Text('Externe'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectionGroupPlacement = value;
                });
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: effectiveKind,
              dropdownColor: colorBlockBackground,
              style: const TextStyle(color: colorTextPrimary),
              decoration: InputDecoration(
                labelText: 'Type du cadre',
                labelStyle: const TextStyle(color: colorTextSecondary),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: colorPanelBorder),
                ),
                isDense: true,
              ),
              items: groupKinds
                  .map(
                    (kind) => DropdownMenuItem<String>(
                      value: kind,
                      child: Text(kind),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectionGroupKind = value;
                });
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _selectionGroupLabelController,
              style: const TextStyle(color: colorTextPrimary),
              decoration: InputDecoration(
                labelText: 'Label du cadre (optionnel)',
                labelStyle: const TextStyle(color: colorTextSecondary),
                hintText: 'ex: auth flow',
                hintStyle: const TextStyle(color: colorTextSecondary),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: colorPanelBorder),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.canCreateSequenceGroupFromSelection
                    ? () {
                        FocusScope.of(context).unfocus();
                        widget.onCreateSequenceGroupFromSelection?.call(
                          effectiveKind,
                          _selectionGroupLabelController.text,
                          _selectionGroupPlacement == 'nested',
                        );
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) {
                            return;
                          }
                          setState(() {});
                        });
                      }
                    : null,
                icon: const Icon(Icons.crop_square),
                label: const Text('Creer un cadre'),
              ),
            ),
            if (widget.createSequenceGroupValidationMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.createSequenceGroupValidationMessage!,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSequenceGroupProperties(SequenceControlGroupInfo group) {
    final height = (group.endYCanvas - group.startYCanvas).clamp(0.0, 1e9);
    final normalizedKind = group.kind.trim().toLowerCase();
    final isElseBranchSelection =
        normalizedKind == 'alt' &&
        group.targetBranchIndex != null &&
        group.targetBranchIndex! > 0;
    final selectedBranchIndex = group.targetBranchIndex ?? 0;
    final selectedElseLabel =
        isElseBranchSelection &&
            selectedBranchIndex - 1 >= 0 &&
            selectedBranchIndex - 1 < group.branchLabels.length
        ? group.branchLabels[selectedBranchIndex - 1]
        : '';
    final groupKinds = <String>['alt', 'opt', 'loop'];
    final effectiveKind = groupKinds.contains(_sequenceGroupKind)
        ? _sequenceGroupKind
        : (groupKinds.contains(normalizedKind) ? normalizedKind : 'alt');

    return _buildPanelContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Proprietes du groupe',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isElseBranchSelection
                ? 'Type: else (branche $selectedBranchIndex)'
                : 'Type: ${normalizedKind.isEmpty ? 'inconnu' : normalizedKind}',
            style: const TextStyle(color: colorTextSecondary),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: effectiveKind,
            dropdownColor: colorBlockBackground,
            style: const TextStyle(color: colorTextPrimary),
            decoration: InputDecoration(
              labelText: 'Type du groupe',
              labelStyle: const TextStyle(color: colorTextSecondary),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: colorPanelBorder),
              ),
              isDense: true,
            ),
            items: groupKinds
                .map(
                  (kind) =>
                      DropdownMenuItem<String>(value: kind, child: Text(kind)),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              if (isElseBranchSelection) {
                return;
              }
              setState(() {
                _sequenceGroupKind = value;
              });
              widget.onSequenceGroupChanged?.call(
                group,
                value,
                _sequenceGroupLabelController.text,
              );
            },
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey('sequence-group-label-${group.selectionKey}'),
            controller: _sequenceGroupLabelController,
            style: const TextStyle(color: colorTextPrimary),
            decoration: InputDecoration(
              labelText: isElseBranchSelection
                  ? 'Label de la branche else'
                  : 'Label du groupe',
              labelStyle: const TextStyle(color: colorTextSecondary),
              hintText: 'ex: success / retry',
              hintStyle: const TextStyle(color: colorTextSecondary),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: colorPanelBorder),
              ),
              isDense: true,
            ),
            onChanged: (value) {
              widget.onSequenceGroupChanged?.call(
                group,
                isElseBranchSelection ? 'alt' : effectiveKind,
                value,
              );
            },
          ),
          if (isElseBranchSelection) ...[
            const SizedBox(height: 6),
            Text(
              'Label actuel else: ${selectedElseLabel.isEmpty ? '(vide)' : selectedElseLabel}',
              style: const TextStyle(color: colorTextSecondary),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Branches else: ${group.branchCount}',
            style: const TextStyle(color: colorTextSecondary),
          ),
          if (effectiveKind == 'alt') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => widget.onAddElseToSequenceGroup?.call(group),
                icon: const Icon(Icons.call_split),
                label: const Text('Ajouter une branche else'),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Y debut: ${group.startYCanvas.toStringAsFixed(1)}',
            style: const TextStyle(color: colorTextSecondary),
          ),
          Text(
            'Y fin: ${group.endYCanvas.toStringAsFixed(1)}',
            style: const TextStyle(color: colorTextSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'Hauteur visuelle: ${height.toStringAsFixed(1)}',
            style: const TextStyle(color: colorTextSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => widget.onDeleteSequenceGroup?.call(group),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Supprimer le groupe'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockProperties(Block block) {
    if (block.isZone) {
      return _buildZoneBlockProperties(block);
    }

    final nodeShapes = <BlockNodeShape>[
      BlockNodeShape.rectangle,
      BlockNodeShape.roundedRectangle,
      BlockNodeShape.stadium,
      BlockNodeShape.subroutine,
      BlockNodeShape.circle,
      BlockNodeShape.doubleCircle,
      BlockNodeShape.database,
      BlockNodeShape.horizontalTube,
      BlockNodeShape.hexagon,
      BlockNodeShape.parallelogram,
      BlockNodeShape.parallelogramInverted,
      BlockNodeShape.trapezoid,
      BlockNodeShape.trapezoidInverted,
    ];

    String nodeShapeLabel(BlockNodeShape shape) {
      switch (shape) {
        case BlockNodeShape.rectangle:
          return 'Rectangle';
        case BlockNodeShape.roundedRectangle:
          return 'Rectangle arrondi';
        case BlockNodeShape.stadium:
          return 'Stadium';
        case BlockNodeShape.subroutine:
          return 'Subroutine';
        case BlockNodeShape.circle:
          return 'Cercle';
        case BlockNodeShape.doubleCircle:
          return 'Double cercle';
        case BlockNodeShape.database:
          return 'Base de donnees';
        case BlockNodeShape.horizontalTube:
          return 'Tube horizontal (Topic)';
        case BlockNodeShape.hexagon:
          return 'Hexagone';
        case BlockNodeShape.parallelogram:
          return 'Parallelogramme';
        case BlockNodeShape.parallelogramInverted:
          return 'Parallelogramme inverse';
        case BlockNodeShape.trapezoid:
          return 'Trapeze';
        case BlockNodeShape.trapezoidInverted:
          return 'Trapeze inverse';
      }
    }

    return _buildPanelContainer(
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
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () async {
                await onTapProposalApp();

                // _blockTitleController.text = value;
                // widget.onBlockTitleChanged?.call(block.id, value);
              },
              icon: const Icon(Icons.tips_and_updates_outlined, size: 16),
              label: const Text('proposal app'),
            ),
          ),
          if (widget.currentSubgraphTitle != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.canToggleCurrentSubgraphMembership
                    ? widget.onToggleCurrentSubgraphMembership
                    : null,
                icon: Icon(
                  widget.selectedBlockInCurrentSubgraph
                      ? Icons.exit_to_app
                      : Icons.login,
                ),
                label: Text(
                  widget.selectedBlockInCurrentSubgraph
                      ? 'Sortir du subgraph courant'
                      : 'Entrer dans le subgraph courant',
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cible: ${widget.currentSubgraphTitle}',
              style: const TextStyle(color: colorTextSecondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: block.colorKey,
            dropdownColor: colorBlockBackground,
            style: const TextStyle(color: colorTextPrimary),
            decoration: InputDecoration(
              labelText: 'Couleur du bloc',
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
                  'Par défaut',
                  style: TextStyle(color: colorTextPrimary),
                ),
              ),
              ...kBlockColorMap.entries.map((entry) {
                final label = kBlockColorLabelMap[entry.key] ?? entry.key;
                return DropdownMenuItem<String?>(
                  value: entry.key,
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: entry.value,
                          shape: BoxShape.circle,
                        ),
                      ),
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
              widget.onBlockColorChanged?.call(block, value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<BlockNodeShape>(
            initialValue: block.nodeShape,
            dropdownColor: colorBlockBackground,
            style: const TextStyle(color: colorTextPrimary),
            decoration: InputDecoration(
              labelText: 'Forme du noeud',
              labelStyle: const TextStyle(color: colorTextSecondary),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: colorPanelBorder),
              ),
              isDense: true,
            ),
            items: nodeShapes
                .map(
                  (shape) => DropdownMenuItem<BlockNodeShape>(
                    value: shape,
                    child: Text(nodeShapeLabel(shape)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              widget.onBlockNodeShapeChanged?.call(block, value);
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Tags colorés',
            style: TextStyle(
              color: colorTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kBlockTagColorMap.entries.map((entry) {
              final key = entry.key;
              final color = entry.value;
              final label = kBlockTagColorLabelMap[key] ?? key;
              final isSelected = block.tagColorKeys.contains(key);

              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  final updated = List<String>.from(block.tagColorKeys);
                  if (isSelected) {
                    updated.remove(key);
                  } else {
                    updated.add(key);
                  }
                  widget.onBlockTagsChanged?.call(block, updated);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.28)
                        : colorBlockBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? color : colorPanelBorder,
                      width: isSelected ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: const TextStyle(
                          color: colorTextPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'Tags sélectionnés: ${block.tagColorKeys.length}',
            style: const TextStyle(color: colorTextSecondary),
          ),
          const SizedBox(height: 12),
          ImageUrlToBase64Widget(
            initialBase64: _resolvedBlockIconBase64(block),
            showBase64Text: false,
            onBase64Changed: (value) {
              if (value.trim().isEmpty) {
                _removeBlockIcon(block);
                return;
              }
              widget.onBlockIconBase64Changed?.call(block, value);
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _blockJsonController,
            minLines: 4,
            maxLines: 10,
            style: const TextStyle(color: colorTextPrimary),
            decoration: InputDecoration(
              labelText: 'JSON propriétés bloc',
              alignLabelWithHint: true,
              hintText:
                  '{"title":"Service API","colorKey":"blue","tagColorKeys":["green"],"size":{"width":240,"height":180}}',
              hintStyle: const TextStyle(color: colorTextSecondary),
              labelStyle: const TextStyle(color: colorTextSecondary),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: colorPanelBorder),
              ),
            ),
            onChanged: (_) {
              if (_blockJsonError != null) {
                setState(() {
                  _blockJsonError = null;
                });
              }
            },
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: const [
              Text(
                'Clés supportées: title, colorKey, tagColorKeys, iconBase64, size',
                style: TextStyle(color: colorTextSecondary, fontSize: 12),
              ),
            ],
          ),
          if (_blockJsonError != null) ...[
            const SizedBox(height: 6),
            Text(
              _blockJsonError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _populateJsonFromBlock(block),
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Depuis bloc'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _applyBlockPropertiesJson(block),
                  icon: const Icon(Icons.data_object),
                  label: const Text('Appliquer JSON'),
                ),
              ),
            ],
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

  Future<List<ProposalInfo>> searchProposalApp(String query) async {
    List? resultsbdd = await bddStorage.supabase.rpc(
      'search_apm',
      params: {
        'q': query,
        'lang': 'english',
        'company_id': currentCompany.companyId,
      },
    );

    List<ProposalInfo> existingProposals = [];
    if (resultsbdd != null) {
      for (var element in resultsbdd) {
        Map<String, dynamic> hasProp = {...element['prop'] ?? {}};

        // String attrId = element['attr_id'];
        // String schemaId = element['schema_id'];
        String namespace = element['namespace'];
        // String companyId = element['company_id'];

        // var listModel = await bddStorage.supabase
        //     .from('attributs')
        //     .select('*')
        //     .eq('schema_id', schemaId)
        //     .eq('category', 'apm')
        //     .eq('attr_id', attrId)
        //     .eq('namespace', namespace)
        //     .eq('company_id', companyId);

        // if (listModel.isEmpty) continue;
        //get Namespace name
        var aDomain =
            currentCompany.listDomain
                ?.getNodeByMasterIdPath(namespace)
                ?.info
                .name ??
            '';
        var modelName = element['path'].split('>').last ?? 'unknown';
        var path = element['path'].replaceAll('>', '.');
        if (path.startsWith('root.')) {
          path = path.substring(5);
        }

        var proposalInfo = ProposalInfo(
          name: path.split('.').last,
          path: path,
          properties: hasProp,
          model: modelName,
          domain: aDomain,
        );
        existingProposals.add(proposalInfo);
      }
    }
    return existingProposals;
  }

  Future<List<ProposalInfo>> searchProposalLink(String query) async {
    List? resultsbdd = await bddStorage.supabase.rpc(
      'search_apm',
      params: {
        'q': query,
        'lang': 'english',
        'company_id': currentCompany.companyId,
      },
    );

    List<ProposalInfo> existingProposals = [];
    if (resultsbdd != null) {
      for (var element in resultsbdd) {
        Map<String, dynamic> hasProp = {...element['prop'] ?? {}};

        // String attrId = element['attr_id'];
        // String schemaId = element['schema_id'];
        String namespace = element['namespace'];
        // String companyId = element['company_id'];

        // var listModel = await bddStorage.supabase
        //     .from('attributs')
        //     .select('*')
        //     .eq('schema_id', schemaId)
        //     .eq('category', 'apm')
        //     .eq('attr_id', attrId)
        //     .eq('namespace', namespace)
        //     .eq('company_id', companyId);

        // if (listModel.isEmpty) continue;
        //get Namespace name
        var aDomain =
            currentCompany.listDomain
                ?.getNodeByMasterIdPath(namespace)
                ?.info
                .name ??
            '';
        var modelName = element['path'].split('>').last ?? 'unknown';
        var path = element['path'].replaceAll('>', '.');
        if (path.startsWith('root.')) {
          path = path.substring(5);
        }

        var proposalInfo = ProposalInfo(
          name: path.split('.').last,
          path: path,
          properties: hasProp,
          model: modelName,
          domain: aDomain,
        );
        existingProposals.add(proposalInfo);
      }
    }
    return existingProposals;
  }

  BuildContext? loadingContext;

  Future<Null> onTapProposalApp() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        loadingContext = dialogContext;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 14),
                const Text('Recherche en cours...'),
              ],
            ),
          ),
        );
      },
    );

    String query = widget.selectedBlock?.title ?? '';

    //pop le dialog de loading
    List<ProposalInfo> result = await searchProposalApp(query);

    // ignore: use_build_context_synchronously
    Navigator.of(loadingContext!).pop();
    if (!context.mounted) return;

    var scoreTxt = '';

    showDialog<void>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Search results for "$query"'),
          content: SizedBox(
            width: 500,
            child: result.isEmpty
                ? Text('No result found for "$query"')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: result.length,
                    itemBuilder: (context, index) {
                      final r = result[index];
                      return AnimatedTooltip(
                        content: Column(
                          //children: getTooltipFromProposal(r.item),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blueGrey.withAlpha(130),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              dense: true,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              onTap: () {
                                applyProposal(widget.selectedBlock!, r);
                                Navigator.of(dialogContext).pop();
                              },
                              //leading: getColorIndicatorFromScore(r.score),
                              title: Text(
                                '${index + 1}.) ${r.name} from ${r.domain}.${r.model} ',
                              ),
                              subtitle: Text('${r.path}  score: $scoreTxt'),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<Null> onTapProposalLink() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        loadingContext = dialogContext;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 14),
                const Text('Recherche en cours...'),
              ],
            ),
          ),
        );
      },
    );

    String query = widget.selectedLink?.name ?? '';

    //pop le dialog de loading
    List<ProposalInfo> result = await searchProposalApp(query);

    // ignore: use_build_context_synchronously
    Navigator.of(loadingContext!).pop();
    if (!context.mounted) return;

    var scoreTxt = '';

    showDialog<void>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Search results for "$query"'),
          content: SizedBox(
            width: 500,
            child: result.isEmpty
                ? Text('No result found for "$query"')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: result.length,
                    itemBuilder: (context, index) {
                      final r = result[index];
                      return AnimatedTooltip(
                        content: Column(
                          //children: getTooltipFromProposal(r.item),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blueGrey.withAlpha(130),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              dense: true,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              onTap: () {
                                applyProposal(widget.selectedBlock!, r);
                                Navigator.of(dialogContext).pop();
                              },
                              //leading: getColorIndicatorFromScore(r.score),
                              title: Text(
                                '${index + 1}.) ${r.name} from ${r.domain}.${r.model} ',
                              ),
                              subtitle: Text('${r.path}  score: $scoreTxt'),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildZoneBlockProperties(Block block) {
    final zoneBorderStyles = <ZoneBorderStyle>[
      ZoneBorderStyle.plain,
      ZoneBorderStyle.dashed1_2,
      ZoneBorderStyle.dashed2_2,
      ZoneBorderStyle.dashed2_1,
    ];

    String zoneBorderLabel(ZoneBorderStyle style) {
      switch (style) {
        case ZoneBorderStyle.plain:
          return 'Plain';
        case ZoneBorderStyle.dashed1_2:
          return 'Pointille 1-2';
        case ZoneBorderStyle.dashed2_2:
          return 'Pointille 2-2';
        case ZoneBorderStyle.dashed2_1:
          return 'Pointille 2-1';
      }
    }

    String zoneTypeLabel(BlockZoneType zoneType) {
      switch (zoneType) {
        case BlockZoneType.frame:
          return 'Cadre';
        case BlockZoneType.subgraph:
          return 'Subgraph';
      }
    }

    return _buildPanelContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Proprietes de la zone',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('zone-title-${block.id}'),
            controller: _blockTitleController,
            style: const TextStyle(color: colorTextPrimary),
            decoration: InputDecoration(
              labelText: 'Nom',
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
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                // const value = 'proposal';
                // _blockTitleController.text = value;
                // widget.onBlockTitleChanged?.call(block.id, value);
              },
              icon: const Icon(Icons.tips_and_updates_outlined, size: 16),
              label: const Text('proposal ?'),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<BlockZoneType>(
            initialValue: block.zoneType,
            dropdownColor: colorBlockBackground,
            style: const TextStyle(color: colorTextPrimary),
            decoration: InputDecoration(
              labelText: 'Type de zone',
              labelStyle: const TextStyle(color: colorTextSecondary),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: colorPanelBorder),
              ),
              isDense: true,
            ),
            items: BlockZoneType.values
                .map(
                  (type) => DropdownMenuItem<BlockZoneType>(
                    value: type,
                    child: Text(zoneTypeLabel(type)),
                  ),
                )
                .toList(growable: false),
            onChanged: null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: block.colorKey,
            dropdownColor: colorBlockBackground,
            style: const TextStyle(color: colorTextPrimary),
            decoration: InputDecoration(
              labelText: 'Couleur',
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
                  'Par défaut',
                  style: TextStyle(color: colorTextPrimary),
                ),
              ),
              ...kBlockColorMap.entries.map((entry) {
                final label = kBlockColorLabelMap[entry.key] ?? entry.key;
                return DropdownMenuItem<String?>(
                  value: entry.key,
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: entry.value,
                          shape: BoxShape.circle,
                        ),
                      ),
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
              widget.onBlockColorChanged?.call(block, value);
            },
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: SwitchListTile.adaptive(
              value: block.zoneTransparent,
              onChanged: (value) {
                widget.onZoneTransparencyChanged?.call(block, value);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Couleur transparente',
                style: TextStyle(color: colorTextPrimary, fontSize: 13),
              ),
              subtitle: const Text(
                'Conserve uniquement la bordure',
                style: TextStyle(color: colorTextSecondary, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<ZoneBorderStyle>(
            initialValue: block.zoneBorderStyle,
            dropdownColor: colorBlockBackground,
            style: const TextStyle(color: colorTextPrimary),
            decoration: InputDecoration(
              labelText: 'Style de bordure',
              labelStyle: const TextStyle(color: colorTextSecondary),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: colorPanelBorder),
              ),
              isDense: true,
            ),
            items: zoneBorderStyles
                .map(
                  (style) => DropdownMenuItem<ZoneBorderStyle>(
                    value: style,
                    child: Text(zoneBorderLabel(style)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              widget.onZoneBorderStyleChanged?.call(block, value);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    widget.onZoneBringToFront?.call(block);
                  },
                  icon: const Icon(Icons.flip_to_front),
                  label: const Text('Mettre au premier plan'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    widget.onZoneSendToBack?.call(block);
                  },
                  icon: const Icon(Icons.flip_to_back),
                  label: const Text('Mettre au dernier plan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _describeMermaidArrowType(String arrowType) {
    switch (arrowType) {
      case '->>':
        return 'Sync flow (request)';
      case '-->>':
        return 'Async flow (event)';
      case '->':
        return 'One-way flow';
      case '-->':
        return 'One-way Async (dashed)';
      case '->x':
        return 'Termination ';
      case '--x':
        return 'Termination event';
      case '-)':
        return 'Async signal';
      case '--)':
        return 'Async signal (dashed)';
      default:
        return 'Custom flow type';
    }
  }

  String _mermaidArrowTypeLabel(String arrowType) {
    return '$arrowType ${_describeMermaidArrowType(arrowType)}';
  }

  String _describeFlowArrowType(String arrowType) {
    switch (arrowType) {
      case '-->':
        return 'flux normal';
      case '==>':
        return 'flux critique';
      case '=>':
        return 'flux important';
      case '-.->':
        return 'dependance faible';
      case '.->':
        return 'evenement';
      case '==.=>':
        return 'event fort';
      case '=.=>':
        return 'event fort';
      case '---':
        return 'relation neutre';
      case '-.-':
        return 'relation faible';
      case '<-->':
        return 'sync bidirectionnelle';
      case '<.->':
        return 'sync faible bidirectionnelle';
      default:
        return 'Type flow personnalise';
    }
  }

  String _flowArrowTypeLabel(String arrowType) {
    return '$arrowType ${_describeFlowArrowType(arrowType)}';
  }

  bool _isDashedArrowType(String arrowType) {
    return arrowType.contains('.') || arrowType.startsWith('--');
  }

  bool _isFlowDashedArrowType(String arrowType) {
    return arrowType.contains('.');
  }

  bool _isThickFlowArrowType(String arrowType) {
    return arrowType.contains('==') || arrowType.startsWith('=>');
  }

  bool _isBidirectionalFlowArrowType(String arrowType) {
    return arrowType.contains('<');
  }

  bool _isHeadlessFlowArrowType(String arrowType) {
    return arrowType == '---' || arrowType == '-.-';
  }

  Widget _buildFlowLegendChip(String type, {required bool isSelected}) {
    final border = isSelected
        ? const Color(0xFF64C8FF)
        : colorPanelBorder.withValues(alpha: 0.90);
    final bg = isSelected
        ? const Color(0xFF64C8FF).withValues(alpha: 0.14)
        : colorBlockBackground.withValues(alpha: 0.55);

    return Container(
      width: 174,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            height: 14,
            child: CustomPaint(
              painter: _FlowArrowLegendPainter(
                color: const Color(0xFF64C8FF),
                dashed: _isFlowDashedArrowType(type),
                thick: _isThickFlowArrowType(type),
                bidirectional: _isBidirectionalFlowArrowType(type),
                headless: _isHeadlessFlowArrowType(type),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected
                        ? colorTextPrimary
                        : colorTextSecondary.withValues(alpha: 0.95),
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _describeFlowArrowType(type),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: colorTextSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowArrowLegend(String selectedType) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorBlockBackground.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorPanelBorder.withValues(alpha: 0.9)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _flowArrowTypeOptions
            .map(
              (type) =>
                  _buildFlowLegendChip(type, isSelected: selectedType == type),
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> _showFlowArrowLegendDialog(String selectedType) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colorPropertiesPanelBg,
          title: const Text(
            'Codification Flow',
            style: TextStyle(color: colorTextPrimary),
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: _buildFlowArrowLegend(selectedType),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Color _mermaidArrowAccentColor(String arrowType) {
    if (arrowType.endsWith('x') || arrowType.endsWith('X')) {
      return const Color(0xFFE57373);
    }
    if (arrowType.endsWith(')')) {
      return const Color(0xFFFFC107);
    }
    return const Color(0xFF64C8FF);
  }

  // IconData _mermaidArrowIcon(String arrowType) {
  //   if (arrowType.endsWith('x') || arrowType.endsWith('X')) {
  //     return Icons.close_rounded;
  //   }
  //   if (arrowType.endsWith(')')) {
  //     return Icons.arrow_outward_rounded;
  //   }
  //   return Icons.arrow_forward_rounded;
  // }

  Widget _buildLinkProperties(BlockLink link) {
    final arrowType = (link.sequenceArrowType ?? '').trim();
    final allowSequenceElementTypeChoice = widget.isSequenceDiagramMode;
    final isNoteOver = MermaidSequenceCodec.isNoteOverType(arrowType);
    final isNoteFlow = MermaidSequenceCodec.isNoteFlowType(arrowType);
    final isNoteLike =
        allowSequenceElementTypeChoice &&
        MermaidSequenceCodec.isNoteType(arrowType);
    final sequenceMessageKind = isNoteFlow
        ? _sequenceMessageKindNoteFlow
        : (isNoteOver
              ? _sequenceMessageKindNoteOver
              : _sequenceMessageKindMessage);
    final selectableArrowTypes = allowSequenceElementTypeChoice
        ? _mermaidArrowTypeOptions
        : _flowArrowTypeOptions;
    final defaultArrowType = allowSequenceElementTypeChoice ? '-->' : '-->';
    final effectiveArrowType =
        selectableArrowTypes.contains(arrowType) && arrowType.isNotEmpty
        ? arrowType
        : defaultArrowType;
    final isDashedArrow = _isDashedArrowType(effectiveArrowType);
    final arrowAccent = _mermaidArrowAccentColor(effectiveArrowType);
    final webLinks = _webLinksFromLink(link);

    return _buildPanelContainer(
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
          if (allowSequenceElementTypeChoice) ...[
            const Text(
              'Type element sequence',
              style: TextStyle(color: colorTextSecondary),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: _sequenceMessageKindMessage,
                    label: Text('Message'),
                  ),
                  ButtonSegment<String>(
                    value: _sequenceMessageKindNoteOver,
                    label: Text('Note over'),
                  ),
                  ButtonSegment<String>(
                    value: _sequenceMessageKindNoteFlow,
                    label: Text('flow'),
                  ),
                ],
                selected: <String>{sequenceMessageKind},
                showSelectedIcon: false,
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all(colorTextPrimary),
                  side: WidgetStateProperty.all(
                    const BorderSide(color: colorPanelBorder),
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return colorBlockBackground;
                    }
                    return Colors.transparent;
                  }),
                ),
                onSelectionChanged: (selection) {
                  if (selection.isEmpty) {
                    return;
                  }
                  final value = selection.first;

                  if (value == _sequenceMessageKindNoteOver) {
                    widget.onLinkSequenceArrowTypeChanged?.call(
                      link,
                      MermaidSequenceCodec.noteOverType,
                    );
                    return;
                  }

                  if (value == _sequenceMessageKindNoteFlow) {
                    widget.onLinkSequenceArrowTypeChanged?.call(
                      link,
                      MermaidSequenceCodec.noteFlowType,
                    );
                    return;
                  }

                  final nextArrowType =
                      _mermaidArrowTypeOptions.contains(arrowType)
                      ? arrowType
                      : '-->';
                  widget.onLinkSequenceArrowTypeChanged?.call(
                    link,
                    nextArrowType,
                  );
                },
              ),
            ),
          ],
          // if (hasSequenceArrowType) ...[
          //   const SizedBox(height: 12),
          //   Container(
          //     width: double.infinity,
          //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          //     decoration: BoxDecoration(
          //       color: arrowAccent.withValues(alpha: 0.12),
          //       borderRadius: BorderRadius.circular(10),
          //       border: Border.all(color: arrowAccent.withValues(alpha: 0.55)),
          //     ),
          //     child: Row(
          //       crossAxisAlignment: CrossAxisAlignment.start,
          //       children: [
          //         Icon(
          //           _mermaidArrowIcon(arrowType),
          //           size: 16,
          //           color: arrowAccent,
          //         ),
          //         const SizedBox(width: 8),
          //         Expanded(
          //           child: Column(
          //             crossAxisAlignment: CrossAxisAlignment.start,
          //             children: [
          //               Text(
          //                 'Type Mermaid: $arrowType',
          //                 style: const TextStyle(
          //                   color: colorTextPrimary,
          //                   fontWeight: FontWeight.w600,
          //                 ),
          //               ),
          //               const SizedBox(height: 2),
          //               Text(
          //                 _describeMermaidArrowType(arrowType),
          //                 style: const TextStyle(
          //                   color: colorTextSecondary,
          //                   fontSize: 12,
          //                 ),
          //               ),
          //               if (isDashedArrow)
          //                 const Text(
          //                   'Style de trait: pointille',
          //                   style: TextStyle(
          //                     color: colorTextSecondary,
          //                     fontSize: 12,
          //                   ),
          //                 ),
          //             ],
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
          // ],
          if (!isNoteLike) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        selectableArrowTypes.contains(effectiveArrowType)
                        ? effectiveArrowType
                        : defaultArrowType,
                    dropdownColor: colorBlockBackground,
                    iconEnabledColor: arrowAccent,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      labelText: allowSequenceElementTypeChoice
                          ? 'Type message'
                          : 'Type flux (flowchart)',
                      labelStyle: TextStyle(color: arrowAccent),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: arrowAccent.withValues(alpha: 0.65),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: arrowAccent, width: 1.5),
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: arrowAccent),
                      ),
                      isDense: true,
                      helperText: allowSequenceElementTypeChoice
                          ? (isDashedArrow ? 'Dashed flow style' : null)
                          : 'Codification Mermaid flow',
                      helperStyle: const TextStyle(
                        fontSize: 12,
                        color: colorTextSecondary,
                      ),
                    ),
                    items: selectableArrowTypes
                        .map(
                          (type) => DropdownMenuItem<String>(
                            value: type,
                            child: Text(
                              allowSequenceElementTypeChoice
                                  ? _mermaidArrowTypeLabel(type)
                                  : _flowArrowTypeLabel(type),
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      widget.onLinkSequenceArrowTypeChanged?.call(link, value);
                    },
                  ),
                ),
                if (!allowSequenceElementTypeChoice) ...[
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: IconButton(
                      tooltip: 'Voir la codification flow',
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      color: colorTextSecondary.withValues(alpha: 0.92),
                      onPressed: () {
                        _showFlowArrowLegendDialog(effectiveArrowType);
                      },
                      icon: const Icon(Icons.info_outline),
                    ),
                  ),
                ],
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              isNoteFlow
                  ? 'Note flow: rendu fleche epaisse, export Mermaid en note over.'
                  : 'Note over: rendu bloc rectangulaire, export Mermaid: note over A,B: texte',
              style: const TextStyle(color: colorTextSecondary, fontSize: 12),
            ),
          ],
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
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () async {
                await onTapProposalLink();
                // const value = 'proposal';
                // _linkNameController.text = value;
                // widget.onLinkNameChanged?.call(link, value);
              },
              icon: const Icon(Icons.tips_and_updates_outlined, size: 16),
              label: const Text('proposal link'),
            ),
          ),
          const SizedBox(height: 12),
          WebLinkManager(
            links: webLinks,
            onLinksChanged: (links) {
              widget.onLinkWebLinksJsonChanged?.call(
                link,
                _webLinksToJson(links),
              );
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: link.colorKey,
            dropdownColor: colorBlockBackground,
            style: const TextStyle(color: colorTextPrimary),
            decoration: InputDecoration(
              labelText: 'Couleur du lien',
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
                  'Par défaut',
                  style: TextStyle(color: colorTextPrimary),
                ),
              ),
              ...kLinkColorMap.entries.map((entry) {
                final label = kLinkColorLabelMap[entry.key] ?? entry.key;
                return DropdownMenuItem<String?>(
                  value: entry.key,
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: entry.value,
                          shape: BoxShape.circle,
                        ),
                      ),
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
              widget.onLinkColorChanged?.call(link, value);
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
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              value: link.autoLayoutLock,
              onChanged: (value) {
                widget.onLinkAutoLayoutLockChanged?.call(link, value);
              },
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Lock auto-layout (Conserver)',
                style: TextStyle(color: colorTextPrimary),
              ),
              subtitle: const Text(
                'Force le mode Conserver sur ce lien même si le mode global est Auto.',
                style: TextStyle(color: colorTextSecondary, fontSize: 12),
              ),
              activeThumbColor: Colors.orange,
            ),
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
    return _buildPanelContainer(
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
            'Selectionnez un bloc, un lien ou un groupe sequence.',
            style: TextStyle(color: colorTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelContainer({required Widget child}) {
    return Container(
      width: 320,
      height: double.infinity,
      alignment: Alignment.topLeft,
      decoration: BoxDecoration(
        color: colorPropertiesPanelBg,
        border: Border(left: BorderSide(color: colorPanelBorder)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  void applyProposal(Block block, ProposalInfo r) {
    // _blockTitleController.text = r.properties?['title'] ?? r.name;
    // widget.onBlockTitleChanged?.call(block.id, _blockTitleController.text);

    final payload = <String, dynamic>{
      'title': r.properties?['title'] ?? r.name,
      // 'colorKey': block.colorKey,
      // 'tagColorKeys': List<String>.from(block.tagColorKeys),
      'iconBase64': ?r.properties?['identity.logo'],
      //'size': {'width': block.size.width, 'height': block.size.height},
    };

    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    setState(() {
      _blockJsonController.text = encoded;
      _blockJsonError = null;
    });
    widget.onBlockPropertiesJsonChanged?.call(block, encoded);
  }
}
