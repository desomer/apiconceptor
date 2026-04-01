import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/feature/design/page_designer.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:jsonschema/widget/widget_glasspan.dart';

// ignore: must_be_immutable
class AppsPageDesigner extends GenericPageStateless with GlassPaneMixin {
  AppsPageDesigner({super.key, required this.mode});
  String query = 'factoryName';
  bool isLoading = false;
  Widget? cache;
  String? url;
  final DesignMode mode;

  @override
  bool isCacheValid(GoRouterState state, String uri, BuildContext context) {
    String keyFactory = query;
    WidgetFactory f = getFactory(keyFactory, context);
    f.cwFactoryProps.listPropsEditor = [];
    f.cwFactoryProps.listStyleEditor = [];
    f.cwFactoryProps.listStyleSelectorEditor = [];
    f.onStarted = (context) {
      f.onStarted = null;
      Future.delayed(Duration(milliseconds: 1000), () {
        // ignore: invalid_use_of_protected_member
        f.pageDesignerKey.currentState?.setState(() {});
        f.rootCtx?.repaint();
        if (f.isModeDesigner()) {
          SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
            f.rootCtx?.selectOnDesigner();
          });
          hideGlassPane();
        }
      });
    };

    return true;
  }

  @override
  Widget build(BuildContext context) {
    String keyFactory = query;
    WidgetFactory f = getFactory(keyFactory, context);
    f.initAllGlobalKeys();
    return PageDesigner(key: f.pageDesignerKey, mode: mode, factory: f);
  }

  WidgetFactory getFactory(String keyFactory, BuildContext context) {
    WidgetFactory? f = cacheLinkPage.get(keyFactory);
    if (f == null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        showGlassPane(context);
      });
      f = WidgetFactory();
      cacheLinkPage.put(keyFactory, f);
    }
    f.id = keyFactory;
    return f;
  }

  @override
  NavigationInfo? initNavigation(
    GoRouterState routerState,
    BuildContext context,
    PageInit? pageInit,
  ) {
    query = routerState.uri.queryParameters['id'] ?? "";
    return NavigationInfo()
      ..navLeft = [
        BreadNode(
          icon: const Icon(Icons.edit),
          settings: const RouteSettings(name: 'Edit Page'),
          type: BreadNodeType.widget,
          path: Pages.pageDesigner.id(query),
        ),
        BreadNode(
          icon: const Icon(Icons.play_arrow_rounded),
          settings: const RouteSettings(name: 'Test Page'),
          type: BreadNodeType.widget,
          path: Pages.pageViewer.id(query),
        ),
        BreadNode(
          icon: const Icon(Icons.bug_report),
          settings: const RouteSettings(name: 'Debug app'),
          type: BreadNodeType.widget,
          path: Pages.pageDebug.id(query),
        ),
      ]
      ..actions = [ZoomDesignerWidget(zoomNotifier: designZoomNotifier)];
  }
}

class ZoomDesignerWidget extends StatefulWidget {
  const ZoomDesignerWidget({super.key, required this.zoomNotifier});

  final ValueNotifier<double> zoomNotifier;

  @override
  State<ZoomDesignerWidget> createState() => _ZoomDesignerWidgetState();
}

class _ZoomDesignerWidgetState extends State<ZoomDesignerWidget> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              widget.zoomNotifier.value = 100;
            });
          },
          icon: Icon(Icons.center_focus_strong_outlined),
        ),
        SizedBox(
          width: 200,
          child: Slider(
            min: 80,
            max: 200,
            divisions: 20,
            value: widget.zoomNotifier.value.toDouble(),
            onChanged: (value) {
              widget.zoomNotifier.value = value;
              setState(() {});
            },
          ),
        ),
      ],
    );
  }
}
