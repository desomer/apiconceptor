import 'package:collection/collection.dart';
import 'package:jsonschema/core/api/call_ds_manager.dart';
import 'package:jsonschema/core/designer/editor/view/bloc_drag_components.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_repository.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_action.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/content/widget/widget_content_helper.dart';
import 'package:jsonschema/feature/transform/pan_response_viewer.dart';
import 'package:jsonschema/start_core.dart';
import 'package:shortid/shortid.dart';

class CwFactoryBloc with NameMixin {
  Future<void> createRepositoriesIfNeeded(
    WidgetFactory aFactory,
    Map<String, dynamic> data,
    bool loadLater,
  ) async {
    Map listRepo = data[cwRepos];
    for (String key in listRepo.keys) {
      var rpConfig = listRepo[key];
      if (aFactory.mapRepositories[key] == null) {
        var repo = CwRepository(config: rpConfig, aFactory: aFactory);
        aFactory.mapRepositories[key] = repo;
        await repo.ds.loadDs(rpConfig[cwProps]["dsId"], null);
        var schemaCriteria = repo.ds.helper!.apiCallInfo.currentAPIRequest!;

        await repo.designState.criteriaState.init(schemaCriteria, true);
        await repo.viewerState.criteriaState.init(schemaCriteria, true);
        repo.designState.dataState.init(repo.ds.modelHttp200!, true);
        repo.viewerState.dataState.init(repo.ds.modelHttp200!, false);

        var h = repo.ds.helper!;

        if (repo.ds.configApp.paramToLoad != null) {
          await h.loadCriteriaFromParam(
            repo.ds.configApp.paramToLoad!,
            repo.viewerState.criteriaState.data,
            repo.viewerState.criteriaState.dataEmpty,
          );
        }
        if (loadLater) {
          Future.delayed(Duration(seconds: 1), () {
            loadAllData(repo);
          });
        } else {
          loadAllData(repo);
        }
      }
    }
  }

  void loadAllData(CwRepository repo) {
    repo.designState.criteriaState.loadDataInContainer(
      repo.designState.criteriaState.data,
    );
    repo.designState.dataState.loadDataInContainer(
      repo.designState.dataState.data,
    );
    repo.viewerState.criteriaState.loadDataInContainer(
      repo.viewerState.criteriaState.data,
    );
  }

  Future<Map<String, dynamic>?> doDataSrcBloc(
    Map config,
    CallerDatasource ds,
    CwWidgetCtx ctx,
  ) async {
    bool withActionCriteria = false;
    List<Map<String, dynamic>> actions = [];
    String typeContainer = "criteria";
    String? listPathArray;

    String repositoryId = await getRepositoryIdAndCreateIfNeeded(
      config,
      ctx,
      ds,
    );

    var propContainer = <String, dynamic>{};
    Map<String, dynamic> containerData = initContainer(
      ds,
      propContainer,
      repositoryId,
      ctx,
    );

    var listAttrSelected = ds.selectionConfig;
    for (var i = 0; i < listAttrSelected.length; i++) {
      ModelSchema? model;
      bool isAttribute = false;

      if (listAttrSelected[i]['src'] == 'Actions') {
        await addAction(
          model,
          listAttrSelected,
          i,
          ctx,
          containerData,
          repositoryId,
          ds,
        );
      } else if (listAttrSelected[i]['src'] == 'Criteria') {
        model = ds.helper!.apiCallInfo.currentAPIRequest!;
        typeContainer = 'criteria';
        withActionCriteria = true;
        isAttribute = true;
      } else if (listAttrSelected[i]['src'] == 'Data') {
        model = ds.modelHttp200!;
        typeContainer = 'data';
        isAttribute = true;
      }

      if (isAttribute) {
        var aListPathArray = addAttribute(
          model,
          listAttrSelected,
          i,
          ctx,
          containerData,
          repositoryId,
          ds,
        );
        if (aListPathArray != null) {
          listPathArray = aListPathArray;
        }
      }
    }

    if (withActionCriteria) {
      addActionCriteria(ctx, repositoryId, actions);
    }
    for (var i = 0; i < actions.length; i++) {
      ctx.aFactory.addInSlot(
        containerData,
        'cell_${listAttrSelected.length + i}',
        actions[i],
      );
    }

    propContainer['nbchild'] = listAttrSelected.length + actions.length;

    if (ds.typeLayout == 'List') {
      // surround par un list widget
      var list = {
        cwImplement: 'list',
        cwProps: <String, dynamic>{
          'bind': {
            'repository': repositoryId,
            'from': typeContainer,
            'attr': listPathArray,
          },
        },
      };
      ctx.aFactory.addInSlot(list, 'item0', containerData);
      containerData = list;
    } else if (ds.typeLayout == 'Table') {
      propContainer['bind']['attr'] = listPathArray;
    }

    return containerData;
  }

