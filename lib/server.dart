import 'dart:io';

import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/export/export2json_fake.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_md_doc.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

HttpServer? server;

void startServer() async {
  if (server != null) return;

  var handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(_echoRequest);

  server = await shelf_io.serve(handler, 'localhost', 1234);

  // Enable content compression
  server!.autoCompress = true;

  print('Serving at http://${server!.address.host}:${server!.port}');
}

Future<Response> _echoRequest(Request request) async {
  AttributInfo? apiInfo;
  List<String> appApi = [];

  //currentCompany.listAPI.mapInfoByJsonPath.forEach((key, value)
  for (var element in currentCompany.listAPI!.mapInfoByJsonPath.entries) {
    var value = element.value;
    if (value.type == 'ope') {
      var paths = value.path.split('>');
      StringBuffer api = StringBuffer();
      paths.getRange(1, paths.length - 1).forEach((element) {
        if (api.length > 0) api.write('/');
        api.write(element);
      });
      appApi.add(api.toString());
      if (api.toString() == request.url.toString()) {
        print("api $api");
        apiInfo = value;
        break;
      }
    }
  }
  if (apiInfo != null) {
    var key = apiInfo.masterID!;
    var currentModel = ModelSchema(
      category: Category.model,
      infoManager: InfoManagerModel(typeMD: TypeMD.model),
      headerName: apiInfo.name,
      id: 'response/$key',
    );
    if (withBdd) {
      await currentModel.loadYamlAndProperties(
        cache: true,
        withProperties: true,
      );
    }

    var export = Export2FakeJson();
    await export.browseSync(currentModel, false, 0);
    var json = export.prettyPrintJson(export.json['200'] ?? {});

    return Response.ok(json, headers: {'Content-Type': 'application/json; charset=utf-8'},);
  }
  if (request.url.toString() == 'all/api') {
    var html = StringBuffer();
    html.write('<ul>');
    for (var element in appApi) {
      html.write(
        '<li><a href="http://localhost:1234/$element">$element</a></li>',
      );
    }
    html.write('</ul>');
    return Response.ok(
      '<html>$html</html>',
      headers: {'Content-Type': 'text/html; charset=utf-8'},
    );
  }

  return Response.ok('Request error for "${request.url}"');
}
