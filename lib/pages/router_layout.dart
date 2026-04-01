import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/core/designer/editor/engine/undo_manager.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/login/login_screen.dart';
import 'package:jsonschema/widget/tree_editor/pan_yaml_tree.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:jsonschema/widget/widget_global_zoom.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_show_error.dart';

bool showLoginDialog = true;
bool connectBdd = true;
bool autoLoging = true;

PanYamlTree? currentYamlTree;

ValueNotifier<String> dataProviderMode = ValueNotifier<String>('mock');

// ignore: must_be_immutable
class Layout extends StatefulWidget {
  const Layout({super.key, required this.navChild, required this.routerState});

  final Widget navChild;
  final GoRouterState routerState;

  @override
  State<Layout> createState() => _LayoutState();
}

class _LayoutState extends State<Layout> with WidgetHelper {
  @override
   Widget build(BuildContext context) {
    final String location = widget.routerState.uri.toString();

    GenericPage page = (getPage(context, widget.routerState) as GenericPage);

    var navigationInfo =
        page.initNavigation(widget.routerState, context, null)!;

    BreadCrumbNavigator.currentNavigationInfo = navigationInfo;

    if (!connectBdd) {
      showLoginDialog = false;
    }

    if (showLoginDialog) {
      showLoginDialog = false;
      Future.delayed(Duration(milliseconds: 200)).then((value) {
        // ignore: use_build_context_synchronously
        _dialogBuilder(context);
      });
    }

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
            resizeToAvoidBottomInset: true,
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
              actions: navigationInfo.actions,
            ),
            body: GestureDetector(
              onTap: () {
                //FocusScope.of(context).unfocus();
              },
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: getNavigationItem(navigationInfo, location, context),
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                  Expanded(
                    child: widget.navChild,
                    //  IndexedStack(index: 0, children: pages),
                    //child: widget.navChild,
                  ),
                ],
              ),
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
//                 IconButton(
//                   onPressed: () async {
//                     bool result = await askUser(
//                       context,
//                       'Confirmation',
//                       'Are you sure you want to clear the cache and reset the app?',
//                     );
//                     if (!result) return;

