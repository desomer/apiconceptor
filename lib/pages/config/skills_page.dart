import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/authorization_manager.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/json_browser/browse_model.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/prompts/prompt_model.dart';
import 'package:jsonschema/prompts/prompt_model_design.dart';
import 'package:jsonschema/prompts/prompt_persistence.dart';
import 'package:jsonschema/prompts/prompt_test.dart';
import 'package:jsonschema/prompts/prompt_usecase.dart';
import 'package:jsonschema/prompts/prompt_interface.dart';
import 'package:jsonschema/prompts/prompt_integration.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/mark_down_editor.dart';
import 'package:jsonschema/widget/splitview/widget_split.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_show_error.dart';

import '../../widget/editor/cell_prop_editor.dart';

class SkillsPage extends GenericPageStateless {
  const SkillsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsGeometry.all(10),
      child: SkillsPageContent(),
    );
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    GlobalKey keyPage,
    PageInit? pageInit,
  ) {
    return NavigationInfo();
  }
}

class SkillsPageContent extends StatefulWidget {
  const SkillsPageContent({super.key});

  @override
  State<SkillsPageContent> createState() => _SkillsPageContentState();
}

class _SkillsPageContentState extends State<SkillsPageContent> {
  late final Future<Map<String, String>> _markdownFuture;
  final List<TextEditingController> _controllers = [];
  final List<String> _savedMarkdown = [];
  final Set<int> _modifiedIndexes = {};
  final FocusNode _editorFocusNode = FocusNode();
  int _selectedIndex = 0;
  var skillManager = SkillManager();

  @override
  void initState() {
    super.initState();

    _markdownFuture = skillManager.loadMarkdown();
  }

  void _initializeMarkdownEditors(Map<String, String> markdownBySkill) {
    if (_controllers.isNotEmpty) return;

    _controllers.addAll(
      SkillManager.skillNames.map(
        (skillName) => TextEditingController(
          text: markdownBySkill[skillName] ?? '# $skillName\n',
        ),
      ),
    );
    _savedMarkdown.addAll(_controllers.map((controller) => controller.text));
    for (var index = 0; index < _controllers.length; index++) {
      _controllers[index].addListener(() => _onMarkdownChanged(index));
    }
  }

  void _onMarkdownChanged(int index) {
    final wasModified = _modifiedIndexes.contains(index);
    final isModified = _controllers[index].text != _savedMarkdown[index];
    if (wasModified == isModified) return;

    setState(() {
      if (isModified) {
        _modifiedIndexes.add(index);
      } else {
        _modifiedIndexes.remove(index);
      }
    });
  }

