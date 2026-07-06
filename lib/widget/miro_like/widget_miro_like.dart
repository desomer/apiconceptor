import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/bdd/data_event.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/miro_like/layers/miro_canvas_painter.dart';
import 'package:jsonschema/widget/miro_like/layers/connector_path_utils.dart';
import 'package:jsonschema/widget/miro_like/widgets/actions/properties_panel.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'models/link_manager.dart';
import 'models/link_model.dart';
import 'models/block_model.dart';
import 'auto_layout_engine.dart';
import 'widgets/actions/import_export_manager.dart';
import 'widgets/link_manager.dart';
import 'mermaid_flowchart_codec.dart';
import 'mermaid_sequence_codec.dart';
import 'widgets/anchor_handle_widget.dart';
import 'widgets/inflection_handle_widget.dart';
import 'widgets/link_label_handle_widget.dart';
import 'widgets/miro_canvas_workspace.dart';

// Data import/export and serialization.
part 'parts/data/widget_miro_like_imports.dart';
part 'parts/data/widget_miro_like_json.dart';

// Sequence diagram layer and rendering.
part 'layers/sequence_message_layer.dart';

// User interaction and editing handlers.
part 'parts/interaction/widget_miro_like_sequence.dart';
part 'parts/interaction/widget_miro_like_canvas_selection.dart';
part 'parts/interaction/widget_miro_like_linking.dart';
part 'parts/interaction/widget_miro_like_handlers.dart';
part 'parts/interaction/widget_miro_like_zones.dart';

// Canvas geometry and handles.
part 'parts/canvas/widget_miro_like_canvas_core.dart';
part 'parts/canvas/widget_miro_like_anchors.dart';
part 'parts/canvas/widget_miro_like_link_handles.dart';

// Layout orchestration.
part 'parts/layout/widget_miro_like_autolayout.dart';

// UI composition and actions.
part 'parts/ui/widget_miro_like_actions.dart';
part 'parts/ui/widget_miro_like_build_sections.dart';

// ============================================================================
// THEME COLORS - Centralized color definitions for the entire application
// ============================================================================

// Canvas and Background Colors
const Color colorCanvasBackground = Color.fromARGB(255, 48, 48, 51);
const Color colorPropertiesPanelBg = Color.fromARGB(255, 24, 24, 27);
const Color colorPanelBorder = Color.fromARGB(255, 71, 71, 74);

// Block Colors
const Color colorBlockBackground = Color.fromARGB(255, 33, 33, 36);
const Color colorBlockBackgroundSelected = Color.fromARGB(61, 255, 193, 7);
const Color colorBlockBorder = Color.fromARGB(255, 66, 66, 69);
const Color colorBlockBorderSelected = Color.fromARGB(255, 255, 152, 0);
const Color colorBlockText = Colors.white;
const Color colorBlockTextSelected = Colors.white;

// Link Colors
const Color colorLinkDefault = Color.fromARGB(255, 100, 200, 255);
const Color colorLinkSelected = Color.fromARGB(255, 255, 165, 0);
const Color colorLinkCreation = Color.fromARGB(255, 56, 142, 60);
const Color colorInflectionPoint = Color.fromARGB(255, 255, 152, 0);

// Anchor Handle Colors
const Color colorAnchorSourceHandle = Color.fromARGB(255, 0, 128, 128);
const Color colorAnchorTargetHandle = Color.fromARGB(255, 103, 58, 183);
const Color colorAnchorBorder = Colors.white;

// Text Colors
const Color colorTextPrimary = Colors.white;
const Color colorTextSecondary = Color.fromARGB(179, 255, 255, 255);
const Color colorTextError = Colors.red;

// Shadow and Effects
const Color colorShadow1 = Color.fromARGB(77, 0, 0, 0);
const Color colorShadow2 = Color.fromARGB(64, 0, 0, 0);

class MiroLikeWidget extends StatefulWidget {
  final String? query;
  const MiroLikeWidget({super.key, this.query});

  @override
  State<MiroLikeWidget> createState() => _MiroLikeWidgetState();
}

const double _linkHitTolerance = 24.0;
const double _inflectionHandleRadius = 7.0;
const double _anchorHandleRadius = 6.0;
const double anchorSpacingDistance = 35.0;
const double anchorBorderMarginDistance = 50.0;
const double _minBlockWidth = 200.0;
const double _minBlockHeight = 150.0;
const double _alignmentSnapCaptureDistance = 10.0;
const double _alignmentSnapReleaseDistance = 24.0;
const double _minZoneWidth = 180.0;
const double _minZoneHeight = 120.0;
const double _zoneHandleSize = 14.0;