// //                    prefs.remove("page_designer_data_${factory.id}");
//                     String keyFactory = "query";
//                     WidgetFactory? aFactory = cacheLinkPage.get(keyFactory);
//                     if (aFactory != null) {
//                       aFactory.getEmptyApp();
//                       aFactory.pageDesignerKey.currentState?.setState(() {});
//                       aFactory.rootCtx?.widgetState?.clearWidgetCache();
//                       aFactory.rootCtx?.repaint();
//                       aFactory.rootCtx?.selectOnDesigner();
//                     }
//                   },
//                   icon: Icon(Icons.delete),
//                 ),
                IconButton(
                  onPressed: () {
                    globalUndoManager.undo();
                  },
                  icon: Icon(Icons.undo),
                ),
                IconButton(
                  onPressed: () {
                    globalUndoManager.redo();
                  },
                  icon: Icon(Icons.redo),
                ),
                ValueListenableBuilder(
                  valueListenable: dataProviderMode,
                  builder: (context, value, child) {
                    return SizedBox(
                      width: 400,
                      child: Row(
                        children: [
                          Text('Data from mock  '),
                          Padding(
                            padding: const EdgeInsets.all(0),
                            child: Checkbox(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,

                              visualDensity: const VisualDensity(
                                horizontal: -4,
                                vertical: -4,
                              ),
                              value: value == 'mock',
                              onChanged: (bool? newValue) {
                                dataProviderMode.value =
                                    (newValue ?? false ? 'mock' : 'api');
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Spacer(),
                Text('API Architect by Desomer G. V1.0.3.61'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget getAcgtionBtn(BuildContext context) {
  //   return PopupMenuButton<String>(
  //     onSelected: (value) {
  //       switch (value) {
  //         case 'Home':
  //           context.push('/');
  //           break;
  //         case 'Paramètres':
  //           context.push('/settings');
  //           break;
  //         case 'À propos':
  //           context.push('/about');
  //           break;
  //       }
  //     },
  //     itemBuilder:
  //         (context) => [
  //           const PopupMenuItem(value: 'Home', child: Text('Home')),
  //           const PopupMenuItem(value: 'Paramètres', child: Text('Paramètres')),
  //           const PopupMenuItem(value: 'À propos', child: Text('À propos')),
  //         ],
  //   );
  // }

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
      var p = element.path?.split('?');
      var elementPath = p != null && p.length == 2 ? p[0] : element.path; 
      if (elementPath == location) {
        selectedIndex = navigationInfo.navLeft.indexOf(element) + 1;
        break;
      }
    }

    List<NavigationRailDestination> contextMenu =
        navigationInfo.navLeft.map((item) {
          return NavigationRailDestination(
            disabled: item.path == null && item.onTap == null,
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
              context.pushReplacement(r.path!);
            }
          }
        }
      },
      labelType: NavigationRailLabelType.all,
      destinations: [
        NavigationRailDestination(icon: Icon(Icons.apps), label: Text('Home')),
        ...contextMenu,
      ],
    );
  }

  Future<void> _dialogBuilder(BuildContext context) async {
    var mail = prefs.getString("mail");
    var pwd = prefs.getString("pwd");

    return showDialog<void>(
      barrierDismissible: false,
      // ignore: use_build_context_synchronously
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: EdgeInsets.all(5),
          content: SizedBox(
            width: 500,
            height: 600,
            child: LoginScreen(email: mail ?? '', pwd: pwd ?? ''),
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
          ],
        ),
      ),
    );
  }
}

class WidgetSearchText extends StatefulWidget {
  const WidgetSearchText({super.key});

  @override
  State<WidgetSearchText> createState() => _WidgetSearchTextState();
}

class _WidgetSearchTextState extends State<WidgetSearchText> {
  int searchIndex = 0;
  int maxSearchIndex = 0;
  String value = '';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextToggle(),
        if (maxSearchIndex > 0) Text('${searchIndex + 1}/$maxSearchIndex '),
        SizedBox(
          width: 150,
          height: 30,
          child: TextField(
            onChanged: (value) {
              this.value = value;
              setState(() {
                if (currentYamlTree != null) {
                  searchIndex = 0;
                  maxSearchIndex = currentYamlTree!.setSearch(
                    value,
                    searchIndex,
                  );
                }
              });
            },
            decoration: const InputDecoration(
              hintText: 'Search',
              //contentPadding: EdgeInsets.symmetric(horizontal: 8),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          width: 20,
          child: GestureDetector(
            onTap: () {
              doNext();
            },
            child: Icon(Icons.arrow_left, size: 30),
          ),
        ),
        SizedBox(
          width: 20,
          child: GestureDetector(
            onTap: () {
              doPrev();
            },
            child: Icon(Icons.arrow_right, size: 30),
          ),
        ),
        SizedBox(width: 10),
        VerticalDivider(width: 1, thickness: 1, indent: 3, endIndent: 3),
      ],
    );
  }

  void doPrev() {
    setState(() {
      if (searchIndex < maxSearchIndex - 1) {
        searchIndex++;
      } else {
        searchIndex = 0;
      }
      maxSearchIndex = currentYamlTree?.setSearch(value, searchIndex) ?? 0;
    });
  }

  void doNext() {
    setState(() {
      searchIndex = searchIndex > 0 ? searchIndex - 1 : maxSearchIndex - 1;
      maxSearchIndex = currentYamlTree?.setSearch(value, searchIndex) ?? 0;
    });
  }
}

class UserAuthentication {
  static ValueNotifier<String> stateConnection = ValueNotifier<String>(
    'Connecting...',
  );

  void logIn(BuildContext context, String email, String password) async {
    BuildContext? ctx;

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (c) {
        ctx = c;
        return AlertDialog(
          content: Row(
            spacing: 50,
            children: [
              ValueListenableBuilder(
                valueListenable: stateConnection,
                builder: (context, value, child) {
                  return Text(
                    style: TextStyle(fontSize: 20),
                    stateConnection.value,
                  );
                },
              ),

              CircularProgressIndicator(),
            ],
          ),
        );
      },
    );

    await Future.delayed(Duration(milliseconds: 200));

    var ok = await startCore(email, password);
    // ignore: use_build_context_synchronously
    Navigator.of(ctx!).pop();
    if (ok) {
      await prefs.setString("mail", email);
      await prefs.setString("pwd", password);
      // ignore: use_build_context_synchronously
      Navigator.of(context).pop();
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login failed. Please check your credentials.'),
        ),
      );
    }
  }
}

class BackIntent extends Intent {
  const BackIntent();
}

class TextToggle extends StatefulWidget {
  const TextToggle({super.key});

  @override
  State<TextToggle> createState() => _TextToggleState();
}

class _TextToggleState extends State<TextToggle> {
  bool isOn = false;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed:
          () => setState(() {
            isOn = !isOn;
            if (currentYamlTree != null) {
              currentYamlTree!.changeFilterTarget(isOn ? 'api' : 'all');
            }
          }),
      child: Text(
        isOn ? "Only API target" : "API",
        style: TextStyle(
          color: isOn ? Colors.green : Colors.grey,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