  Future<String> getRepositoryIdAndCreateIfNeeded(
    Map<dynamic, dynamic> config,
    CwWidgetCtx ctx,
    CallerDatasource ds,
  ) async {
    String? repositoryId;
    if (config[cwType] == 'datasource') {
      // creation du repository si n'existe pas
      repositoryId = shortid.generate();
      ctx.aFactory.appData[cwRepos][repositoryId] = {
        cwImplement: 'repos',
        cwSlotId: repositoryId,
        cwProps: <String, dynamic>{
          'domain': ds.domainDs,
          'dsId': ds.dsId,
          'name': ds.dsName,
        },
      };
      await createRepositoriesIfNeeded(
        ctx.aFactory,
        ctx.aFactory.appData,
        false,
      );
      componentValueListenable.value++;
    } else if (config[cwType] == 'repository') {
      repositoryId = config['id'];
    }
    return repositoryId ?? '?';
  }

  Map<String, dynamic> initContainer(
    CallerDatasource ds,
    Map<String, dynamic> propContainer,
    String repositoryId,
    CwWidgetCtx ctx,
  ) {
    Map<String, dynamic>? containerData;

    if (ds.typeLayout == 'Table') {
      // add table container
      propContainer.addAll(<String, dynamic>{
        'bind': {'repository': repositoryId, 'from': 'data'},
      });
      containerData = {cwImplement: 'table', cwProps: propContainer};
      // affecte le style de la ligne de la table
      ctx.aFactory.addInSlot(containerData, 'd-row', {
        cwImplement: 'row',
        cwProps: <String, dynamic>{
          "style": {
            "elevation": 4,
            "bRadius": 20,
            "pbottom": 5,
            "pleft": 5,
            "pright": 5,
            "mleft": 10,
            "mright": 10,
            "bColor": "FFD5E3EA",
            "bSize": 1,
          },
        },
      });
    } else {
      // add form container
      propContainer.addAll(<String, dynamic>{
        'type': 'column',
        'layout': 'form',
      });
      containerData = {cwImplement: 'container', cwProps: propContainer};

      if (ctx.parentCtx?.dataWidget?[cwImplement] == 'container' &&
          (ctx.parentCtx?.dataWidget?[cwProps]?['type'] ?? 'column') ==
              'column') {
        // hauteur à la hauteur du contenu si parent colonne
        containerData[cwPropsSlot] = <String, dynamic>{"fit": "inner"};
      }
    }
    return containerData;
  }

  String? addAttribute(
    ModelSchema? model,
    List<Map<String, dynamic>> listAttrSelected,
    int i,
    CwWidgetCtx ctx,
    Map<String, dynamic> containerData,
    String repositoryId,
    CallerDatasource ds,
  ) {
    String? listPathArray;
    var attrSelected = listAttrSelected[i];
    var info = model!.nodeByMasterId[attrSelected['id']]!.info;
    var v = info.path;
    int it = v.lastIndexOf("[]");
    if (it > 0) {
      var lp = v.substring(0, it + 2);
      var attr = model.mapInfoByJsonPath[lp];
      if (attr != null) {
        listPathArray = attr.masterID ?? attr.properties?[constMasterID];
      }
    }

    ctx.aFactory.addInSlot(containerData, 'cell_$i', {
      cwImplement: 'input',
      cwProps: <String, dynamic>{
        'label': camelCaseToWords(info.name),
        'type': 'textfield',
        'bind': {
          'attr': info.masterID,
          'from': attrSelected['src'].toString().toLowerCase(),
          'repository': repositoryId,
        },
        if (ds.typeLayout == 'Table') "style": {"appearance": "custom"},
      },
    });

    if (ds.typeLayout == 'Table') {
      // ajout des header
      ctx.aFactory.addInSlot(containerData, 'header_$i', {
        cwImplement: 'input',
        cwProps: <String, dynamic>{
          'label': camelCaseToWords(info.name),
          "style": {"boxAlignH": "0", "boxAlignV": "0"},
        },
      });
    }
    return listPathArray;
  }

