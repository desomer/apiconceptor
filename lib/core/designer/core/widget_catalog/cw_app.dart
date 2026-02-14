import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_theme.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_slot.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';

class CwApp extends CwWidget {
  const CwApp({super.key, required super.ctx, required super.cacheWidget});

  static void initFactory(WidgetFactory factory) {
    factory.register(
      id: 'app',
      build:
          (ctx) =>
              CwApp(key: ctx.getKey(), ctx: ctx, cacheWidget: CachedWidget()),
      config: (ctx) {
        return CwWidgetConfig()
            .addStyle(
              CwWidgetProperties(id: 'color', name: 'seed color')..isColor(ctx),
            )
            .addStyle(
              CwWidgetProperties(id: 'darkMode', name: 'dark mode')
                ..isBool(ctx),
            );
      },
    );
  }

  @override
  State<CwApp> createState() => CwPageState();
}

class CwPageState extends CwWidgetState<CwApp> with HelperEditor {
  final themeController = ThemeController();
  late ValueNotifier<String> routeController;
  final routerBuilderController = ValueNotifier<int>(0);

  @override
  void initState() {
    routeController = ValueNotifier<String>('/');
    if (widget.ctx.aFactory.isModeDesigner()) {
      widget.ctx.aFactory.routeControllerDesigner = routeController;
    } else {
      widget.ctx.aFactory.routeControllerViewer = routeController;
    }
    super.initState();
  }

  @override
  void dispose() {
    widget.ctx.aFactory.routeControllerViewer = null;
    widget.ctx.aFactory.routeControllerDesigner = null;
    themeController.dispose();
    routeController.dispose();
    routerBuilderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildWidget(false, ModeBuilderWidget.noConstraint, (
      ctx,
      constraints,
      _,
    ) {
      var isDark = getBoolProp(widget.ctx, 'darkMode') ?? false;
      ThemeData theme = getTheme(isDark);
      themeController.setDefaultTheme(theme);
      var ret = ValueListenableBuilder<int>(
        valueListenable: routerBuilderController,
        builder: (context, value, child) {
          final GoRouter router = goRouter();
          ctx.aFactory.router = router;
          return MaterialApp.router(
            key: GlobalKey(debugLabel: 'MaterialApp.router - CwPage'),
            debugShowCheckedModeBanner: false,
            routerConfig: router,
            theme: themeController.theme,
          );
        },
      );
      return ret;
    });
  }

  bool isModeDesktop() {
    return true;
  }

  @override
  bool clearWidgetCache({bool clearInnerWidget = false}) {
    //routerBuilderController.value++;
    widget.ctx.aFactory.cachePagesDesign.clear();
    widget.ctx.aFactory.cachePagesViewer.clear();
    return super.clearWidgetCache(clearInnerWidget: clearInnerWidget);
  }

  GoRouter goRouter() {
    var appRoutes = widget.ctx.aFactory.appData[cwApp][cwSlots] as Map;
    List<GoRoute> routes = [];
    if (routes.isEmpty) {
      for (var route in appRoutes.entries) {
        var routeData = route.value;
        routes.add(
          GoRoute(
            path: routeData[cwRoutePath],
            //name: routeData[cwRouteName],
            pageBuilder: (context, state) {
              var cachePages =
                  widget.ctx.aFactory.isModeDesigner()
                      ? widget.ctx.aFactory.cachePagesDesign
                      : widget.ctx.aFactory.cachePagesViewer;

              Widget? page = cachePages[route.value[cwRouteId]];
              if (page == null) {
                page = getPage(context, route.value[cwRouteId]);
                if (withWidgetCache) {
                  cachePages[route.value[cwRouteId]] = page;
                }
              }

              return NoTransitionPage(child: page);
            },
          ),
        );
      }

      for (var i = 0; i < 10; i++) {
        routes.add(
          GoRoute(
            path: '/temp/page_slot_$i',
            //name: routeData[cwRouteName],
            pageBuilder: (context, state) {
              var route = widget.ctx.aFactory.listSlotsPageInRouter[i];

              return NoTransitionPage(
                child: getPage(context, route[cwRouteId]),
              );
            },
          ),
        );
      }
    }

    var myRouteObserver = MyRouteObserver(factory: widget.ctx.aFactory);
    var router = GoRouter(
      observers: [myRouteObserver],
      initialLocation: routeController.value,
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            return child;
          },
          routes: routes,
        ),
      ],
    );
    myRouteObserver.router = router;
    return router;
  }

  Widget getPage(BuildContext context, String routeId) {
    return getSlot(CwSlotProp(id: routeId, name: 'page'));
  }

  ThemeData getTheme(bool isDark) {
    Color mainColor =
        getColorFromHex(widget.ctx, 'color') ??
        (isDark ? Colors.grey.shade900 : Colors.white);

    Color? bgColor = HelperEditor.getColorProp(widget.ctx, 'bgColor', [
      cwStyle,
    ]);

    // Color barForegroundColor =
    //     (mainColor.computeLuminance() > 0.400)
    //         ? lightenOrDarken(true, mainColor, 0.5) // dark
    //         : lightenOrDarken(false, mainColor, 0.5);

    var colorScheme = ColorScheme.fromSeed(
      seedColor: mainColor,
      brightness: isDark ? Brightness.dark : Brightness.light,
    );

    var theme = ThemeData(
      //scaffoldBackgroundColor: mainColor,
      // appBarTheme: AppBarTheme(
      //   foregroundColor: barForegroundColor,
      //   backgroundColor: mainColor,
      // ),
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgColor,
    );
    return theme;
  }

  Color lightenOrDarken(bool dark, Color color, [double amount = .1]) {
    assert(amount >= 0 && amount <= 1);

    final hsl = HSLColor.fromColor(color);
    HSLColor? hslColor;
    if (dark) {
      hslColor = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    } else {
      hslColor = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    }
    return hslColor.toColor();
  }
}

class MyRouteObserver extends NavigatorObserver {
  late GoRouter router;
  final WidgetFactory factory;

  MyRouteObserver({required this.factory});

  @override
  void didPush(Route route, Route? previousRoute) {
    //print("Route push: ${route.settings.name} ${router.state.path}");
    factory.routeControllerDesigner?.value = router.state.path!;
    factory.routeControllerViewer?.value = router.state.path!;
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    print("Route pop: ${route.settings.name}");
  }
}
