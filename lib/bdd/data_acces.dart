import 'dart:core';

import 'package:supabase/supabase.dart';

DataAcces localStorage = DataAcces();

class DataAcces {
  late SupabaseClient supabase;

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

    // await supabase.from('ListModel').insert({
    //   "json": {"ok": "good"}
    // });
    // final data = await supabase.from('ListModel').select('json');
    // debugPrint(data.toString());

    //testBucket();
  }

  Map<String, CacheValue> local = {};

  Future<dynamic> _get(String id) async {
    print("load bdd $id");
    var query = supabase
        .from('models')
        .select('json')
        .eq('compagny_id', getCompanyId)
        .eq('model_id', id);

    var ret = await query;
    if (ret.isNotEmpty) {
      return ret.first['json'];
    }
    return null;
  }

  String get getCompanyId => 'test';

  Future _set(String id, dynamic value) async {
    //print("save bdd $id");
    await supabase.from('models').upsert([
      {'compagny_id': getCompanyId, 'model_id': id, 'json': value},
    ]);
  }

  dynamic getItemSync(String id, int delay) {
    if (delay == -1) {
      if (local[id] != null) {
        return local[id]!.value;
      }
    }
    return null;
  }

  dynamic getItem(String id, int delay) {
    if (delay == -1) {
      if (local[id] != null) {
        return local[id]!.value;
      }
    }
    return _getItemAsync(id);
  }

  Future<dynamic> _getItemAsync(String id) async {
    var ret = await _get(id);
    _setCache(id, ret);
    return ret;
  }

  void setItem(String id, dynamic value) async {
    _setCache(id, value);
    await _set(id, value);
  }

  void _setCache(String id, dynamic value) {
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

class CacheValue {
  int time = 0;
  dynamic value;
}

//postgre pw = alPMsV1bPKgs10v4