  Future<String?> addAction(
    ModelSchema? model,
    List<Map<String, dynamic>> listAttrSelected,
    int i,
    CwWidgetCtx ctx,
    Map<String, dynamic> containerData,
    String repositoryId,
    CallerDatasource ds,
  ) async {
    String? listPathArray;
    var attrSelected = listAttrSelected[i];
    var link = attrSelected['id'] as ConfigLink;

    var infoLink = {"linkTo": link.toDatasrc, "onPath": link.onPath};
    CallerDatasource dsDest = CallerDatasource();
    await dsDest.loadDs('#name=${link.toDatasrc}', null);

    Map<String, dynamic> repos = ctx.aFactory.appData[cwRepos];
    var repo = repos.values.firstWhereOrNull((element) {
      return element[cwProps]["name"] == link.toDatasrc;
    });
    if (repo == null) {
      var infoDS = {
        'domain': dsDest.domainDs,
        'dsId': dsDest.dsId,
        'name': dsDest.dsName,
      };
      infoLink['repository'] = await getRepositoryIdAndCreateIfNeeded(
        {cwType: 'datasource', cwProps: infoDS},
        ctx,
        dsDest,
      );
      componentValueListenable.value++;
    } else {
      infoLink['repository'] = repo[cwSlotId];
    }

    AttributInfo? info;
    if (attrSelected['type'] == 'data_link') {
      var jsonPath =
          'root${link.onPath.replaceAll('/', '>').replaceAll('[*]', '[]')}';
      info = ds.modelHttp200!.mapInfoByJsonPath[jsonPath]!;
    }

    ctx.aFactory.addInSlot(containerData, 'cell_$i', {
      cwImplement: 'action',
      cwProps: <String, dynamic>{
        'label': camelCaseToWords(link.title),
        'bind': {
          'attr': info?.masterID ?? '?',
          'from': attrSelected['type'] == 'data_link' ? 'data' : 'criteria',
          'repository': repositoryId,
        },
        cwOnPressed: {
          cwType: "repository",
          "operation": "link2Datasrc",
          "link": infoLink,
          "repository": repositoryId,
        },
        if (ds.typeLayout == 'Table') "style": {"appearance": "custom"},
      },
    });

    if (ds.typeLayout == 'Table') {
      // ajout des header
      ctx.aFactory.addInSlot(containerData, 'header_$i', {
        cwImplement: 'input',
        cwProps: <String, dynamic>{
          'label': camelCaseToWords(link.title),
          "style": {"boxAlignH": "0", "boxAlignV": "0"},
        },
      });
    }
    return listPathArray;
  }

  void addActionCriteria(
    CwWidgetCtx ctx,
    String repositoryId,
    List<Map<String, dynamic>> actions,
  ) {
    var actionBar = {
      cwImplement: "container",
      cwProps: <String, dynamic>{
        "type": "row",
        "nbchild": 1,
        "mainAxisAlign": "end",
      },
    };

    ctx.aFactory.addCmpInSlot(
      actionBar,
      "cell_0",
      cmpType: "action",
      props: <String, dynamic>{
        'label': 'search',
        "type": "elevated",
        "icon": {"pack": "material", "key": "youtube_searched_for"},
        cwOnPressed: {
          cwType: "repository",
          "operation": "load",
          "repository": repositoryId,
        },
      },
      slotProps: <String, dynamic>{"fit": "inner"},
    );

    actions.add(actionBar);
  }
}
