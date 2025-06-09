import 'dart:async';
import 'dart:core';

import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:flutter/foundation.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/bdd/data_event.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/editor/code_editor.dart';
import 'package:supabase/supabase.dart';

DataAcces bddStorage = DataAcces();

class DataAcces {
  late SupabaseClient supabase;
  StoreManager storeManager = StoreManager();

  Future<void> init() async {
    try {
      supabase = SupabaseClient(
        'https://oielmrsjyymltbkyeuec.supabase.co',
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9pZWxtcnNqeXltbHRia3lldWVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYxODkyMzAsImV4cCI6MjA2MTc2NTIzMH0.V8uEtQAhrXjRel_VCqgRX6aWAlJXJBwLLbNF7fAn0EM',
      );

      AuthResponse res = await supabase.auth.signInWithPassword(
        email: 'gauthier.desomer@gmail.com',
        password: 'test.archi',
      );
      // ignore: unused_local_variable
      final Session? session = res.session;
      // ignore: unused_local_variable
      final User? user = res.user;
    } on Exception catch (e) {
      print(e);
    }

    // Listen to auth state changes
    // supabase.auth.onAuthStateChange.listen((data) {
    //   final AuthChangeEvent event = data.event;
    //   final Session? session = data.session;
    //   // Do something when there is an auth event
    // });

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
  }

  late RealtimeChannel myChannel;
  Map<String, CacheValue> local = {};
  Map<String, OnEvent> doEventListner = {};

  Future<dynamic> _getFromSupabase(ModelSchemaDetail model, String id) async {
    if (id.startsWith('json/')) {
      print("load prop from bdd $id");
      var queryattr = supabase
          .from('attributs')
          .select('*')
          .eq('company_id', getCompanyId)
          .eq('schema_id', id.substring(5));
      var ret2 = await queryattr;
      if (ret2.isNotEmpty) {
        print('ret');
        model.modelProperties = {};
        for (var element in ret2) {
          AttributInfo info = AttributInfo();
          info.masterID = element['attr_id'];
          info.path = element['path'];
          info.properties = element['prop'];
          info.action = element['state'];
          model.modelProperties[info.path] = info.properties;
          model.mapInfoByJsonPath[info.path] = info;
        }
        return model.modelProperties;
      }
    } else {
      print("load yaml from bdd $id");
      var query = supabase
          .from('models')
          .select('json')
          .eq('compagny_id', getCompanyId)
          .eq('model_id', id);

      var ret = await query;
      if (ret.isNotEmpty) {
        return ret.first['json'];
      }
    }

    return null;
  }

  String get getCompanyId => 'test';

  dynamic getItemSync(String id, int delay) {
    if (delay == -1) {
      if (local[id] != null) {
        return local[id]!.value;
      }
    }
    return null;
  }

  dynamic getItem(ModelSchemaDetail model, String id, int delay) {
    if (delay == -1) {
      if (local[id] != null) {
        return local[id]!.value;
      }
    }
    return _getItemAsync(model, id);
  }

  Future<dynamic> _getItemAsync(ModelSchemaDetail model, String id) async {
    var ret = await _getFromSupabase(model, id);
    _setCache(id, ret);
    return ret;
  }

  void saveYAML({
    required String type,
    required ModelSchemaDetail model,
    dynamic value,
  }) async {
    if (local[model.id] != null) {
      var l = local[model.id]!.value;
      if (type == 'YAML') {
        computeSendYamlChangeEvent({'old': l, 'value': value, 'id': model.id})
        //compute(computeSendEvent, {'old': l, 'value': value, 'id': model.id});
        .then(_sendMessage);
      }
    }
    setYaml(model, value);
  }

  void dispatchChangeProp(
    ModelSchemaDetail model,
    dynamic patch,
    TextConfig textConfig,
  ) {
    var element = patch['payload'];
    var info = model.mapInfoByJsonPath[element['path']] ?? AttributInfo();
    info.masterID = element['attr_id'];
    info.path = element['path'];
    info.properties = element['prop'];
    info.action = element['state'];
    model.modelProperties[info.path] = info.properties;
    model.mapInfoByJsonPath[info.path] = info;
    info.cacheRowWidget = null;
    info.numUpdate++;
    // ignore: invalid_use_of_protected_member
    textConfig.treeJsonState.setState(() {});
  }

  dynamic dispatchChangeYAML({
    required String id,
    dynamic patch,
    dynamic value,
  }) {
    if (value == patch['old']) {
      local[id]!.value = patch['new'];
      return local[id]!.value;
    } else {
      List<Patch> patchDest = patchFromText(patch['patch']);
      DiffMatchPatch dmp = DiffMatchPatch();
      var result = dmp.patch_apply(patchDest, value);
      local[id]!.value = result.first;
      return local[id]!.value;
    }
  }

  void prepareSaveModel(ModelSchemaDetail model) async {
    var saveAttrDelete = [...model.notUseAttributInfo];
    var saveAttr = [...model.useAttributInfo];

    for (var attr in saveAttrDelete) {
      if (attr.masterID != null && !attr.isInitByRef && attr.action != 'D') {
        attr.action = 'D';

        var payload = {
          'company_id': getCompanyId,
          'namespace': 'main',
          'category': model.type.name,
          'schema_id': model.id,
          'version': '1',
          'attr_id': attr.masterID,
          'path': attr.path,
          'prop': attr.properties,
          'state': attr.action ?? 'D',
        };

        var save = SaveEvent(
          model: model,
          id: '${model.id};${attr.masterID}',
          table: 'attributs',
          data: payload,
        );

        _sendMessage({'typeEvent': 'PROP', 'id': model.id, 'payload': payload});

        storeManager.add(save);
      }
    }

    for (var attr in saveAttr) {
      if (attr.masterID != null && !attr.isInitByRef && attr.action != 'R') {
        attr.action = 'R';

        var payload = {
          'company_id': getCompanyId,
          'namespace': 'main',
          'category': model.type.name,
          'schema_id': model.id,
          'version': '1',
          'attr_id': attr.masterID,
          'path': attr.path,
          'prop': attr.properties,
          'state': attr.action ?? 'R',
        };

        var save = SaveEvent(
          model: model,
          id: '${model.id};${attr.masterID}',
          table: 'attributs',
          data: payload,
        );

        _sendMessage({'typeEvent': 'PROP', 'id': model.id, 'payload': payload});

        storeManager.add(save);
      }
    }
  }

  FutureOr<Null> _sendMessage(payload) async {
    try {
      print('send by ${payload['id']}'); // event $payload
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

  Future<void> _setSupabase(SaveEvent event) async {
    await supabase.from(event.table).upsert([event.data]);
  }

  void setYaml(ModelSchemaDetail model, dynamic value) async {
    _setCache(model.id, value);
    await _set(model, value);
  }

  Future _set(ModelSchemaDetail model, dynamic value) async {
    print("save models yaml ${model.id}");
    var save = SaveEvent(
      model: model,
      id: '${model.id};',
      table: 'models',
      data: {
        'compagny_id': getCompanyId,
        // 'namespace': 'main',
        'model_id': model.id,
        //'version': '1',
        'json': value,
      },
    );

    storeManager.add(save);
    // await supabase.from('models').upsert([
    //   {'compagny_id': getCompanyId, 'model_id': id, 'json': value},
    // ]);
  }

  void _setCache(String id, dynamic value) {
    if (value == null) {
      if (id.startsWith('json/')) {
        value = {};
      } else {
        value = '';
      }
      print(id);
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
}

//--------------------------------------------------------------------------

class StoreManager {
  Debouncer debouncer = Debouncer(milliseconds: 1000);
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
