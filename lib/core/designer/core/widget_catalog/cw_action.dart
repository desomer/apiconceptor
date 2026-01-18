import 'package:flutter/material.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';
import 'package:jsonschema/core/api/sessionStorage.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_repository.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_selectable.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/start_core.dart';

const cwOnPressed = 'onPressed';

class CwAction extends CwWidget {
  const CwAction({super.key, required super.ctx});

  @override
  State<CwAction> createState() => _CwInputState();

  static void initFactory(WidgetFactory factory) {
    final List listButtonType = [
      {'icon': Icons.smart_button, 'value': 'elevated'},
      {'icon': Icons.text_fields, 'value': 'text'}, // elevated button
      {'icon': Icons.crop_square, 'value': 'outlined'}, // outlined button
      {'icon': Icons.touch_app, 'value': 'icon'},
      {'icon': Icons.list, 'value': 'listTile'},
    ];

    factory.register(
      id: 'action',
      build: (ctx) => CwAction(key: ctx.getKey(), ctx: ctx),
      config: (ctx) {
        return CwWidgetConfig()
            .addProp(
              CwWidgetProperties(id: 'type', name: 'view type')
                ..isToogle(ctx, listButtonType, defaultValue: 'elevated'),
            )
            .addProp(
              CwWidgetProperties(id: 'label', name: 'label')..isText(ctx),
            )
            .addProp(CwWidgetProperties(id: 'url', name: 'url')..isText(ctx))
            .addProp(CwWidgetProperties(id: 'icon', name: 'icon')..isIcon(ctx));
      },
      populateOnDrag: (ctx, drag) {
        drag.childData![cwProps]['label'] ??= 'New Action';
      },
    );
  }
}

class _CwInputState extends CwWidgetStateBindJson<CwAction> with HelperEditor {
  @override
  void initState() {
    initBind();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return buildWidget(false, ModeBuilderWidget.noConstraint, (
      ctx,
      constraints,
    ) {
      Widget button;
      String? style = getStringProp(widget.ctx, 'type');
      String? label = getStringProp(widget.ctx, 'label') ?? '';
      Map<String, dynamic>? iconProp = getObjProp(widget.ctx, 'icon');
      Icon? icon;
      if (iconProp != null) {
        var iconDes = deserializeIcon(iconProp);
        if (iconDes != null) {
          icon = Icon(iconDes.data);
        }
      }

      void onPressed() async {
        var v = widget.ctx.dataWidget![cwProps][cwOnPressed];

        setSelectedRow(context);

        if (v != null &&
            v[cwType] == 'repository' &&
            ctx.aFactory.isModeViewer()) {
          CwRepository? repo =
              widget.ctx.aFactory.mapRepositories[v['repository']];
          if (repo != null) {
            if (v['operation'] == 'load') {
              loadRepository(repo, context);
            } else if (v['operation'] == 'link2Datasrc') {
              var paramSessionId = await getLinkDataInSession(v['link'], repo);
              CwRepository? repoLink =
                  widget.ctx.aFactory.mapRepositories[v['link']['repository']];
              if (repoLink != null) {
                // ignore: use_build_context_synchronously
                loadRepository(
                  repoLink,
                  context,
                  paramSessionId: paramSessionId,
                );
              }
            }
          }
        }

        String? url = getStringProp(widget.ctx, 'url');
        if (url != null && url.isNotEmpty) {
          if (ctx.aFactory.isModeDesigner()) {
            int t = DateTime.now().millisecondsSinceEpoch;
            var isPressBeforeSelected =
                !ctx.isDesignSelected() ||
                t - currentSelectorManager.lastSelectedTime < 500;
            //ctx.aFactory.rootCtx?.selectOnDesigner();
            if (isPressBeforeSelected) {
              // in designer mode, do not navigate sur la selection
              return;
            }
          }
          url = ctx.aFactory.mapPath2PathSlot[url] ?? url;
          ctx.aFactory.router!.push(url);
        }
      }

      switch (style) {
        case 'outlined':
          if (icon != null) {
            button = OutlinedButton.icon(
              onPressed: onPressed,
              icon: icon,
              label: Text(label),
            );
          } else {
            button = OutlinedButton(onPressed: onPressed, child: Text(label));
          }
          break;
        case 'icon':
          button = IconButton(
            onPressed: onPressed,
            icon: icon ?? const Icon(Icons.help),
            tooltip: label,
          );
          break;
        case 'listTile':
          button = ListTile(
            leading: icon,
            dense: true,
            title: Text(label),
            onTap: onPressed,
          );
          break;
        case 'text':
          if (icon != null) {
            button = TextButton.icon(
              onPressed: onPressed,
              icon: icon,
              label: Text(label),
            );
          } else {
            button = TextButton(onPressed: onPressed, child: Text(label));
          }

        case 'elevated':
        default:
          if (icon != null) {
            button = ElevatedButton.icon(
              onPressed: onPressed,
              icon: icon,
              label: Text(label),
            );
          } else {
            button = ElevatedButton(onPressed: onPressed, child: Text(label));
          }
          break;
      }

      return button;
    });
  }

  void loadRepository(
    CwRepository repo,
    BuildContext context, {
    String? paramSessionId,
  }) {
    var h = repo.ds.helper!;
    repo.dataState.clearDisplayedData();

    if (paramSessionId != null) {
      // affecte la session du parent
      h.apiCallInfo.parentData = sessionStorage.get(paramSessionId);
    }

    // ignore: use_build_context_synchronously
    h.startCancellableSearch(context, repo.criteriaState.data, () {
      var data = h.apiCallInfo.aResponse?.reponse?.data;
      repo.dataState.data = data;
      repo.dataState.loadDataInContainer(data);
    });
  }

  void setSelectedRow(BuildContext context) {
    if (stateRepository != null) {
      //String? oldPathData = pathData;
      pathData = stateRepository!.getDataPath(
        // ignore: use_build_context_synchronously
        context,
        attribut!.info,
        typeListContainer: false,
        state: this,
      );
      doChangeRow();
    }
  }

  Future<String?> getLinkDataInSession(
    Map<String, dynamic> link,
    CwRepository repos,
  ) async {
    var pages = await loadDataSource("all", false);
    BrowseSingle().browse(pages, false);
    String toDatasrc = link['linkTo'];
    String pathValue = link['onPath'];
    var attr = pages.mapInfoByName[toDatasrc];
    if (attr?.isNotEmpty ?? false) {
      var pth = pathValue.replaceAll("[*]", "[]");

      String pathSelected;
      (_, pathSelected) = repos.dataState.getStateContainer(pth);

      PageData pageData = PageData(
        data: repos.dataState.data,
        path: pathSelected,
      );

      print(
        'assign link data to session ${pageData.hashCode}, path=$pathSelected',
      );
      var key = '${pageData.hashCode}';
      sessionStorage.put(key, pageData);
      return key;
    }
    return null;
  }
}
