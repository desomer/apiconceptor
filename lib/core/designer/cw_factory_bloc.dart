import 'package:jsonschema/core/api/call_ds_manager.dart';
import 'package:jsonschema/core/designer/component/widget_cmp_choiser.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';
import 'package:jsonschema/core/designer/cw_repository.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/content/widget/widget_content_helper.dart';
import 'package:jsonschema/start_core.dart';
import 'package:uuid/uuid.dart';

class CwFactoryBloc with NameMixin {
  Future<void> createRepositoryIfNeeded(CwWidgetCtx ctx) async {
    Map listSlot = ctx.aFactory.data[cwSlots];
    for (String key in listSlot.keys) {
      if (key.startsWith('rp_')) {
        var rpConfig = listSlot[key];
        if (ctx.aFactory.mapRepositories[key] == null) {
          var repo = CwRepository(config: rpConfig, aFactory: ctx.aFactory);
          ctx.aFactory.mapRepositories[key] = repo;
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
      }
    }
  }

  Future<Map<String, dynamic>?> doDataSrcBloc(
    Map config,
    CallerDatasource ds,
    CwWidgetCtx ctx,
  ) async {
    String repositoryId = '';
    if (config['type'] == 'datasource') {
      // creation du repository si n'existe pas
      repositoryId = Uuid().v7();
      ctx.aFactory.data[cwSlots]['rp_$repositoryId'] = {
        cwType: 'repos',
        cwId: repositoryId,
        cwProps: <String, dynamic>{'domain': ds.domainDs, 'dsId': ds.dsId},
      };
      await createRepositoryIfNeeded(ctx);
      componentValueListenable.value++;
    } else if (config['type'] == 'repository') {
      repositoryId = config[cwId];
    }

    Map<String, dynamic>? ret;
    var listAttrSelected = ds.selectionConfig;

    var propContainer = <String, dynamic>{'type': 'column', 'layout': 'form'};
    ret = {cwType: 'container', cwProps: propContainer};

    if (ctx.parentCtx?.dataWidget?[cwType] == 'container' &&
        (ctx.parentCtx?.dataWidget?[cwProps]?['type'] ?? 'column') ==
            'column') {
      // hauteur à la hauteur du contenu si parent colonne
      ret[cwPropsSlot] = <String, dynamic>{"fit": "inner"};
    }

    bool addAction = true;
    List<Map<String, dynamic>> actions = [];
    String typeContainer = "criteria";
    String? listPath;

    for (var i = 0; i < listAttrSelected.length; i++) {
      ModelSchema? model;

      if (listAttrSelected[i]['src'] == 'Criteria') {
        model = ds.helper!.apiCallInfo.currentAPIRequest!;
        if (addAction == true) {
          addAction = false;
          typeContainer = 'criteria';
          addActionCriteria(ctx, repositoryId, actions);
        }
      } else if (listAttrSelected[i]['src'] == 'Data') {
        model = ds.modelHttp200!;
        typeContainer = 'data';
      }

      var info = model!.nodeByMasterId[listAttrSelected[i]['id']]!.info;
      var v = info.path;
      int it = v.lastIndexOf("[]");
      if (it > 0) {
        var lp = v.substring(0, it + 2);
        var attr = model.mapInfoByJsonPath[lp];
        if (attr != null) {
          listPath = attr.masterID ?? attr.properties?[constMasterID];
        }
      }

      ctx.aFactory.addInSlot(ret, 'cell_$i', {
        cwType: 'input',
        cwProps: <String, dynamic>{
          'label': camelCaseToWords(info.name),
          'type': 'textfield',
          'bind': {
            'attr': info.masterID,
            'from': listAttrSelected[i]['src'].toString().toLowerCase(),
            'repository': repositoryId,
          },
        },
      });
    }

    for (var i = 0; i < actions.length; i++) {
      ctx.aFactory.addInSlot(
        ret,
        'cell_${listAttrSelected.length + i}',
        actions[i],
      );
    }

    propContainer['nbchild'] = listAttrSelected.length + actions.length;

    if (ds.typeLayout == 'List') {
      var list = {
        cwType: 'list',
        cwProps: <String, dynamic>{
          'bind': {
            'repository': repositoryId,
            'from': typeContainer,
            'attr': listPath,
          },
        },
      };
      ctx.aFactory.addInSlot(list, 'item0', ret);
      ret = list;
    }

    return ret;
  }

  void addActionCriteria(
    CwWidgetCtx ctx,
    String repositoryId,
    List<Map<String, dynamic>> actions,
  ) {
    var actionBar = {
      cwType: "container",
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
        "onPressed": {
          "type": "repository",
          "operation": "load",
          "repository": repositoryId,
        },
      },
      slotProps: <String, dynamic>{"fit": "inner"},
    );

    actions.add(actionBar);
  }
}
