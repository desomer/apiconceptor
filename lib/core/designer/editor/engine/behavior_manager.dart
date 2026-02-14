import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/core/cw_repository.dart';
import 'package:jsonschema/core/designer/core/cw_repository_action.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_selectable.dart';

class BehaviorManager {
  static void addBehavior(
    Map<String, dynamic> dataWidget, {
    required String type,
    required Map<String, dynamic> data,
  }) {
    dataWidget[cwBehaviors] ??= <Map<String, dynamic>>[];
    List<Map<String, dynamic>> behaviors = dataWidget[cwBehaviors];
    behaviors.add({'type': type, 'metadata': data});
  }

  static List<BehaviorDescription> getBehaviors(
    Map<String, dynamic> dataWidget,
  ) {
    List<BehaviorDescription> descriptions = [];
    if (dataWidget[cwBehaviors] != null) {
      List<Map<String, dynamic>> behaviors = List<Map<String, dynamic>>.from(
        dataWidget[cwBehaviors],
      );
      for (var behavior in behaviors) {
        descriptions.add(
          BehaviorDescription(
            type: behavior['type'],
            metadata: Map<String, dynamic>.from(behavior['metadata']),
          ),
        );
      }
    }
    return descriptions;
  }

  static void executeBehaviors(CwWidgetCtx ctx, BuildContext context) async {
    if (ctx.dataWidget == null) return;
    var fact = ctx.aFactory;

    List<BehaviorDescription> behaviors = getBehaviors(ctx.dataWidget!);
    for (var behavior in behaviors) {
      if (behavior.type == 'navigate') {
        String? url = behavior.metadata['routeUrl'];
        if (url != null && url.isNotEmpty) {
          if (fact.isModeDesigner()) {
            int t = DateTime.now().millisecondsSinceEpoch;
            var isPressBeforeSelected =
                !ctx.isDesignSelected() ||
                t - currentSelectorManager.lastSelectedTime < 500;

            if (isPressBeforeSelected) {
              // in designer mode, do not navigate sur la selection
              return;
            }
          }
          url = fact.mapPath2PathSlot[url] ?? url;
          fact.router!.push(url);
        }
      } else if (behavior.type == 'repository') {
        await behavior.doActionOnRepository(ctx, context);
      }
    }
  }
}

class BehaviorDescription {
  final String type;
  final Map<String, dynamic> metadata;

  BehaviorDescription({required this.type, required this.metadata});

  Widget getWidgetDescription(CwWidgetCtx ctx) {
    if (type == 'navigate') {
      return Text('Go to ${metadata['routeUrl']}');
    } else if (type == 'repository') {
      CwRepository? repo = ctx.aFactory.mapRepositories[metadata['repository']];
      if (metadata['operation'] == 'action') {
        return Text('${metadata['idAction']} on ${repo!.ds.dsName}');
      } else if (metadata['operation'] == 'link2Datasrc') {
        CwRepository? repo2 = ctx.aFactory.mapRepositories[metadata['link']['repository']];
        return Text('Link ${repo?.ds.dsName} to ${repo2?.ds.dsName}');
      } else if (metadata['operation'] == 'loadCriteria') {
        return Text('set criteria on ${repo!.ds.dsName}');
      }
      return Text('${metadata['operation']} on ${repo!.ds.dsName}');
    }
    return Text('Behavior: $type, Metadata: $metadata');
  }

  Future<void> doActionOnRepository(
    CwWidgetCtx ctx,
    BuildContext context,
  ) async {
    var fact = ctx.aFactory;
    if (fact.isModeViewer()) {
      var infoPress = metadata;
      CwRepository? repo = fact.mapRepositories[infoPress['repository']];

      if (repo != null) {
        CwRepositoryAction repoAction = CwRepositoryAction(
          ctx: ctx,
          repo: repo,
        );
        if (infoPress['operation'] == 'action') {
          switch (infoPress['idAction']) {
            case 'search':
              repoAction.loadData(context);
              break;
            case 'prevPage':
              repoAction.doPrevPage(infoPress, 0);
              repoAction.loadData(context);
            case 'nextPage':
              repoAction.doNextPage(infoPress, 1000000);
              repoAction.loadData(context);
            default:
              break;
          }
        } else if (infoPress['operation'] == 'link2Datasrc') {
          var paramSessionId = await repoAction.getLinkDataInSession(
            infoPress['link'],
          );
          CwRepository? repoLink =
              fact.mapRepositories[infoPress['link']['repository']];
          if (repoLink != null) {
            CwRepositoryAction repoLinkAction = CwRepositoryAction(
              ctx: ctx,
              repo: repoLink,
            );
            repoLinkAction.loadData(
              // ignore: use_build_context_synchronously
              context,
              paramSessionId: paramSessionId,
            );
          }
        } else if (infoPress['operation'] == 'loadCriteria') {
          repoAction.loadCriteria(infoPress);
          repoAction.loadData(context);
        }
      }
    }
  }
}
