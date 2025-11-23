import 'dart:async';
import 'dart:core';

import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/material.dart';
import 'package:jsonschema/core/bdd/data_event.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/pages/router_layout.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_show_error.dart';
import 'package:supabase/supabase.dart';

DataAcces bddStorage = DataAcces();
User? user;

class DataAcces {
  SupabaseClient? _sup;
  late SupabaseClient supabase;
  StoreManager storeManager = StoreManager();

  Future<bool> connect(String usermail, String password) async {
    print("connect to supabase");
    try {
      _sup ??= SupabaseClient(
        'https://oielmrsjyymltbkyeuec.supabase.co',
        'sb_publishable_e9UTDwq91xn659rSjkzhCw_Z-nO5k06',
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );

      supabase = _sup!;

      print("signInWithPassword to supabase");
      AuthResponse res = await supabase.auth.signInWithPassword(
        email: usermail,
        password: password, //'test.archi',
      );
      // ignore: unused_local_variable
      final Session? session = res.session;
      user = res.user;
      UserAuthentication.stateConnection.value = 'Loading profile ...';

      var queryattr = supabase
          .from('user_profil')
          .select('*')
          .eq('uid', user!.id);

      var ret2 = await queryattr;
      if (ret2.isNotEmpty) {
        for (var element in ret2) {
          // liste des company
          print('profil $element');
        }
      } else {
        UserAuthentication.stateConnection.value = 'Create ${user?.email}';
        await supabase.from('user_profil').upsert([
          {
            'uid': user!.id,
            'role': {
              'rule': ['invit'],
            },
          },
        ]);
      }

      // var l = await supabase.auth.admin.listUsers();
      // print("l");
    } on Exception catch (e) {
      print(e);
      return false;
    }

    // Listen to auth state changes
    // supabase.auth.onAuthStateChange.listen((data) {
    //   final AuthChangeEvent event = data.event;
    //   final Session? session = data.session;
    //   // Do something when there is an auth event
    // });

    print("init realtime to supabase");
    myChannel = supabase.channel('room-one'); // set your topic here

    // Simple function to log any messages we receive
    void messageReceived(payload) {
      //print(payload);
      doEventListner[payload['id']]?.onPatch(payload);
    }

    // Subscribe to the Channel
    myChannel
        .onBroadcast(
          event: 'shout',
          // Listen for "shout". Can be "*" to listen to all events
          callback: (payload) => messageReceived(payload),
        )
        .subscribe();

    print("end connect to supabase");
    return true;
  }

  late RealtimeChannel myChannel;
  Map<String, CacheValue> local = {};
  Map<String, OnEvent> doEventListner = {};
  Map<String, ModelVersion> lastVersionByMaster = {};

  Future<dynamic> getTrashSupabase(
    ModelSchema model,
    String id,
    String pathYaml,
  ) async {
    var queryattr = supabase
        .from('attributs')
        .select('*')
        .eq('company_id', currentCompany.companyId)
        .eq('state', 'D')
        .eq('schema_id', id)
        .order('update_at', ascending: false);
    var ret2 = await queryattr;
    if (ret2.isNotEmpty) {
      model.modelProperties = {};
      for (var element in ret2) {
        AttributInfo info = AttributInfo();
        info.masterID = element['attr_id'];
        info.path = element['path'];
        info.properties = element['prop'];
        info.action = element['state'];
        info.timeLastUpdate = DateTime.tryParse(element['update_at'] ?? '');
        model.mapInfoByTreePath[info.masterID!] = info;
        var path = 'root>$pathYaml>${info.masterID}';
        model.modelProperties[path] = info.properties;
        model.modelProperties[path]['_\$\$version'] = element['version'] ?? '1';
        model.mapInfoByJsonPath[path] = info;
      }
      return model.mapInfoByTreePath;
    }
    return null;
  }

