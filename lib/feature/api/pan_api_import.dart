import 'package:flutter/material.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/core/import/url2api.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget_state/state_api.dart';

// ignore: must_be_immutable
class PanAPIImport extends StatelessWidget {
  PanAPIImport({super.key});

  late TabController tabImport;

  Widget _getImportTab(Url2Api import, ModelSchema model, BuildContext ctx) {
    return WidgetTab(
      onInitController: (TabController tab) {
        tabImport = tab;
        tab.addListener(() {});
      },
      listTab: [Tab(text: 'From urls'), Tab(text: 'From Open API Swagger')],
      listTabCont: [_getURLImport(import), _getAttrSelector(model)],
      heightTab: 40,
    );
  }

  Widget _getURLImport(Url2Api import) {
    return TextEditor(
      config: TextConfig(
        mode: markdown,
        getText: () {
          return '';
        },
        onChange: (String json, TextConfig config) {
          import.raw = json;
        },
        notifError: ValueNotifier(''),
      ),
      header: 'import list of urls',
    );
  }

  Widget _getAttrSelector(ModelSchema model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        //TextButton(onPressed: () {}, child: Text("Import")),
        //  Expanded(child: WidgetModelLink(listModel: model)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Url2Api import = Url2Api();

    ModelSchema model = ModelSchema(
      category: Category.selector,
      headerName: 'Select Models',
      id: 'model',
      infoManager: currentCompany.listModel.infoManager,
    );
    model.autoSaveProperties = false;
    model.mapModelYaml = currentCompany.listModel.mapModelYaml;
    model.modelProperties = currentCompany.listModel.modelProperties;

    Size size = MediaQuery.of(context).size;
    double width = size.width * 0.8;
    double height = size.height * 0.8;

    return AlertDialog(
      title: const Text('Import API from ...'),
      content: SizedBox(
        width: width,
        height: height,

        child: _getImportTab(import, model, context),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('Import'),
          onPressed: () {
            if (tabImport.index == 0) {
              var modelSchemaDetail = currentCompany.listAPI;
              modelSchemaDetail.modelYaml =
                  import.doImportJSON(modelSchemaDetail).yaml.toString();

              stateApi.repaintListAPI();

              modelSchemaDetail.doChangeAndRepaintYaml(null, true, 'import');

              // WidgetsBinding.instance.addPostFrameCallback((_) {
              //   var newModel =
              //       modelSchemaDetail
              //           .mapInfoByJsonPath['root>$domainKey>$nameKey'];
              //   var id = newModel!.masterID!;
              //   var aModel = ModelSchemaDetail(
              //     type: YamlType.model,
              //     infoManager: InfoManagerModel(typeMD: TypeMD.model),
              //     name: nameKey,
              //     id: id,
              //   );
              //   aModel.modelYaml = yaml;
              //   aModel.doChangeYaml(null, true, 'import');
              // });
            } else if (tabImport.index == 1) {
              //doImportFromModel(model);
            }
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  // void doImportFromModel(ModelSchemaDetail model) {
  //   print(model.lastBrowser?.selectedPath);
  //   for (var sel in model.lastBrowser?.selectedPath ?? {}) {
  //     var info = model.mapInfoByJsonPath[sel];
  //     var node = (model.lastJsonBrowser as JsonBrowserWidget).findNode(info!);
  //     var data = node!.data;
  //     List<NodeAttribut> path = [];
  //     while (data != null) {
  //       path.insert(0, data);
  //       data = data.parent;
  //       if (data?.info.type == 'model') {
  //         break;
  //       }
  //     }

  //     var modelSchemaDetail = currentCompany.currentModel!;
  //     modelSchemaDetail.modelYaml = '${modelSchemaDetail.modelYaml}add';
  //     // ignore: invalid_use_of_protected_member
  //     stateModel.keyModelYamlEditor.currentState?.setState(() {});
  //     modelSchemaDetail.doChangeYaml(null, true, 'import');
  //   }
  // }
}
