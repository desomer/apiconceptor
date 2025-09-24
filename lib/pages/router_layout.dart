import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/login/login_screen.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:jsonschema/widget/widget_global_zoom.dart';
import 'package:jsonschema/widget/widget_show_error.dart';
import 'package:jsonschema/widget/widget_zoom_selector.dart';

bool showLoginDialog = true;

// ignore: must_be_immutable
class Layout extends StatefulWidget {
  const Layout({super.key, required this.navChild, required this.routerState});

  final Widget navChild;
  final GoRouterState routerState;

  @override
  State<Layout> createState() => _LayoutState();
}

class _LayoutState extends State<Layout> {
  @override
  Widget build(BuildContext context) {
    final String location = widget.routerState.uri.toString();

    GenericPage page = (getPage(context, widget.routerState) as GenericPage);

    var navigationInfo =
        page.initNavigation(widget.routerState, context, null)!;

    if (showLoginDialog) {
      showLoginDialog = false;
      Future.delayed(Duration(milliseconds: 200)).then((value) {
        // ignore: use_build_context_synchronously
        _dialogBuilder(context);
      });
    }

    // int _index = navigationInfo.navLeft.indexWhere(
    //   (element) => element.settings.name == navigationInfo.currentPage,
    // );

    // IndexedStack(index: _index, children: _pages),

    // List<Widget>? pages = []; //getAllPages(context);

    // //int index = indexOfPage(location);
    // pages.remove(page as Widget);
    // pages.insert(0, widget.navChild);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        navigatorKey.currentContext?.pop();
      },
      child: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.arrowLeft):
              const BackIntent(),
        },
        child: Actions(
          actions: {
            BackIntent: CallbackAction<BackIntent>(
              onInvoke: (intent) {
                context.pop();
                return null;
              },
            ),
          },
          child: Scaffold(
            backgroundColor: Color.fromARGB(255, 5, 1, 0),
            appBar: AppBar(
              toolbarHeight: 40,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1.0),
                child: Container(
                  color: Colors.grey.shade300, // Couleur de la bordure
                  height: 1.0, // Épaisseur de la bordure
                ),
              ),

              title: Row(
                children: [BackButton(), getBreadcrumb(navigationInfo)],
              ),
              actions: [
                Text('Open factor '),
                WidgetZoomSelector(zoom: openFactor),
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Rechercher',
                  onPressed: () {
                    // Action de recherche
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.notifications),
                  tooltip: 'Notifications',
                  onPressed: () {
                    // Action de notification
                  },
                ),
              ],
            ),
            body: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: getNavigationItem(navigationInfo, location, context),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child:
                      widget
                          .navChild, //  IndexedStack(index: 0, children: pages),
                  //child: widget.navChild,
                ),
              ],
            ),
            bottomNavigationBar: Row(
              children: [
                WidgetShowError(),
                SizedBox(width: 10),
                // InkWell(child: Icon(Icons.undo)),
                // SizedBox(width: 5),
                // InkWell(child: Icon(Icons.redo)),
                // SizedBox(width: 5),
                SizedBox(height: 20, child: WidgetGlobalZoom()),
                Spacer(),
                Text('API Architect by Desomer G. V0.3.3'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget getActionBtn(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'Home':
            context.push('/');
            break;
          case 'Paramètres':
            context.push('/settings');
            break;
          case 'À propos':
            context.push('/about');
            break;
        }
      },
      itemBuilder:
          (context) => [
            const PopupMenuItem(value: 'Home', child: Text('Home')),
            const PopupMenuItem(value: 'Paramètres', child: Text('Paramètres')),
            const PopupMenuItem(value: 'À propos', child: Text('À propos')),
          ],
    );
  }

  Widget getNavigationItem(
    NavigationInfo navigationInfo,
    String location,
    BuildContext context,
  ) {
    int selectedIndex = 0;
    var loc = location.split('?');
    if (loc.length == 2) {
      location = loc[0];
    }
    for (var element in navigationInfo.navLeft) {
      if (element.path == location) {
        selectedIndex = navigationInfo.navLeft.indexOf(element) + 1;
        break;
      }
    }

    List<NavigationRailDestination> contextMenu =
        navigationInfo.navLeft.map((item) {
          return NavigationRailDestination(
            icon: item.icon != null ? item.icon! : Icon(Icons.question_mark),
            label: Text(item.settings.name ?? "Unknown"),
          );
        }).toList();

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        if (index == 0) {
          context.push('/');
        } else {
          var r = navigationInfo.navLeft[index - 1];
          if (r.path != null) {
            if (location != r.path) {
              context.push(r.path!);
            }
          }
        }
        // switch (index) {
        //   case 0:
        //     context.push('/');
        //     break;
        //   case 1:
        //     context.push('/about');
        //     break;
        //   case 2:
        //     context.push('/about');
        //     break;
        //   case 3:
        //     context.push('/about');
        //     break;
        // }
      },
      labelType: NavigationRailLabelType.all,
      destinations: [
        NavigationRailDestination(icon: Icon(Icons.apps), label: Text('Home')),
        ...contextMenu,
        // NavigationRailDestination(
        //   icon: Icon(Icons.star_sharp),
        //   label: Text('Favorites'),
        // ),
        // NavigationRailDestination(
        //   icon: Icon(Icons.settings),
        //   label: Text('Parameters'),
        // ),
        // NavigationRailDestination(icon: Icon(Icons.info), label: Text('About')),
      ],
    );
  }

  Future<void> _dialogBuilder(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: EdgeInsets.all(5),
          content: SizedBox(
            width: 500,
            height: 600,
            child: LoginScreen(email: 'gdesomer@apiarchitect.com'),
          ),
        );
      },
    );
  }

  Widget getBreadcrumb(NavigationInfo navigationInfo) {
    return SizedBox(
      height: 40,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            BreadCrumbNavigator(
              key: BreadCrumbNavigator.keyBreadcrumb,
              getList: () {
                return navigationInfo.breadcrumbs;
              },
            ),
            //Spacer(),
            // Text('Open factor '),
            // WidgetZoomSelector(zoom: openFactor),
          ],
        ),
      ),
    );
  }
}

class BackIntent extends Intent {
  const BackIntent();
}
