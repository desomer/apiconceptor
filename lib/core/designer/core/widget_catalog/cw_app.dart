import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_theme.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_slot.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';

class CwApp extends CwWidget {
  const CwApp({super.key, required super.ctx});

  static void initFactory(WidgetFactory factory) {
    factory.register(
      id: 'app',
      build: (ctx) => CwApp(key: ctx.getKey(), ctx: ctx),
      config: (ctx) {
        return CwWidgetConfig()
            // ..addSlot(CwWidgetSlotConfig(id: "appbar"))
            // ..addSlot(CwWidgetSlotConfig(id: "bottombar"))
            // ..addSlot(CwWidgetSlotConfig(id: "floatingActionButton"))
            // ..addSlot(CwWidgetSlotConfig(id: "body"))
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
    themeController.dispose();
    routeController.dispose();
    routerBuilderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildWidget(false, ModeBuilderWidget.noConstraint, (ctx, constraints) {
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

      // return MaterialApp(
      //   debugShowCheckedModeBanner: false,
      //   theme: theme,
      //   home: AnimatedBuilder(
      //     animation: themeController,
      //     builder: (context, _) {
      //       return getResponsiveDrawerScaffold(context, '/');
      //     },
      //   ),
      // );
      return ret;
    });
  }

  bool isModeDesktop() {
    return true;
  }


  GoRouter goRouter() {
    List<GoRoute> routes = [];

    var appRoutes = widget.ctx.aFactory.appData[cwApp][cwSlots] as Map;

    for (var route in appRoutes.entries) {
      var routeData = route.value;
      routes.add(
        GoRoute(
          path: routeData[cwRoutePath],
          //name: routeData[cwRouteName],
          pageBuilder:
              (context, state) => NoTransitionPage(
                child: getPage(context, route.value[cwRouteId]),
              ),
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

            return NoTransitionPage(child: getPage(context, route[cwRouteId]));
          },
        ),
      );
    }

    var myRouteObserver = MyRouteObserver(factory : widget.ctx.aFactory);
    var router = GoRouter(
      observers: [myRouteObserver],
      initialLocation: routeController.value,
      routes: [
        ShellRoute(
          //navigatorKey: widget.ctx.aFactory.rootNavigatorKey,
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
    //CwWidgetCtx pageCtx = widget.ctx.aFactory.getPageCtx(widget.ctx, routeId);
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
    print("Route push: ${route.settings.name} ${router.state.path}");
    factory.routeControllerDesigner?.value = router.state.path!;
    factory.routeControllerViewer?.value = router.state.path!;
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    print("Route pop: ${route.settings.name}");
  }
}