  Future<dynamic> _getFromModelSupabase(
    ModelSchema model,
    String id,
    ModelVersion? version,
  ) async {
    if (id.startsWith('json/')) {
      //print("load prop from bdd $id");
      var queryattr = supabase
          .from('attributs')
          .select('*')
          .eq('version', version?.version ?? '1')
          .eq('company_id', currentCompany.companyId)
          .eq('namespace', model.namespace ?? currentCompany.currentNameSpace)
          .eq('schema_id', id.substring(5))
          .eq('state', 'R');
      var ret2 = await queryattr;
      if (ret2.isNotEmpty) {
        model.modelProperties = {};
        for (var element in ret2) {
          AttributInfo info = AttributInfo();
          info.masterID = element['attr_id'];
          info.path = element['path'];
          info.properties = element['prop'];
          info.action = element['state'];
          if (info.masterID?.startsWith('#') ?? false) {
            model.nodeExtended[info.masterID!] = NodeAttribut(
              parent: null,
              yamlNode: MapEntry('extended', 'extended'),
              info: info,
            );
          } else {
            model.modelProperties[info.path] = info.properties;
            model.mapInfoByJsonPath[info.path] = info;
          }
        }
        return model.modelProperties;
      }
    } else {
      //print("load yaml from bdd $id");
      var query = supabase
          .from('models')
          .select('json, namespace')
          .eq('namespace', model.namespace ?? currentCompany.currentNameSpace)
          .eq('compagny_id', currentCompany.companyId)
          .eq('model_id', id)
          .eq('version', version?.version ?? '1');

      var ret = await query;
      if (ret.isNotEmpty) {
        model.namespace =
            ret.first['namespace'] ?? currentCompany.currentNameSpace;
        return ret.first['json'];
      } else {
        model.namespace = currentCompany.currentNameSpace;
      }
    }

    return null;
  }

  dynamic getItemSync({
    required ModelSchema model,
    required String id,
    required int delay,
    required ModelVersion? version,
  }) {
    if (delay == -1) {
      String cacheId = getCacheId(model, id, version);
      if (local[cacheId] != null) {
        return local[cacheId]!.value;
      }
    }
    return null;
  }

  dynamic getItem({
    required ModelSchema model,
    required String id,
    required ModelVersion? version,
    required int delay,
    required bool setcache,
  }) {
    if (delay == -1) {
      String cacheId = getCacheId(model, id, version);
      if (local[cacheId] != null) {
        return local[cacheId]!.value;
      }
    }
    return _getItemAsync(
      model: model,
      id: id,
      version: version,
      setcache: setcache,
    );
  }

  Future<dynamic> _getItemAsync({
    required ModelSchema model,
    required String id,
    required ModelVersion? version,
    required bool setcache,
  }) async {
    var ret = await _getFromModelSupabase(model, id, version);
    if (setcache) {
      String cacheId = getCacheId(model, id, version);
      _setCache(cacheId, ret);
    }
    return ret;
  }

  String getCacheId(ModelSchema model, String id, ModelVersion? version) {
    return '${model.namespace}/$id/${version?.version ?? '1'}';
  }

  void saveYAML({
    required String type,
    required ModelSchema model,
    dynamic value,
  }) async {
    ModelVersion? version = model.currentVersion;
    String cacheId = getCacheId(model, model.id, version);
    if (local[cacheId] != null) {
      var l = local[cacheId]!.value;
      if (type == 'YAML') {
        computeSendYamlChangeEvent({
          'old': l,
          'value': value,
          'id': model.id,
          'version': version?.version ?? '1',
        })
        //compute(computeSendEvent, {'old': l, 'value': value, 'id': model.id});
        .then(_sendMessage);
      }
    }
    setYaml(model, value, version);
  }

  void dispatchChangeProperties(
    ModelSchema model,
    dynamic patch,
    CodeEditorConfig textConfig,
    String version,
  ) {
    var element = patch['payload'];
    if (model.getVersionId() == element['version']) {
      var info = model.mapInfoByJsonPath[element['path']] ?? AttributInfo();
      info.masterID = element['attr_id'];
      info.path = element['path'];
      info.properties = element['prop'];
      info.action = element['state'];
      model.modelProperties[info.path] = info.properties;
      model.mapInfoByJsonPath[info.path] = info;
      info.cacheRowWidget = null;
      info.numUpdateForKey++;
      if (textConfig.treeJsonState?.mounted ?? false) {
        // ignore: invalid_use_of_protected_member
        textConfig.treeJsonState?.setState(() {});
      }
    }
  }

