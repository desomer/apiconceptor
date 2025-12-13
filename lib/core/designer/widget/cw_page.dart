import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';
import 'package:jsonschema/core/designer/cw_slot.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';

class CwPage extends CwWidget {
  const CwPage({super.key, required super.ctx});

  static void initFactory(WidgetFactory factory) {
    factory.builderWidget['page'] = (ctx) {
      return CwPage(ctx: ctx);
    };

    factory.builderConfig['page'] = (ctx) {
      return CwWidgetConfig(id: "page")
        ..addSlot(CwWidgetSlotConfig(id: "appbar"))
        ..addSlot(CwWidgetSlotConfig(id: "bottombar"))
        ..addSlot(CwWidgetSlotConfig(id: "floatingActionButton"))
        ..addSlot(CwWidgetSlotConfig(id: "body"))
        ..addProp(
          CwWidgetProperties(id: 'color', name: 'seed color')..isColor(ctx),
        )
        ..addProp(
          CwWidgetProperties(id: 'darkMode', name: 'dark mode')..isBool(ctx),
        )
        ..addProp(
          CwWidgetProperties(id: 'floating', name: 'floating Action Button')
            ..isBool(ctx),
        )
        ..addProp(
          CwWidgetProperties(id: 'bottomBar', name: 'bottom Navigation Bar')
            ..isBool(ctx),
        );
    };
  }

  @override
  State<CwPage> createState() => CwPageState();
}

class CwPageState extends CwWidgetState<CwPage> with HelperEditor {
  @override
  Widget build(BuildContext context) {
    return buildWidget((ctx) {
      var isDark = getBoolProp(widget.ctx, 'darkMode') ?? false;
      ThemeData theme = getTheme(isDark);

      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: getResponsiveDrawerScaffold(context),
      );
    });
  }

  bool isModeDesktop() {
    return true;
  }

  Widget getResponsiveDrawerScaffold(BuildContext context) {
    bool isDesktop = isModeDesktop();
    var withFloating = getBoolProp(widget.ctx, 'floating') ?? false;
    var withBottomBar = getBoolProp(widget.ctx, 'bottomBar') ?? false;
    var withDrawer =
        getBoolProp(widget.ctx.childrenCtx?['appbar'], 'drawer') ?? false;
    var fixDrawer =
        getBoolProp(widget.ctx.childrenCtx?['appbar'], 'fixDrawer') ?? false;

    Widget? drawer;
    if (withDrawer) {
      drawer = Drawer(
        child: getSlot(CwSlotProp(id: 'rdrawer', name: 'right drawer')),
        // child: ListView(
        //   padding: EdgeInsets.zero,
        //   children: const [
        //     DrawerHeader(child: Text('Menu')),
        //     ListTile(leading: Icon(Icons.home), title: Text('Accueil')),
        //     ListTile(leading: Icon(Icons.info), title: Text('À propos')),
        //   ],
        // ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar:
          isDesktop
              ? getSlot(CwSlotProp(id: 'appbar', name: 'app bar'))
              : getSlot(CwSlotProp(id: 'appbar', name: 'app bar')),
      floatingActionButton:
          withFloating
              ? FloatingActionButton(
                onPressed: () {
                  // Action du bouton flottant
                },
                child: getSlot(
                  CwSlotProp(
                    id: 'floatingActionButton',
                    name: 'floating Action Button',
                  ),
                ),
              )
              : null,
      drawer: isDesktop && fixDrawer ? null : drawer,
      body: getBody(isDesktop && fixDrawer, drawer),

      // persistentFooterButtons: [
      //   TextButton(onPressed: () {}, child: const Text("Annuler")),
      //   ElevatedButton(onPressed: () {}, child: const Text("Valider")),
      // ],
      floatingActionButtonLocation:
          withBottomBar ? FloatingActionButtonLocation.miniCenterDocked : null,
      bottomNavigationBar:
          withBottomBar
              ? (getSlot(CwSlotProp(id: 'bottombar', name: 'bottom bar'))
                ..setDefaultLayout((context, child) {
                  return BottomAppBar(
                    shape: const CircularNotchedRectangle(),
                    child: child,
                  );
                }))
              : null,

      // bottomNavigationBar : BottomAppBar(
      //                 shape: const CircularNotchedRectangle(),
      //                 child: Row(
      //                   mainAxisAlignment: MainAxisAlignment.spaceAround,
      //                   children: [
      //                     IconButton(icon: Icon(Icons.menu), onPressed: () {}),
      //                     IconButton(icon: Icon(Icons.search), onPressed: () {}),
      //                   ],
      //                 ),
      //               )

      // bottomNavigationBar: BottomNavigationBar(
      //   // currentIndex: _selectedIndex,
      //   // onTap: _onItemTapped,
      //   items: const [
      //     BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
      //     BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Recherche'),
      //     BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
      //   ],
      // ),
    );
  }

  Widget getBody(bool isDesktop, Widget? drawer) {
    if (isDesktop && drawer != null) {
      return Row(
        children: [
          SizedBox(width: 250, child: drawer),
          // contenu principal
          Expanded(child: getSlot(CwSlotProp(id: 'body', name: 'body'))),
        ],
      );
    } else {
      return getSlot(CwSlotProp(id: 'body', name: 'body'));
    }
  }

  ThemeData getTheme(bool isDark) {
    Color mainColor =
        getColorFromHex(widget.ctx, 'color') ??
        (isDark ? Colors.grey.shade900 : Colors.white);

    Color barForegroundColor =
        (mainColor.computeLuminance() > 0.400)
            ? lightenOrDarken(true, mainColor, 0.5) // dark
            : lightenOrDarken(false, mainColor, 0.5);

    var colorScheme2 = ColorScheme.fromSeed(
      seedColor: mainColor,
      brightness: isDark ? Brightness.dark : Brightness.light,
    );

    var theme = ThemeData(
      //scaffoldBackgroundColor: mainColor,
      appBarTheme: AppBarTheme(
        foregroundColor: barForegroundColor,
        backgroundColor: mainColor,
      ),
      useMaterial3: true,
      colorScheme: colorScheme2,
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
