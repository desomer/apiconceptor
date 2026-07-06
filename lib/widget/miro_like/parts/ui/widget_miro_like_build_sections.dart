// ignore_for_file: invalid_use_of_protected_member

part of '../../widget_miro_like.dart';

extension _MiroLikeWidgetStateBuildSectionsMethods on _MiroLikeWidgetState {
  Widget _buildCanvasWorkspace() {
    return MiroCanvasWorkspace(
      canvasKey: _canvasKey,
      canvasBackgroundColor: colorCanvasBackground,
      blocks: blocks,
      canvasOffset: canvasOffset,
      zoomLevel: zoomLevel,
      selectedBlock: selectedBlock,
      linkSourceBlock: linkSourceBlock,
      foregroundPainter: MiroCanvasPainter(
        blocks: blocks,
        links: links,
        canvasOffset: canvasOffset,
        zoomLevel: zoomLevel,
        showSequenceParticipantLifelines: _isSequenceDiagramView,
        highlightedSequenceParticipantId: linkSourceBlock == null
            ? null
            : _sequenceLinkTargetHoverBlockId,
        selectedBlock: selectedBlock,
        selectedLink: selectedLink,
        linkingFromPoint: linkingFromPoint,
        currentMousePosition: currentMousePosition,
        linkSourceBlock: linkSourceBlock,
        flowAnimation: _flowController,
        pendingInflectionPoints: pendingInflectionPoints,
      ),
      overlayWidgets: [
        ..._buildSelectionOverlay(),
        ..._buildAlignmentSnapGuides(),
        ..._buildZoneResizeHandles(),
        if (_isSequenceDiagramView)
          SequenceMessageLayer(
            entries: _buildSequenceMessageEntries(),
            frameEntries: _frozenSequenceFrameEntriesDuringDrag,
            groupSpan: _buildSequenceGroupSpan(),
            zoomLevel: zoomLevel,
            selectedGroup: _selectedSequenceGroup,
            previewGroup: _dragPreviewSequenceGroup,
            selectedLinks: _selectedSequenceLinks,
            onSelectGroup: (group) {
              setState(() {
                _selectedSequenceGroup = group;
                selectedBlock = null;
                selectedLink = null;
                _selectedBlockIds.clear();
                _selectedSequenceLinks.clear();
              });
            },
            onSelect: (link, additive) {
              setState(() {
                if (additive && _isSequenceDiagramView) {
                  if (_selectedSequenceLinks.contains(link)) {
                    _selectedSequenceLinks.remove(link);
                  } else {
                    _selectedSequenceLinks.add(link);
                  }
                  selectedLink = _selectedSequenceLinks.length == 1
                      ? _selectedSequenceLinks.first
                      : null;
                } else {
                  selectedLink = link;
                  _selectedSequenceLinks
                    ..clear()
                    ..add(link);
                }
                _selectedSequenceGroup = null;
                selectedBlock = null;
                _selectedBlockIds.clear();
              });
            },
            onDragStart: (_) {
              _pushUndoSnapshot();
              _captureSequenceControlSnapshotsForDrag();
              _frozenSequenceFrameEntriesDuringDrag =
                  _buildSequenceMessageEntries();
              _dragPreviewSequenceGroup = null;
            },
            onDragUpdate: (link, globalPosition) {
              setState(() {
                selectedLink = link;
                selectedBlock = null;
                _dragSequenceMessageToGlobalPosition(link, globalPosition);
                final canvasPosition = _toCanvasLocal(globalPosition);
                final candidateGroup =
                    _findSequenceControlGroupAtCanvasPosition(
                      canvasPosition,
                      rawEntriesOverride: _frozenSequenceFrameEntriesDuringDrag,
                    );
                final previousGroup = _dragPreviewSequenceGroup;
                SequenceControlGroupInfo? resolvedGroup = candidateGroup;

                if (previousGroup != null) {
                  final insidePrevious =
                      canvasPosition.dy >= previousGroup.startYCanvas &&
                      canvasPosition.dy <= previousGroup.endYCanvas;

                  if (insidePrevious) {
                    if (candidateGroup == null) {
                      resolvedGroup = previousGroup;
                    } else {
                      final sameControlGroup =
                          identical(
                            candidateGroup.sourceLink,
                            previousGroup.sourceLink,
                          ) &&
                          candidateGroup.sourceOpenLineIndex ==
                              previousGroup.sourceOpenLineIndex;
                      final branchChanged =
                          sameControlGroup &&
                          candidateGroup.targetBranchIndex !=
                              previousGroup.targetBranchIndex;
                      final candidateContainsPrevious =
                          candidateGroup.startYCanvas <=
                              previousGroup.startYCanvas &&
                          candidateGroup.endYCanvas >= previousGroup.endYCanvas;
                      if (candidateContainsPrevious && !branchChanged) {
                        resolvedGroup = previousGroup;
                      }
                    }
                  }
                }

                _dragPreviewSequenceGroup = resolvedGroup;
                _markBoardChanged();
              });
            },
            onDragEnd: (link, globalPosition) {
              setState(() {
                final finalGroup = _dragPreviewSequenceGroup;
                _reorderSequenceMessagesByLane(
                  controlSnapshots: _sequenceDragControlSnapshots,
                  draggedLink: link,
                  dropTargetGroup: finalGroup,
                );
                _sequenceDragControlSnapshots = null;
                _frozenSequenceFrameEntriesDuringDrag = null;
                _dragPreviewSequenceGroup = null;
                _markBoardChanged();
              });
            },
          )
        else
          ..._buildAnchorHandles(),
        if (!_isSequenceDiagramView) ..._buildInflectionHandles(),
        ..._buildLinkLabelHandles(),
        ..._buildLinkWebLinkBadges(),
      ],
      onCanvasPrimaryDragStart: (details) {
        setState(() {
          if (linkSourceBlock != null) {
            return;
          }
          if (!_isSequenceDiagramView) {
            final modelPosition = Offset(
              (details.localPosition.dx - canvasOffset.dx) / zoomLevel,
              (details.localPosition.dy - canvasOffset.dy) / zoomLevel,
            );
            if (_isInsideStandardBlockAtModelPosition(modelPosition)) {
              return;
            }
          }
          _isSequenceMessageBoxSelecting = _isSequenceDiagramView;
          _pendingBoxSelectionStartCanvas = details.localPosition;
        });
      },
      onCanvasPrimaryDragUpdate: (details) {
        setState(() {
          if (linkSourceBlock != null) {
            return;
          }
          final pendingStart = _pendingBoxSelectionStartCanvas;
          if (!_isBoxSelecting && pendingStart != null) {
            final dragDistance =
                (details.localPosition - pendingStart).distance;
            if (dragDistance >=
                _MiroLikeWidgetState._boxSelectionStartThreshold) {
              _startBoxSelection(pendingStart);
            }
          }
          _updateBoxSelection(details.localPosition);
        });
      },
      onCanvasPrimaryDragEnd: (_) {
        setState(() {
          final pendingTapCanvas = _pendingBoxSelectionStartCanvas;
          _pendingBoxSelectionStartCanvas = null;
          if (!_isBoxSelecting) {
            _isSequenceMessageBoxSelecting = false;
            if (pendingTapCanvas != null) {
              _handleCanvasTapAtCanvasPosition(pendingTapCanvas);
            }
            return;
          }
          if (_isSequenceMessageBoxSelecting) {
            _finishSequenceMessageBoxSelection();
          } else {
            _finishBoxSelection();
          }
        });
      },
      onHover: (event) {
        setState(() {
          currentMousePosition = event.localPosition;
        });
      },
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          setState(() {
            final mouseCanvasPos = event.localPosition;
            final modelPointBeforeZoom =
                (mouseCanvasPos - canvasOffset) / zoomLevel;
            final zoomFactor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
            zoomLevel = (zoomLevel * zoomFactor).clamp(0.2, 4.0);
            canvasOffset = mouseCanvasPos - modelPointBeforeZoom * zoomLevel;
          });
        }
      },
      onCanvasSecondaryDragStart: (event) {
        setState(() {
          final canvasPosition = _toCanvasLocal(event.position);
          if (_startSequenceLinkingFromCanvas(canvasPosition)) {
            _isSequenceMessageBoxSelecting = false;
            _draggedZoneId = null;
            isPanning = false;
            return;
          }

          if (!_isSequenceDiagramView) {
            final hitLink = _findLinkAtCanvasPosition(canvasPosition);
            if (hitLink != null) {
              // Keep link interactions priority over zones on right click.
              _draggedZoneId = null;
              isPanning = false;
              return;
            }
          }

          final modelPosition = _toModelPosition(event.position);
          if (_isInsideStandardBlockAtModelPosition(modelPosition)) {
            _draggedZoneId = null;
            isPanning = false;
            return;
          }

          final hitBlock = _findTopBlockAtModelPosition(modelPosition);
          if (hitBlock != null && hitBlock.isZone) {
            selectedBlock = hitBlock;
            _selectedBlockIds
              ..clear()
              ..add(hitBlock.id);
            selectedLink = null;
            if (hitBlock.zoneType == BlockZoneType.frame) {
              _pushUndoSnapshot();
              _draggedZoneId = hitBlock.id;
              isPanning = false;
            } else {
              _draggedZoneId = null;
              // Allow right-drag to pan even when starting on subgraph zones.
              isPanning = true;
            }
            return;
          }
          _draggedZoneId = null;
          isPanning = hitBlock == null;
        });
      },
      onCanvasSecondaryDragUpdate: (event) {
        if (linkSourceBlock != null) {
          _updateLinkPreviewFromGlobal(event.position);
          return;
        }

        if (_draggedZoneId != null) {
          setState(() {
            final zoneIndex = blocks.indexWhere((b) => b.id == _draggedZoneId);
            if (zoneIndex == -1) {
              return;
            }
            final zone = blocks[zoneIndex];
            zone.position += Offset(
              event.delta.dx / zoomLevel,
              event.delta.dy / zoomLevel,
            );
            _markBoardChanged();
          });
          return;
        }
        if (isPanning) {
          setState(() {
            canvasOffset += event.delta;
          });
        }
      },
      onCanvasSecondaryDragEnd: (event) {
        if (linkSourceBlock != null) {
          _finishLinkingAtGlobal(event.position);
        }

        setState(() {
          if (_isSequenceDiagramView) {
            // Defensive cleanup: ensure sequence creation preview is never left active.
            linkSourceBlock = null;
            linkingFromPoint = null;
            currentMousePosition = null;
            _sequenceLinkTargetHoverBlockId = null;
            _sequenceCreationStartCanvasY = null;
            pendingInflectionPoints.clear();
          }
          _draggedZoneId = null;
          isPanning = false;
        });
      },
      onCanvasTapDown: (details) {
        setState(() {
          if (_consumeNextCanvasTap) {
            final now = DateTime.now();
            final consumeAgeOk =
                _consumeNextCanvasTapAt != null &&
                now.difference(_consumeNextCanvasTapAt!) <=
                    const Duration(milliseconds: 350);
            final consumeDistanceOk =
                _consumeNextCanvasTapGlobalPosition != null &&
                (details.globalPosition - _consumeNextCanvasTapGlobalPosition!)
                        .distance <=
                    20.0;
            _consumeNextCanvasTap = false;
            _consumeNextCanvasTapGlobalPosition = null;
            _consumeNextCanvasTapAt = null;
            if (consumeAgeOk && consumeDistanceOk) {
              return;
            }
          }

          final canvasPosition = _toCanvasLocal(details.globalPosition);
          _handleCanvasTapAtCanvasPosition(canvasPosition);
        });
      },
      onCanvasSecondaryTapDown: (details) {
        final canvasPosition = _toCanvasLocal(details.globalPosition);
        final modelPosition = _toModelPosition(details.globalPosition);

        if (linkSourceBlock != null) {
          return;
        }

        final hitLink = _findLinkAtCanvasPosition(canvasPosition);
        if (hitLink != null) {
          setState(() {
            if (_isSequenceDiagramView) {
              selectedBlock = null;
              _selectedBlockIds.clear();
              _selectedSequenceGroup = null;
              selectedLink = hitLink;
              _selectedSequenceLinks
                ..clear()
                ..add(hitLink);
              return;
            }

            selectedBlock = null;
            _selectedBlockIds.clear();
            if (selectedLink != hitLink) {
              selectedLink = hitLink;
              return;
            }

            final pointAdded = _insertInflectionPointOnLink(canvasPosition);
            if (!pointAdded) {
              selectedLink = hitLink;
            }
          });
          _lastSecondaryTapTime = null;
          _lastSecondaryTapCanvasPosition = null;
          return;
        }

        final nearBlock = _findBlockNearModelPosition(modelPosition);
        if (nearBlock != null) {
          _lastSecondaryTapTime = null;
          _lastSecondaryTapCanvasPosition = null;
          return;
        }

        final now = DateTime.now();
        final isDoubleSecondaryTap =
            _lastSecondaryTapTime != null &&
            now.difference(_lastSecondaryTapTime!) <=
                const Duration(milliseconds: 350) &&
            _lastSecondaryTapCanvasPosition != null &&
            (canvasPosition - _lastSecondaryTapCanvasPosition!).distance <=
                18.0;

        _lastSecondaryTapTime = now;
        _lastSecondaryTapCanvasPosition = canvasPosition;

        if (!isDoubleSecondaryTap) {
          return;
        }

        _lastSecondaryTapTime = null;
        _lastSecondaryTapCanvasPosition = null;

        _showCanvasCreationMenu(details.globalPosition);
      },
      isSecondaryButtonPressed: _isSecondaryButtonPressed,
      onStartLinkingForBlock: (block) {
        if (_isSequenceDiagramView) {
          return;
        }
        _startLinking(block);
      },
      onUpdateLinkPreviewFromGlobal: _updateLinkPreviewFromGlobal,
      onFinishLinkingAtGlobal: _finishLinkingAtGlobal,
      onBlockPanDown: (block, details) {
        setState(() {
          _pushUndoSnapshot();
          if (!_isCtrlPressed()) {
            if (!(_selectedBlockIds.length > 1 &&
                _selectedBlockIds.contains(block.id))) {
              _selectedBlockIds
                ..clear()
                ..add(block.id);
              selectedBlock = block;
            }
          }
          selectedLink = null;
          _selectedSequenceGroup = null;
          _resetBlockDragSnap();
          _dragFreePositionModel = _selectedBlockIds.length == 1
              ? block.position
              : null;
        });
      },
      onBlockPanUpdate: (block, details) {
        if (_selectedBlockIds.contains(block.id)) {
          if (block.isZone && _isAutoSubgraphZone(block)) {
            return;
          }
          setState(() {
            final deltaModel = Offset(
              details.delta.dx / zoomLevel,
              details.delta.dy / zoomLevel,
            );
            if (_selectedBlockIds.length > 1) {
              final linksToMove = _linksFullyInsideSelection(_selectedBlockIds);
              for (final selectedId in _selectedBlockIds) {
                final idx = blocks.indexWhere((b) => b.id == selectedId);
                if (idx == -1) {
                  continue;
                }
                if (blocks[idx].isZone && _isAutoSubgraphZone(blocks[idx])) {
                  continue;
                }
                blocks[idx].position += deltaModel;
                if (!blocks[idx].isZone) {
                  if (_isSequenceDiagramView) {
                    _syncSequenceMessagesForParticipant(blocks[idx].id);
                  } else {
                    _updateLinksAnchorsForBlock(blocks[idx]);
                  }
                }
              }

              // Keep manual bends stable while dragging a selected group.
              if (!_isSequenceDiagramView) {
                for (final link in linksToMove) {
                  for (int i = 0; i < link.inflectionPoints.length; i++) {
                    link.inflectionPoints[i] += deltaModel;
                  }
                }
              }
            } else {
              final proposedPosition =
                  (_dragFreePositionModel ?? block.position) + deltaModel;
              _dragFreePositionModel = proposedPosition;
              block.position = _applyBlockAlignmentSnap(
                block,
                proposedPosition,
              );
              if (!block.isZone) {
                if (_isSequenceDiagramView) {
                  _syncSequenceMessagesForParticipant(block.id);
                } else {
                  _updateLinksAnchorsForBlock(block);
                }
              }
            }
            _syncAutoSubgraphZones();
            _markBoardChanged();
          });
        }
      },
      onBlockPanEnd: (_) {
        _resetBlockDragSnap();
      },
      onBlockTapDown: (block, details) {
        setState(() {
          _consumeNextCanvasTap = true;
          _consumeNextCanvasTapGlobalPosition = details.globalPosition;
          _consumeNextCanvasTapAt = DateTime.now();
          _lastSecondaryTapTime = null;
          _lastSecondaryTapCanvasPosition = null;
          if (_isCtrlPressed()) {
            if (_selectedBlockIds.contains(block.id)) {
              _selectedBlockIds.remove(block.id);
            } else {
              _selectedBlockIds.add(block.id);
            }
            selectedBlock = _selectedBlockIds.length == 1
                ? blocks.firstWhere((b) => b.id == _selectedBlockIds.first)
                : null;
          } else {
            final keepMultiSelection =
                _selectedBlockIds.length > 1 &&
                _selectedBlockIds.contains(block.id);
            if (!keepMultiSelection) {
              _selectedBlockIds
                ..clear()
                ..add(block.id);
            }
            selectedBlock = _selectedBlockIds.length == 1
                ? blocks.firstWhere((b) => b.id == _selectedBlockIds.first)
                : null;
          }
          selectedLink = null;
          _selectedSequenceGroup = null;
          _resetBlockDragSnap();
        });
      },
      onBlockInfoTap: (block) {
        _showBlockInfoDialog(block);
      },
      selectedBlockIds: _selectedBlockIds,
    );
  }

  Widget _buildSidePanel() {
    final selectedNormalBlock = selectedBlock != null && selectedBlock!.isZone
        ? null
        : selectedBlock;
    final currentSubgraphTitle = selectedNormalBlock == null
        ? null
        : _currentAutoSubgraphTitleForSelectedBlock();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: [
        SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: getAction(),
          ),
        ),
        Expanded(
          child: PropertiesPanel(
            selectedBlock: selectedBlock,
            selectedLink: selectedLink,
            selectedSequenceGroup: _selectedSequenceGroup,
            selectedBlockCount: _selectedBlockIds.length,
            selectedMessageCount: _selectedSequenceLinks.length,
            canCreateSequenceGroupFromSelection:
                _isSequenceDiagramView &&
                _selectedSequenceLinks.isNotEmpty &&
                _isSelectedSequenceMessageRangeContiguous(),
            createSequenceGroupValidationMessage:
                _sequenceGroupCreationValidationMessage(),
            onCreateSequenceGroupFromSelection:
                _createSequenceGroupFromSelection,
            canCreateSubgraphFromSelection:
                !_isSequenceDiagramView && _selectedBlockIds.length > 1,
            onCreateSubgraphFromSelection: _createSubgraphFromSelection,
            onSequenceGroupChanged: _handleSequenceGroupChanged,
            onDeleteSequenceGroup: _deleteSequenceGroup,
            onAddElseToSequenceGroup: _addElseToSequenceGroup,
            onBlockTitleChanged: _handleBlockTitleChanged,
            onBlockColorChanged: _handleBlockColorChanged,
            onBlockNodeShapeChanged: _handleBlockNodeShapeChanged,
            onBlockTagsChanged: _handleBlockTagsChanged,
            onBlockIconBase64Changed: _handleBlockIconBase64Changed,
            onBlockPropertiesJsonChanged: _handleBlockPropertiesJsonChanged,
            canToggleCurrentSubgraphMembership:
                selectedNormalBlock != null &&
                _canToggleSelectedBlockCurrentAutoSubgraphMembership(),
            selectedBlockInCurrentSubgraph:
                selectedNormalBlock != null &&
                _selectedBlockIsInCurrentAutoSubgraph(),
            currentSubgraphTitle: currentSubgraphTitle,
            onToggleCurrentSubgraphMembership:
                _toggleSelectedBlockCurrentAutoSubgraphMembership,
            onZoneBringToFront: _handleZoneBringToFront,
            onZoneSendToBack: _handleZoneSendToBack,
            onZoneTransparencyChanged: _handleZoneTransparencyChanged,
            onZoneBorderStyleChanged: _handleZoneBorderStyleChanged,
            onLinkNameChanged: _handleLinkNameChanged,
            onLinkColorChanged: _handleLinkColorChanged,
            onLinkLabelIconChanged: _handleLinkLabelIconChanged,
            onLinkTagsChanged: _handleLinkTagsChanged,
            onLinkParticleDensityChanged: _handleLinkParticleDensityChanged,
            onLinkParticleSpeedChanged: _handleLinkParticleSpeedChanged,
            onLinkLabelPositionChanged: _handleLinkLabelPositionChanged,
            onLinkLabelOffsetChanged: _handleLinkLabelOffsetChanged,
            onReverseLink: _reverseLink,
            onDeleteLink: _deleteLink,
            onConnectorTypeChanged: _handleConnectorTypeChanged,
            onLinkAutoLayoutLockChanged: _handleLinkAutoLayoutLockChanged,
            onLinkWebLinksJsonChanged: _handleLinkWebLinksJsonChanged,
            onLinkSequenceArrowTypeChanged: _handleLinkSequenceArrowTypeChanged,
            isSequenceDiagramMode: _isSequenceDiagramView,
          ),
        ),
      ],
    );
  }
}