  void _saveMarkdown() {
    for (final index in _modifiedIndexes) {
      _savedMarkdown[index] = _controllers[index].text;
    }
    skillManager.saveMarkdown(_savedMarkdown);
    setState(_modifiedIndexes.clear);
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _editorFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _markdownFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Unable to load skills: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        _initializeMarkdownEditors(snapshot.data!);
        return _buildEditorLayout(context);
      },
    );
  }

  Widget _buildEditorLayout(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Badge.count(
                count: _modifiedIndexes.length,
                isLabelVisible: _modifiedIndexes.isNotEmpty,
                child: ElevatedButton.icon(
                  onPressed: _modifiedIndexes.isEmpty ? null : _saveMarkdown,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SplitView(
            primaryWidth: 240,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: ListView.builder(
                  itemCount: SkillManager.skillNames.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      selected: index == _selectedIndex,
                      leading: const Icon(Icons.psychology_outlined),
                      title: Text(SkillManager.skillNames[index]),
                      onTap: () {
                        setState(() => _selectedIndex = index);
                        _editorFocusNode.requestFocus();
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: MarkDownEditor(
                  key: ValueKey(_selectedIndex),
                  controller: _controllers[_selectedIndex],
                  focusNode: _editorFocusNode,
                  context: context,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class InfoManagerSkills extends InfoManager {
  @override
  Widget getRowHeader(TreeNodeData<NodeAttribut> node, BuildContext context) {
    // TODO: implement getRowHeader
    throw UnimplementedError();
  }

  @override
  String getTypeTitle(NodeAttribut node, String name, type) {
    return type;
  }

  @override
  Function? getValidateKey() {
    return null;
  }

  @override
  InvalidInfo? isTypeValid(
    NodeAttribut nodeAttribut,
    String name,
    type,
    String typeTitle,
  ) {
    return null;
  }
}

class SkillManager {
  static const skillNames = [
    'Model design',
    'Model change',
    'Swagger design',
    'Swagger change',
    'Hexa Model',
    'Hexa Persistence',
    'Hexa Use case',
    'Hexa Interface',
    'Hexa Integration',
    'Hexa Test model',
    'Hexa Test use case',
    'Hexa Test interface',
  ];

  ModelSchema? _schema;

  Future<Map<String, String>> loadMarkdown() async {
    _schema = await loadData("all", false);
    bool resetNeeded = true;

    if (_schema!.modelYaml.isEmpty || resetNeeded) {
      StringBuffer sb = StringBuffer();
      for (var choice in SkillManager.skillNames) {
        sb.write(choice);
        sb.writeln(" : skill");
      }
      _schema!.modelYaml = sb.toString();
      if (_schema!.doChangeAndRepaintYaml(null, true, 'import')) {
        print("Schema changed and repainted YAML");
      }
      var f = _schema!.onChange;
      if (f != null) f({});
    }

    BrowseSingle browseSingle = BrowseSingle(config: BrowserConfig());
    browseSingle.browse(_schema!, false);

    Map<String, String> ret = {};
    _schema!.mapInfoByName.forEach((key, value) {
      var path = value.first.getMasterIDPath();
      if (path.isEmpty) path = value.first.getMasterID();
      NodeAttribut attr = _schema!.getNodeByMasterIdPath(path)!;

      var accessor = ModelAccessorAttr(
        schema: _schema!,
        propName: key,
        node: attr,
      );
      ret[key] = accessor.get() ?? '';
      if (ret[key]!.isEmpty)
      {
        switch (key) {
          case 'Model design':
            ret[key] = promptModelDesign;
            break;
          case 'Model change':
            ret[key] = promptModelChange;
            break;            
          case 'Swagger design':
            ret[key] = promptPathAPI;
            break;  
          case 'Swagger change':
            ret[key] = '';
            break;              
          case 'Hexa Model':
            ret[key] = promptModel;
            break; 
          case 'Hexa Persistence':
            ret[key] = promptPersistence;
            break;
          case 'Hexa Use case':
            ret[key] = promptUseCase;
            break;
          case 'Hexa Interface':
            ret[key] = promptInterface;
            break;
          case 'Hexa Integration':
            ret[key] = promptIntegration;
            break;
          case 'Hexa Test model':
            ret[key] = promptTestDomain;
            break;
          case 'Hexa Test use case':
          case 'Hexa Test interface':
            ret[key] = '# $key\n';
            break;
          default:
            ret[key] = '';
        }
      }
    });

    return ret;
  }

  Future<ModelSchema> loadData(String idDomain, bool cache) async {
    var schema = ModelSchema(
      category: Category.skills,
      headerName: "skills",
      id: 'skills/$idDomain',
      infoManager: InfoManagerSkills(),
      refDomain: null,
    );
    schema.namespace = idDomain;

    if (withBdd) {
      try {
        await schema.loadYamlAndProperties(cache: cache, withProperties: true);
      } on Exception catch (e) {
        print("$e");
        startError.add("$e");
      }
    }
    schema.namespace = idDomain;
    currentCompany.currentApps = schema;
    schema.isReadOnlyModel = isProfilAdmin() == false;
    return schema;
  }

  void saveMarkdown(List<String> savedMarkdown) {
    int i = 0;
    _schema!.mapInfoByName.forEach((key, value) {
      print('$key = ${savedMarkdown[i]}');
      var path = value.first.getMasterIDPath();
      if (path.isEmpty) path = value.first.getMasterID();
      NodeAttribut attr = _schema!.getNodeByMasterIdPath(path)!;

      var accessor = ModelAccessorAttr(
        schema: _schema!,
        propName: key,
        node: attr,
      );
      accessor.set(savedMarkdown[i]);
      i++;
    });
  }
}