  dynamic dispatchChangeYaml({
    required String id,
    dynamic patch,
    dynamic value,
    required String version,
  }) {
    String cacheId = '$id/$version';
    if (value == patch['old']) {
      local[cacheId]!.value = patch['new'];
      return local[cacheId]!.value;
    } else {
      List<Patch> patchDest = patchFromText(patch['patch']);
      DiffMatchPatch dmp = DiffMatchPatch();
      var result = dmp.patch_apply(patchDest, value);
      local[cacheId]!.value = result.first;
      return local[cacheId]!.value;
    }
  }

  void prepareSaveModel(ModelSchema model) async {
    var saveAttrDelete = [...model.notUseAttributInfo];
    var saveAttr = [...model.useAttributInfo];

    var extendedNode = model.nodeExtended.values.toList();
    for (var element in extendedNode) {
      saveAttr.add(element.info);
    }

    for (var attr in saveAttrDelete) {
      if (attr.masterID != null && !attr.isInitByRef && attr.action != 'D') {
        attr.action = 'D';

        var payload = {
          'company_id': currentCompany.companyId,
          'namespace': model.namespace ?? currentCompany.currentNameSpace,
          'category': model.category.name,
          'schema_id': model.id,
          'version': model.getVersionId(),
          'attr_id': attr.masterID,
          'path': attr.path,
          'prop': attr.properties,
          'state': attr.action ?? 'D',
          'update_at': DateTime.now().toIso8601String(),
        };

        var save = SaveEvent(
          model: model,
          version: model.currentVersion,
          id: '${model.id};${attr.masterID}',
          table: 'attributs',
          data: payload,
        );

        _sendMessage({'typeEvent': 'PROP', 'id': model.id, 'payload': payload});

        storeManager.add(save);
      }
    }

    var modelVerif = ModelSchema(
      category: model.category,
      headerName: '',
      id: '',
      infoManager: model.infoManager,
      ref: model.ref,
    );
    modelVerif.namespace = model.namespace;

    await _getFromModelSupabase(
      modelVerif,
      'json/${model.id}',
      model.currentVersion,
    );

    for (var attr in saveAttr) {
      if (attr.masterID != null && !attr.isInitByRef && attr.action != 'R') {
        attr.action = 'R';

        var payload = {
          'company_id': currentCompany.companyId,
          'namespace': model.namespace ?? currentCompany.currentNameSpace,
          'category': model.category.name,
          'schema_id': model.id,
          'version': model.getVersionId(),
          'attr_id': attr.masterID,
          'path': attr.path,
          'prop': attr.properties,
          'state': attr.action ?? 'R',
          'update_at': DateTime.now().toIso8601String(),
        };

        var save = SaveEvent(
          model: model,
          version: model.currentVersion,
          id: '${model.id};${attr.masterID}',
          table: 'attributs',
          data: payload,
        );

        var old = modelVerif.mapInfoByJsonPath[attr.path];
        if (old != null && old.masterID != attr.masterID) {
          print('pb ********** double master id **************');
          print('${model.namespace}/json/${model.id} path = ${attr.path}');
          showError('double master id on ${attr.path}');
        } else {
          _sendMessage({
            'typeEvent': 'PROP',
            'id': model.id,
            'payload': payload,
          });

          storeManager.add(save);
        }
      }
    }
  }

  FutureOr<Null> _sendMessage(dynamic payload) async {
    try {
      //print('send by ${payload['id']} $payload'); // event $payload
      //final res =
      await myChannel.sendBroadcastMessage(event: "shout", payload: payload);
      //print('call $res');
    } on Exception catch (e) {
      print(e);
    }
  }

  void doStore() {
    var store = {...storeManager.toStore};
    storeManager.toStore.clear();
    print('doStore ${store.length}');
    for (var element in store.entries) {
      _setSupabase(element.value);
    }
  }

