import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/list_editor/widget_list_editor.dart';
import 'package:jsonschema/widget/search_user/user.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_tab.dart';

class PanDomain extends StatelessWidget {
  PanDomain({super.key});

  final domainChanged = ValueNotifier(0);

  @override
  Widget build(BuildContext context) {
    currentCompany.listDomain!.onChange = (_) {
      if (currentCompany.listDomain!.selectedAttr == null &&
          currentCompany.listDomain!.useAttributInfo.isNotEmpty) {
        currentCompany.listDomain!.setCurrentAttr(
          currentCompany.listDomain!.useAttributInfo.first,
        );
      }
    };

    var listTab = <Widget>[];
    var listTabCont = <Widget>[];

    currentCompany.listEnv?.mapInfoByTreePath.forEach((key, value) {
      listTab.add(Tab(text: value.name));
      listTabCont.add(
        WidgetListEditor(
          withSpacer: false,
          model: null,
          getModel: () {
            var model = loadVarEnv(
              currentCompany.listDomain!.selectedAttr!.info.masterID!,
              value.masterID!,
              "variables",
              false,
            );
            return model;
          },
          change: domainChanged,
        ),
      );
    });

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: WidgetListEditor(
            model: currentCompany.listDomain,
            change: ValueNotifier(0),
            onSelectRow: () {
              domainChanged.value++;
            },
          ),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: domainChanged,
            builder: (context, value, child) {
              var s = currentCompany.listDomain!.selectedAttr?.info.name ?? '';
              return WidgetTab(
                listTab: [
                  Tab(text: '$s domain variables '),
                  Tab(text: '$s User rules'),
                ],
                listTabCont: [
                  Container(
                    decoration: BoxDecoration(
                      border: BoxBorder.fromLTRB(
                        top: BorderSide(color: Colors.grey, width: 1),
                      ),
                    ),
                    child: WidgetTab(
                      listTab: listTab,
                      listTabCont: listTabCont,
                      heightTab: 40,
                    ),
                  ),
                  Column(
                    children: [
                      Text('User rules for $s domain'),
                      ElevatedButton(
                        onPressed: () async {
                          final user = await showSearch<User?>(
                            context: context,
                            delegate: UserSearchDelegate(),
                          );

                          if (user != null) {
                            await bddStorage.supabase.from('user_auth').upsert({
                              'uid': user.id,
                              'category': 'domain',
                              'auth_id':
                                  currentCompany
                                      .listDomain!
                                      .selectedAttr!
                                      .info
                                      .masterID,
                              'company_id': currentCompany.companyId,
                              'rule': {
                                'create': true,
                                'update': false,
                                'delete': false,
                              },
                            });
                            domainChanged.value++;
                          }
                        },
                        child: Text('Add User Rule'),
                      ),
                      FutureBuilder<List<Map<String, dynamic>>?>(
                        future: bddStorage.getUserAuthByAuthId(
                          'domain',
                          '${currentCompany.listDomain!.selectedAttr?.info.masterID}',
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text("Erreur : ${snapshot.error}"),
                            );
                          }

                          final users = snapshot.data ?? [];

                          return Expanded(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: users.length,
                              itemBuilder: (context, index) {
                                final user = users[index];

                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      user['user_profil']['namedId'][0]
                                              .toUpperCase() +
                                          user['user_profil']['namedId'][1]
                                              .toUpperCase(),
                                    ),
                                  ),
                                  title: Text(user['user_profil']['namedId']),
                                  trailing: IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteUser(user, context),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
                heightTab: 40,
              );
            },
          ),
        ),
      ],
    );
    //   return Container(
    //     padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
    //     width: double.infinity,
    //     height: 30,
    //     color: Colors.blue,
    //     child: Row( spacing: 10,
    //       children: [
    //         Icon(Icons.data_object),
    //         Text(
    //           '${currentCompany.listDomain.selectedAttr?.info.name ?? ''} domain variables ',
    //         ),
    //       ],
    //     ),
    //   );
    // },
    //),
    // Expanded(
    //   child: ,
    // ),
    // ],
    //);
  }

  Future<void> _deleteUser(
    Map<String, dynamic> user,
    BuildContext context,
  ) async {
    try {
      await bddStorage.supabase
          .from('user_auth')
          .delete()
          .eq('uid', user['uid'])
          .eq('company_id', currentCompany.companyId)
          .eq('category', 'domain')
          .eq(
            'auth_id',
            '${currentCompany.listDomain!.selectedAttr?.info.masterID}',
          );
      domainChanged.value++;
    } catch (e) {
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text("delete failed: $e")));
    }
  }
}

//-------------------------------------------------------------
class InfoManagerDomain extends InfoManager with WidgetHelper {
  @override
  Function? getValidateKey() {
    return null;
  }

  @override
  void addRowWidget(
    NodeAttribut attr,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    row.add(
      CellEditor(
        inArray: true,
        key: ValueKey(attr.info.numUpdateForKey),
        acces: ModelAccessorAttr(node: attr, schema: schema, propName: 'title'),
      ),
    );
  }

  @override
  Widget getAttributHeaderOLD(TreeNode<NodeAttribut> node) {
    throw UnimplementedError();
  }

  @override
  String getTypeTitle(NodeAttribut node, String name, dynamic type) {
    return type.toString();
  }

  @override
  InvalidInfo? isTypeValid(
    NodeAttribut nodeAttribut,
    String name,
    type,
    String typeTitle,
  ) {
    return null; // No specific validation for environment variables
  }

  @override
  Widget getRowHeader(TreeNodeData<NodeAttribut> node, BuildContext context) {
    // TODO: implement getRowHeader
    throw UnimplementedError();
  }
}

//-------------------------------------------------------------
class InfoManagerDomainVariables extends InfoManager with WidgetHelper {
  @override
  Function? getValidateKey() {
    return null;
  }

  @override
  void addRowWidget(
    NodeAttribut attr,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    row.add(
      Expanded(
        child: CellEditor(
          inArray: true,
          widthInfinite: true,
          key: ValueKey(attr.info.numUpdateForKey),
          acces: ModelAccessorAttr(
            node: attr,
            schema: schema,
            propName: 'value',
          ),
        ),
      ),
    );
  }

  @override
  Widget getAttributHeaderOLD(TreeNode<NodeAttribut> node) {
    throw UnimplementedError();
  }

  @override
  String getTypeTitle(NodeAttribut node, String name, dynamic type) {
    return type.toString();
  }

  @override
  InvalidInfo? isTypeValid(
    NodeAttribut nodeAttribut,
    String name,
    type,
    String typeTitle,
  ) {
    return null; // No specific validation for environment variables
  }

  @override
  Widget getRowHeader(TreeNodeData<NodeAttribut> node, BuildContext context) {
    // TODO: implement getRowHeader
    throw UnimplementedError();
  }
}
