import 'package:flutter/material.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';
import 'package:jsonschema/core/designer/core/cw_repository_action.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_repository.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_selectable.dart';

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
            .addStyle(
              CwWidgetProperties(id: 'type', name: 'view type')
                ..isToogle(ctx, listButtonType, defaultValue: 'elevated'),
            )
            .addProp(
              CwWidgetProperties(id: 'label', name: 'label')..isText(ctx),
            )
            .addProp(CwWidgetProperties(id: 'url', name: 'url')..isText(ctx))
            .addProp(CwWidgetProperties(id: 'icon', name: 'icon')..isIcon(ctx))
            .addProp(CwWidgetProperties(id: 'size', name: 'size')..isSize(ctx));
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
      String? style = getStringProp(ctx, 'type');
      String? label = getStringProp(ctx, 'label');
      Map<String, dynamic>? iconProp = getObjProp(ctx, 'icon');
      Icon? icon;
      if (iconProp != null) {
        var iconDes = deserializeIcon(iconProp);
        if (iconDes != null) {
          icon = Icon(iconDes.data, color: styleFactory.getColor('fgColor'));
        }
      }

      void onPressed() async {
        Map? infoPress = ctx.dataWidget![cwProps][cwOnPressed];
        _setSelectedRow(context);

        var fact = ctx.aFactory;

        if (infoPress != null &&
            infoPress[cwType] == 'repository' &&
            fact.isModeViewer()) {
          CwRepository? repo = fact.mapRepositories[infoPress['repository']];

          if (repo != null) {
            CwRepositoryAction repoAction = CwRepositoryAction(
              ctx: widget.ctx,
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
                  ctx: widget.ctx,
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

        String? url = getStringProp(widget.ctx, 'url');
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
      }

      var type = ctx.slotProps?.type;
      if (type == 'tab') {
        style = 'inner';
      } else if (type == 'tabslider') {
        style = 'inner';
      } else if (type == 'navigationdestination') {
        style = 'navigationdestination';
      }

      var styleText = styleFactory.getTextStyle(null);

      switch (style) {
        case 'navigationdestination':
          button = NavigationDestination(
            icon:
                icon ??
                Icon(Icons.help, color: styleFactory.getColor('fgColor')),
            label: label ?? '',
          );
          break;

        case 'inner':
          button = Row(
            spacing: 5,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) icon,
              if (label != null) Text(style: styleText, label),
            ],
          );

          break;

        case 'outlined':
          if (icon != null) {
            button = OutlinedButton.icon(
              onPressed: onPressed,
              icon: icon,
              label: Text(style: styleText, label ?? ''),
            );
          } else {
            button = OutlinedButton(
              onPressed: onPressed,
              child: Text(style: styleText, label ?? ''),
            );
          }
          break;
        case 'icon':
          button = IconButton(
            style: styleFactory.getButtonStyle(null, styleText),
            onPressed: onPressed,
            icon: icon ?? const Icon(Icons.help),
            tooltip: label,
          );
          break;
        case 'listTile':
          button = styleFactory.getStyledContainer(
            ListTile(
              leading: icon,
              dense: true,
              title: Text(style: styleText, label ?? ''),
              onTap: onPressed,
            ),
            context,
          );
          break;
        case 'text':
          if (icon != null) {
            button = TextButton.icon(
              style: styleFactory.getButtonStyle(null, styleText),
              onPressed: onPressed,
              icon: icon,
              label: Text(style: styleText, label ?? ''),
            );
          } else {
            button = TextButton(
              style: styleFactory.getButtonStyle(null, styleText),
              onPressed: onPressed,
              child: Text(style: styleText, label ?? ''),
            );
          }

        case 'elevated':
        default:
          if (icon != null) {
            button = ElevatedButton.icon(
              style: styleFactory.getButtonStyle(null, styleText),
              onPressed: onPressed,
              icon: icon,
              label: Text(style: styleText, label ?? ''),
            );
          } else {
            button = ElevatedButton(
              style: styleFactory.getButtonStyle(null, styleText),
              onPressed: onPressed,
              child: Text(style: styleText, label ?? ''),
            );
          }
          break;
      }

      return button;
    });
  }

  void _setSelectedRow(BuildContext context) {
    if (stateRepository != null && attribut != null) {
      //String? oldPathData = pathData;
      bool inArray = widget.ctx.parentCtx?.isType(['list', 'table']) ?? false;
      pathData = stateRepository!.getDataPath(
        // ignore: use_build_context_synchronously
        context,
        widgetPath: widget.ctx.aWidgetPath,
        attribut!.info.path,
        typeListContainer: false,
        inArray: inArray,
        state: this,
      );
    } else {
      var stateArray = widget.ctx.parentCtx?.widgetState;
      if (stateArray is! CwWidgetStateBindJson) return;
      var pathJson =
          'root${stateArray.pathData.replaceAll('/', '>').replaceAll('[*]', '[]')}';
      pathJson = '$pathJson[]>*';

      stateRepository = stateArray.stateRepository;
      pathData = stateRepository!.getDataPath(
        // ignore: use_build_context_synchronously
        context,
        pathJson,
        widgetPath: widget.ctx.aWidgetPath,
        typeListContainer: false,
        inArray: true,
        state: this,
      );
    }
    doChangeRow();
  }
}