  Future<List<ModelVersion>> getAllVersion(ModelSchema model) async {
    var id = model.id;
    var queryattr = supabase
        .from('versions')
        .select('*')
        .eq('company_id', currentCompany.companyId)
        .eq('model_id', id);

    var ret2 = await queryattr;

    var listVersion = <ModelVersion>[];
    if (ret2.isNotEmpty) {
      for (var element in ret2) {
        ModelVersion version = ModelVersion(
          id: id,
          version: element['version'],
          data: element['json'],
        );
        listVersion.add(version);
      }
      listVersion.sort();
    }
    model.versions = listVersion;
    print("load versions from bdd $id nb=${listVersion.length}");
    return listVersion;
  }

  Future<void> storeVersion(ModelSchema model, ModelVersion version) async {
    SaveEvent event = SaveEvent(
      version: version,
      model: model,
      id: '',
      table: 'versions',
      data: {
        'company_id': currentCompany.companyId,
        'model_id': model.id,
        'version': version.version,
        'json': version.data,
      },
    );
    return await _setSupabase(event);
  }

  Future<void> addApiParam(
    ModelSchema model,
    String id,
    String category,
    dynamic json,
  ) async {
    SaveEvent event = SaveEvent(
      version: null,
      model: model,
      id: '',
      table: 'api_params',
      data: {
        'id': id,
        'company_id': currentCompany.companyId,
        'api_id': model.id,
        'category': category,
        'param': json,
      },
    );
    return await _setSupabase(event);
  }

  Future<Map<String, dynamic>?> getAPIParam(
    ModelSchema model,
    String id,
  ) async {
    var apiid = model.id;
    //print("load param api from bdd $apiid");
    var queryattr = supabase
        .from('api_params')
        .select('*')
        .eq('company_id', currentCompany.companyId)
        .eq('api_id', apiid)
        .eq('id', id);
    var ret2 = await queryattr;
    if (ret2.isNotEmpty) {
      for (var element in ret2) {
        return element['param'];
      }
    }

    return null;
  }

  Future<void> _setSupabase(SaveEvent event) async {
    await supabase.from(event.table).upsert([event.data]);
  }

  void setYaml(ModelSchema model, dynamic value, ModelVersion? version) async {
    String cacheId = getCacheId(model, model.id, version);
    _setCache(cacheId, value);
    await _setYaml(model, value, version);
  }

  Future _setYaml(
    ModelSchema model,
    dynamic value,
    ModelVersion? version,
  ) async {
    print("save models yaml ${model.id}");

    var save = SaveEvent(
      model: model,
      version: version,
      id: '${model.id};',
      table: 'models',
      data: {
        'compagny_id': currentCompany.companyId,
        'namespace': model.namespace ?? currentCompany.currentNameSpace,
        'model_id': model.id,
        'version': version?.version ?? '1',
        'json': value,
      },
    );

    storeManager.add(save);
  }

  void _setCache(String id, dynamic value) {
    if (value == null) {
      if (id.contains('/json/')) {
        value = <String, dynamic>{};
      } else {
        value = '';
      }
      print('setcache $id');
    }

    if (local[id] != null) {
      local[id]!.time = DateTime.now().millisecondsSinceEpoch;
      local[id]!.value = value;
    } else {
      local[id] =
          CacheValue()
            ..time = DateTime.now().millisecondsSinceEpoch
            ..value = value;
    }
  }

  Future<void> duplicateVersion(
    ModelSchema model,
    ModelVersion version,
    String modelYaml,
    List<AttributInfo> properties,
  ) async {
    saveYAML(model: model, type: 'YAML', value: modelYaml);
    for (AttributInfo element in properties) {
      model.useAttributInfo.add(element.clone()..action = 'U');
    }
    prepareSaveModel(model);
    doStore();
  }
}

//--------------------------------------------------------------------------

class StoreManager {
  Debouncer debouncer = Debouncer(milliseconds: 3000);
  Map<String, SaveEvent> toStore = {};
  void add(SaveEvent event) {
    toStore[event.id] = event;
    debouncer.run(() {
      bddStorage.doStore();
    });
  }
}

class Debouncer {
  final int milliseconds;
  Timer? _timer;
  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}

class CacheValue {
  int time = 0;
  dynamic value;
}

//postgre pw = alPMsV1bPKgs10v4