const double _sequenceParticipantGap = 280.0;
const double _sequenceParticipantTop = 80.0;
const double _sequenceMessageStartY = 300.0;
const double _sequenceMessageStepY = 30.0;
const double _sequenceSelfLoopHorizontalOffset = 80.0;
const double _sequenceSelfLoopVerticalOffset = 50.0;
const double _sequenceFramePadding = 30.0;
const double _sequenceFrameNestGap = 30.0;
const double _sequenceElseGap = 30.0;
const double _sequenceFrameRightGap = 20.0;

enum _ZoneResizeHandle { topLeft, topRight, bottomLeft, bottomRight }

enum _DiagramLayoutMode { flowchart, sequence }

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}

class _MiroLikeWidgetState extends State<MiroLikeWidget>
    with SingleTickerProviderStateMixin {
  static const List<String> _mermaidDirections = ['LR', 'TB', 'RL', 'BT'];
  static const List<String> _placementQualities = [
    'Rapide',
    'Equilibre',
    'Dense',
  ];
  static const List<String> _blockSpacingModes = [
    'Dense',
    'Normal',
    'Plus ecarte',
  ];
  static const List<String> _alignmentPriorityModes = [
    'Aucun',
    'Normal',
    'Fort',
    'Extreme',
  ];
  static const List<String> _autoLayoutAnchorSideModes = ['Auto', 'Conserver'];

  final GlobalKey _canvasKey = GlobalKey();
  final List<Block> blocks = [];
  final List<BlockLink> links = [];
  late final AnimationController _flowController;
  late final LinkManager linkManager;
  late final ImportExportManager importExportManager;
  Block? selectedBlock;
  final Set<String> _selectedBlockIds = <String>{};
  BlockLink? selectedLink;
  final Set<BlockLink> _selectedSequenceLinks = <BlockLink>{};
  SequenceControlGroupInfo? _selectedSequenceGroup;
  Block? linkSourceBlock;
  Offset? linkingFromPoint;
  Offset? currentMousePosition;
  final List<Offset> pendingInflectionPoints = [];
  Offset canvasOffset = Offset.zero;
  double zoomLevel = 1.0;
  bool isPanning = false;
  String _mermaidLayoutDirection = 'LR';
  String _placementQuality = 'Equilibre';
  String _blockSpacingMode = 'Normal';
  String _alignmentPriorityMode = 'Fort';
  String _autoLayoutAnchorSideMode = 'Auto';
  double? _snapLeftModel;
  double? _snapTopModel;
  Offset? _dragFreePositionModel;
  Offset? _selectionStartCanvas;
  Offset? _selectionCurrentCanvas;
  Offset? _pendingBoxSelectionStartCanvas;
  bool _isBoxSelecting = false;
  bool _isSequenceMessageBoxSelecting = false;
  static const double _boxSelectionStartThreshold = 6.0;
  bool _consumeNextCanvasTap = false;
  Offset? _consumeNextCanvasTapGlobalPosition;
  DateTime? _consumeNextCanvasTapAt;
  DateTime? _lastSecondaryTapTime;
  Offset? _lastSecondaryTapCanvasPosition;
  String? _draggedZoneId;
  bool _isSequenceDiagramView = false;
  bool _hasUnsavedChanges = false;
  String? _sequenceLinkTargetHoverBlockId;
  double? _sequenceCreationStartCanvasY;
  List<_SequenceControlSnapshot>? _sequenceDragControlSnapshots;
  List<SequenceMessageEntry>? _frozenSequenceFrameEntriesDuringDrag;
  SequenceControlGroupInfo? _dragPreviewSequenceGroup;

  static const int _historyLimit = 30;

  static const Duration _granularUndoWindow = Duration(milliseconds: 900);
  final List<String> _undoStack = <String>[];
  final List<String> _redoStack = <String>[];
  String? _savedBoardSnapshot;
  String? _lastGranularUndoKey;
  DateTime? _lastGranularUndoAt;

  void _markBoardChanged() {
    _hasUnsavedChanges = true;
  }

  void _markBoardSaved() {
    _hasUnsavedChanges = false;
    _savedBoardSnapshot = _createBoardSnapshot();
  }

  String _createBoardSnapshot() {
    return jsonEncode(_boardToJson());
  }

  void _pushUndoSnapshot() {
    _lastGranularUndoKey = null;
    _lastGranularUndoAt = null;
    final snapshot = _createBoardSnapshot();
    if (_undoStack.isNotEmpty && _undoStack.last == snapshot) {
      return;
    }
    _undoStack.add(snapshot);
    if (_undoStack.length > _historyLimit) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _pushUndoSnapshotForGranularEdit(String key) {
    final now = DateTime.now();
    final lastAt = _lastGranularUndoAt;
    final isSameEditScope = _lastGranularUndoKey == key;
    final isInsideWindow =
        lastAt != null && now.difference(lastAt) <= _granularUndoWindow;

    if (!isSameEditScope || !isInsideWindow) {
      _pushUndoSnapshot();
    }

    _lastGranularUndoKey = key;
    _lastGranularUndoAt = now;
  }

  bool _isTextEditingFocused() {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    return focusedContext?.widget is EditableText;
  }

  void _updateUnsavedStateFromSnapshot() {
    final savedSnapshot = _savedBoardSnapshot;
    if (savedSnapshot == null) {
      _markBoardChanged();
      return;
    }
    _hasUnsavedChanges = _createBoardSnapshot() != savedSnapshot;
  }

  void _restoreBoardFromSnapshot(String snapshot) {
    final decoded = jsonDecode(snapshot);
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final importedBlocks = _blocksFromJson(decoded['blocks']);
    final legacyType = _connectorTypeFromName(decoded['connectorType']);
    final importedLinks = _linksFromJson(
      decoded['links'],
      fallbackType: legacyType,
    );
    final importedIds = importedBlocks.map((b) => b.id).toSet();
    importedLinks.removeWhere(
      (l) =>
          !importedIds.contains(l.fromBlockId) ||
          !importedIds.contains(l.toBlockId),
    );
    final isSequenceDiagramView =
        decoded['diagramMode']?.toString() == 'sequence';

    setState(() {
      blocks
        ..clear()
        ..addAll(importedBlocks);
      links
        ..clear()
        ..addAll(importedLinks);

      final zoom = decoded['zoomLevel'];
      if (zoom is num) {
        zoomLevel = zoom.toDouble().clamp(0.2, 4.0);
      }

      canvasOffset = _offsetFromJson(decoded['canvasOffset']);
      selectedBlock = null;
      _selectedBlockIds.clear();
      selectedLink = null;
      _selectedSequenceLinks.clear();
      _selectedSequenceGroup = null;
      linkSourceBlock = null;
      linkingFromPoint = null;
      currentMousePosition = null;
      pendingInflectionPoints.clear();
      _resetBlockDragSnap();
      _isBoxSelecting = false;
      _selectionStartCanvas = null;
      _selectionCurrentCanvas = null;
      _draggedZoneId = null;
      _isSequenceDiagramView = isSequenceDiagramView;
      if (_isSequenceDiagramView) {
        _normalizeSequenceMessageGeometryAndSpacing();
      }
      _updateUnsavedStateFromSnapshot();
    });
  }

  void _undo() {
    if (_undoStack.isEmpty) {
      return;
    }
    final previousSnapshot = _undoStack.removeLast();
    _redoStack.add(_createBoardSnapshot());
    _restoreBoardFromSnapshot(previousSnapshot);
  }

  void _redo() {
    if (_redoStack.isEmpty) {
      return;
    }
    final nextSnapshot = _redoStack.removeLast();
    _undoStack.add(_createBoardSnapshot());
    _restoreBoardFromSnapshot(nextSnapshot);
  }

  Block? _findTopBlockAtModelPosition(Offset modelPosition) {
    for (final block in blocks.reversed) {
      final blockRect = Rect.fromLTWH(
        block.position.dx,
        block.position.dy,
        block.size.width,
        block.size.height,
      );
      if (blockRect.contains(modelPosition)) {
        return block;
      }
    }
    return null;
  }

  bool _isInsideStandardBlockAtModelPosition(Offset modelPosition) {
    for (final block in blocks.reversed) {
      if (block.isZone) {
        continue;
      }
      final blockRect = Rect.fromLTWH(
        block.position.dx,
        block.position.dy,
        block.size.width,
        block.size.height,
      );
      if (blockRect.contains(modelPosition)) {
        return true;
      }
    }
    return false;
  }

  double _blockSpacingMultiplier() {
    switch (_blockSpacingMode) {
      case 'Dense':
        return 1;
      case 'Plus ecarte':
        return 8;
      case 'Normal':
      default:
        return 3;
    }
  }

  double _alignmentPriorityMultiplier() {
    switch (_alignmentPriorityMode) {
      case 'Aucun':
        // Negative value means "disable alignment constraints" in auto-layout.
        return -1.0;
      case 'Normal':
        return 0;
      case 'Fort':
        return 0.5;
      case 'Extreme':
      default:
        return 2.0;
    }
  }

  ({
    double iterationMul,
    double repulsionMul,
    double springMul,
    double overlapMul,
    double hpwlMul,
    double crossingMul,
    int channelPitch,
    double snapTargetWeight,
  })
  _placementQualityProfile() {
    switch (_placementQuality) {
      case 'Rapide':
        return (
          iterationMul: 0.72,
          repulsionMul: 0.90,
          springMul: 0.92,
          overlapMul: 0.92,
          hpwlMul: 0.75,
          crossingMul: 0.78,
          channelPitch: 1,
          snapTargetWeight: 0.32,
        );
      case 'Dense':
        return (
          iterationMul: 1.38,
          repulsionMul: 1.14,
          springMul: 1.08,
          overlapMul: 1.14,
          hpwlMul: 1.25,
          crossingMul: 1.28,
          channelPitch: 3,
          snapTargetWeight: 0.56,
        );
      case 'Equilibre':
      default:
        return (
          iterationMul: 1.0,
          repulsionMul: 1.0,
          springMul: 1.0,
          overlapMul: 1.0,
          hpwlMul: 1.0,
          crossingMul: 1.0,
          channelPitch: 2,
          snapTargetWeight: 0.45,
        );
    }
  }

  @override
  void initState() {
    super.initState();
    linkManager = LinkManager(
      blocks: blocks,
      onBlockSpaceEnsure: _ensureBlockHasSpaceForAnchors,
    );
    importExportManager = ImportExportManager(
      context: context,
      generateBoardJson: _generateBoardJson,
      importBoard: (decoded) => _importBoard(decoded, recordHistory: true),
      generateMermaid: _generateMermaid,
      importMermaid: _importMermaid,
    );
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _initializeSampleBlocks();
    _markBoardSaved();
  }

  @override
  void dispose() {
    _flowController.dispose();
    super.dispose();
  }

  void _initializeSampleBlocks() {
    // loader from query id
    if (widget.query != null) {
      bddStorage
          .getFlowApp(currentCompany.currentFlow!, widget.query!)
          .then((flowApp) {
            if (flowApp != null) {
              _importBoard(flowApp, recordHistory: false);
              _markBoardSaved();
            }
          })
          .catchError((error) {
            // Handle error if needed
            debugPrint('Error loading flow app: $error');
          });
    }

    // blocks.addAll([
    //   Block(
    //     id: '1',
    //     title: 'Block 1',
    //     position: const Offset(100, 100),
    //     size: const Size(_minBlockWidth, _minBlockHeight),
    //   ),
    //   Block(
    //     id: '2',
    //     title: 'Block 2',
    //     position: const Offset(350, 100),
    //     size: const Size(_minBlockWidth, _minBlockHeight),
    //   ),
    //   Block(
    //     id: '3',
    //     title: 'Block 3',
    //     position: const Offset(225, 300),
    //     size: const Size(_minBlockWidth, _minBlockHeight),
    //   ),
    // ]);
  }

  void _fitToView() {
    if (blocks.isEmpty) {
      return;
    }

    setState(() {
      // Calculer la bounding box de tous les blocs et des geometries de liens/messages.
      double minX = double.infinity;
      double minY = double.infinity;
      double maxX = -double.infinity;
      double maxY = -double.infinity;

      void includePoint(Offset point) {
        minX = math.min(minX, point.dx);
        minY = math.min(minY, point.dy);
        maxX = math.max(maxX, point.dx);
        maxY = math.max(maxY, point.dy);
      }

      void includeRect(Rect rect) {
        minX = math.min(minX, rect.left);
        minY = math.min(minY, rect.top);
        maxX = math.max(maxX, rect.right);
        maxY = math.max(maxY, rect.bottom);
      }

      Offset canvasToModelPoint(Offset canvasPoint) {
        return Offset(
          (canvasPoint.dx - canvasOffset.dx) / zoomLevel,
          (canvasPoint.dy - canvasOffset.dy) / zoomLevel,
        );
      }

      Rect canvasToModelRect(Rect canvasRect) {
        return Rect.fromPoints(
          canvasToModelPoint(canvasRect.topLeft),
          canvasToModelPoint(canvasRect.bottomRight),
        );
      }

      for (final block in blocks) {
        includeRect(
          Rect.fromLTWH(
            block.position.dx,
            block.position.dy,
            block.size.width,
            block.size.height,
          ),
        );
      }

      for (final link in links) {
        for (final point in link.inflectionPoints) {
          includePoint(point);
        }

        final fromBlock = blocks
            .where((b) => b.id == link.fromBlockId)
            .firstOrNull;
        final toBlock = blocks.where((b) => b.id == link.toBlockId).firstOrNull;
        if (fromBlock == null || toBlock == null) {
          continue;
        }

        includePoint(
          Offset(
            fromBlock.position.dx + fromBlock.size.width / 2,
            fromBlock.position.dy + fromBlock.size.height / 2,
          ),
        );
        includePoint(
          Offset(
            toBlock.position.dx + toBlock.size.width / 2,
            toBlock.position.dy + toBlock.size.height / 2,
          ),
        );
      }

      if (_isSequenceDiagramView) {
        final sequenceEntries = _buildSequenceMessageEntries();
        for (final entry in sequenceEntries) {
          includeRect(
            canvasToModelRect(
              Rect.fromLTRB(
                entry.leftXCanvas,
                entry.topYCanvas,
                entry.rightXCanvas,
                entry.bottomYCanvas,
              ),
            ),
          );
        }

        final frameGroups = _buildSequenceControlGroupsForHitTest(
          sequenceEntries,
        );
        final groupSpan = _buildSequenceGroupSpan();
        if (groupSpan != null) {
          for (final group in frameGroups) {
            includeRect(
              canvasToModelRect(
                Rect.fromLTRB(
                  groupSpan.leftCanvas,
                  group.startYCanvas,
                  groupSpan.rightCanvas,
                  group.endYCanvas,
                ),
              ),
            );
          }
        }
      }

      if (!minX.isFinite ||
          !minY.isFinite ||
          !maxX.isFinite ||
          !maxY.isFinite) {
        return;
      }

      final contentWidth = maxX - minX;
      final contentHeight = maxY - minY;
      const padding = 60.0;

      // Calculer le zoom pour que tout rentre dans la vue avec du padding
      final RenderBox? renderBox =
          _canvasKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) {
        return;
      }

      final viewportWidth = renderBox.size.width - (padding * 2);
      final viewportHeight = renderBox.size.height - (padding * 2);

      final zoomX = viewportWidth / contentWidth;
      final zoomY = viewportHeight / contentHeight;
      zoomLevel = math.min(zoomX, zoomY).clamp(0.2, 4.0);

      // Centrer le contenu dans la vue
      final centeredX =
          viewportWidth / 2 - (contentWidth * zoomLevel) / 2 + padding;
      final centeredY =
          viewportHeight / 2 - (contentHeight * zoomLevel) / 2 + padding;

      canvasOffset = Offset(
        centeredX - minX * zoomLevel,
        centeredY - minY * zoomLevel,
      );
    });
  }

  void _fitToViewAfterNextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _fitToView();
    });
  }

  bool _isSecondaryButtonPressed(int buttons) {
    return (buttons & kSecondaryMouseButton) != 0;
  }

  bool _isCtrlPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight);
  }

  String _generateMermaid() {
    if (_isSequenceDiagramView) {
      return MermaidSequenceCodec.generate(blocks: blocks, links: links);
    }

    return MermaidFlowchartCodec.generate(
      blocks: blocks,
      links: links,
      direction: _mermaidLayoutDirection,
    );
  }

  List<BlockLink> _linksFullyInsideSelection(Set<String> selectedIds) {
    if (selectedIds.length < 2) {
      return const <BlockLink>[];
    }
    return links
        .where(
          (link) =>
              selectedIds.contains(link.fromBlockId) &&
              selectedIds.contains(link.toBlockId),
        )
        .toList(growable: false);
  }

  Block? _findBlockNearModelPosition(Offset modelPosition) {
    final modelTolerance = 10.0 / zoomLevel;
    for (final block in blocks.reversed) {
      final blockRect = Rect.fromLTWH(
        block.position.dx,
        block.position.dy,
        block.size.width,
        block.size.height,
      ).inflate(modelTolerance);
      if (blockRect.contains(modelPosition)) {
        return block;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyZ, control: true): _UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyY, control: true): _RedoIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
            _RedoIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _UndoIntent: CallbackAction<_UndoIntent>(
            onInvoke: (_) {
              if (_isTextEditingFocused()) {
                return null;
              }
              _undo();
              return null;
            },
          ),
          _RedoIntent: CallbackAction<_RedoIntent>(
            onInvoke: (_) {
              if (_isTextEditingFocused()) {
                return null;
              }
              _redo();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Row(
            children: [
              Expanded(child: _buildCanvasWorkspace()),
              _buildSidePanel(),
            ],
          ),
        ),
      ),
    );
  }
}
