part of '../../widget_miro_like.dart';

extension _MiroLikeWidgetStateActionsMethods on _MiroLikeWidgetState {
  List<Widget> getAction() {
    final canDeleteCurrentSelection =
        selectedBlock != null ||
        selectedLink != null ||
        _selectedSequenceLinks.isNotEmpty ||
        _selectedSequenceGroup != null;
    final canDeleteAll = blocks.isNotEmpty || links.isNotEmpty;

    return [
      Row(
        children: [
          Expanded(
            child: SegmentedButton<_DiagramLayoutMode>(
              segments: const [
                ButtonSegment<_DiagramLayoutMode>(
                  value: _DiagramLayoutMode.flowchart,
                  icon: Icon(Icons.account_tree_outlined),
                  label: Text('Flowchart'),
                ),
                ButtonSegment<_DiagramLayoutMode>(
                  value: _DiagramLayoutMode.sequence,
                  icon: Icon(Icons.table_rows_outlined),
                  label: Text('Sequence'),
                ),
              ],
              selected: {
                _isSequenceDiagramView
                    ? _DiagramLayoutMode.sequence
                    : _DiagramLayoutMode.flowchart,
              },
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                if (selection.isEmpty) {
                  return;
                }
                _setDiagramLayoutMode(selection.first);
              },
            ),
          ),
        ],
      ),
      Row(
        children: [
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: 'Voir tous les blocs',
            onPressed: _fitToView,
          ),
          Spacer(),
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo (Ctrl+Z)',
            onPressed: _undoStack.isEmpty ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            tooltip: 'Redo (Ctrl+Y)',
            onPressed: _redoStack.isEmpty ? null : _redo,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addBlock(Offset(200, 200)),
            tooltip: 'Ajouter un bloc',
          ),
          IconButton(
            icon: const Icon(Icons.crop_square),
            onPressed: () => _addFrameBlock(Offset(140, 140)),
            tooltip: 'Ajouter une frame',
          ),
          IconButton(
            icon: Icon(
              Icons.delete,
              color: canDeleteCurrentSelection ? Colors.redAccent : null,
            ),
            onPressed: canDeleteCurrentSelection
                ? _deleteCurrentSelection
                : null,
            tooltip: 'Supprimer la sélection',
          ),
          IconButton(
            icon: Icon(
              Icons.delete_forever,
              color: canDeleteAll ? Colors.redAccent : null,
            ),
            onPressed: canDeleteAll ? _confirmDeleteAll : null,
            tooltip: 'Supprimer tout',
          ),
        ],
      ),
      Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.save_outlined,
              color: _hasUnsavedChanges ? Colors.blue : null,
            ),
            tooltip: 'Save',
            onPressed: () {
              // save miro canvas state to local storage or backend
              debugPrint('save flow app ${widget.query}');

              var payload = {
                'company_id': currentCompany.companyId,
                'namespace': currentCompany.currentFlow!.namespace,
                'category': 'appflow',
                'schema_id': '${currentCompany.currentFlow!.id}/data',
                'version': '1',
                'attr_id': widget.query!,
                'path': '-',
                'prop': _boardToJson(),
                'state': 'R',
                'update_at': DateTime.now().toIso8601String(),
              };

              var save = SaveEvent(
                model: currentCompany.currentFlow!,
                version: null,
                idIdempotence: widget.query!,
                table: 'attributs',
                data: payload,
              );

              bddStorage.storeManager.add(save);
              // ignore: invalid_use_of_protected_member
              setState(() {
                _markBoardSaved();
              });
            },
          ),
          Spacer(),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Export JSON',
            onPressed: () => importExportManager.showExportDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.image_outlined),
            tooltip: 'Export PNG',
            onPressed: _exportGraphAsPng,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Import JSON',
            onPressed: () => importExportManager.showImportDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: 'Export Mermaid',
            onPressed: () => importExportManager.showExportMermaidDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.schema_outlined),
            tooltip: 'Import Mermaid',
            onPressed: () => importExportManager.showImportMermaidDialog(),
          ),
        ],
      ),
      Row(
        children: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: _isSequenceDiagramView
                ? 'Reorganiser en sequence diagram'
                : 'Reorganiser en flowchart',
            onPressed: _reorganizeCurrentLayout,
          ),
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Logger positions',
            onPressed: _isSequenceDiagramView
                ? null
                : _logNodePositionsForAutoLayoutDebug,
          ),
          Spacer(),
          PopupMenuButton<String>(
            tooltip: _isSequenceDiagramView
                ? 'Direction Mermaid indisponible en mode Sequence'
                : 'Direction Mermaid ($_mermaidLayoutDirection)',
            enabled: !_isSequenceDiagramView,
            onSelected: _isSequenceDiagramView
                ? null
                : (value) {
                    // ignore: invalid_use_of_protected_member
                    setState(() {
                      _mermaidLayoutDirection = value;
                    });
                  },
            itemBuilder: (context) {
              return _MiroLikeWidgetState._mermaidDirections
                  .map(
                    (direction) => CheckedPopupMenuItem<String>(
                      value: direction,
                      checked: _mermaidLayoutDirection == direction,
                      child: Text('Direction $direction'),
                    ),
                  )
                  .toList();
            },
            icon: Icon(
              Icons.swap_horiz,
              color: _isSequenceDiagramView ? Colors.white38 : null,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Qualite placement ($_placementQuality)',
            onSelected: (value) {
              // ignore: invalid_use_of_protected_member
              setState(() {
                _placementQuality = value;
              });
            },
            itemBuilder: (context) {
              return _MiroLikeWidgetState._placementQualities
                  .map(
                    (quality) => CheckedPopupMenuItem<String>(
                      value: quality,
                      checked: _placementQuality == quality,
                      child: Text(quality),
                    ),
                  )
                  .toList();
            },
            icon: const Icon(Icons.tune),
          ),
          PopupMenuButton<String>(
            tooltip: 'Ecart blocs ($_blockSpacingMode)',
            onSelected: (value) {
              // ignore: invalid_use_of_protected_member
              setState(() {
                _blockSpacingMode = value;
              });
            },
            itemBuilder: (context) {
              return _MiroLikeWidgetState._blockSpacingModes
                  .map(
                    (spacing) => CheckedPopupMenuItem<String>(
                      value: spacing,
                      checked: _blockSpacingMode == spacing,
                      child: Text(spacing),
                    ),
                  )
                  .toList();
            },
            icon: const Icon(Icons.space_bar),
          ),
          PopupMenuButton<String>(
            tooltip: 'Priorite alignement ($_alignmentPriorityMode)',
            onSelected: (value) {
              // ignore: invalid_use_of_protected_member
              setState(() {
                _alignmentPriorityMode = value;
              });
            },
            itemBuilder: (context) {
              return _MiroLikeWidgetState._alignmentPriorityModes
                  .map(
                    (mode) => CheckedPopupMenuItem<String>(
                      value: mode,
                      checked: _alignmentPriorityMode == mode,
                      child: Text(mode),
                    ),
                  )
                  .toList();
            },
            icon: const Icon(Icons.align_horizontal_left),
          ),
          PopupMenuButton<String>(
            tooltip: 'Cote ancres auto-layout ($_autoLayoutAnchorSideMode)',
            onSelected: (value) {
              // ignore: invalid_use_of_protected_member
              setState(() {
                _autoLayoutAnchorSideMode = value;
              });
            },
            itemBuilder: (context) {
              return _MiroLikeWidgetState._autoLayoutAnchorSideModes
                  .map(
                    (mode) => CheckedPopupMenuItem<String>(
                      value: mode,
                      checked: _autoLayoutAnchorSideMode == mode,
                      child: Text(mode),
                    ),
                  )
                  .toList();
            },
            icon: const Icon(Icons.settings_input_component),
          ),
        ],
      ),
    ];
  }
}
