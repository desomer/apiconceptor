import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:jsonschema/company_model.dart';

class OnEvent {
  OnEvent({required this.id, required this.onPatch});

  String id;
  Function onPatch;
}

class SaveEvent {
  SaveEvent({
    required this.model,
    required this.id,
    required this.table,
    required this.data,
  });
  ModelSchemaDetail model;
  String table;
  String id;
  dynamic data;
}

Future<Map<String, dynamic>> computeSendYamlChangeEvent(
  Map<String, dynamic> event,
) async {
  String id = event['id'];
  String old = event['old'] ?? '';
  String value = event['value'];
  DiffMatchPatch dmp = DiffMatchPatch();
  List<Patch> patch = dmp.patch(old, value);

  String textPatch = patchToText(patch);
  return Future.value({
    'type': 'YAML',
    'id': id,
    'patch': textPatch,
    'old': old,
    'new': value,
  });
}
