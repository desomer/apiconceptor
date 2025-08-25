import 'package:jsonschema/feature/api/pan_api_request.dart';

// ignore: must_be_immutable
class PanApiDocResponse extends PanRequestApi {
  PanApiDocResponse({super.key, required super.getSchemaFct, super.showable});

  @override
  bool withEditor() {
    return false;
  }

  @override
  bool isReadOnly() {
    return true;
  }
}
