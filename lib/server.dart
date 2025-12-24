import 'dart:io';

import 'package:jsonschema/core/api/call_api_manager.dart';
//import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/json_browser/browse_api.dart';
import 'package:jsonschema/start_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

HttpServer? server;
List<String> appApi = [];

void startServer() async {
  if (server != null) return;

  var handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(_echoRequest);

  server = await shelf_io.serve(handler, 'localhost', 1234);

  // Enable content compression
  server!.autoCompress = true;

  print('Serving at http://${server!.address.host}:${server!.port}');

  currentCompany.listDomain.mapInfoByTreePath.forEach((key, value) {
    var namespace = value.masterID!;
    loadAllAPI(namespace: namespace).then((modelApi) async {
      var b = BrowseAPI();
      await b.browseSync(modelApi, false, 20);
      modelApi.mapInfoByTreePath.forEach((key, api) {
        if (api.type == 'ope') {
          String httpOpe = api.name.toLowerCase();
          var apiCallInfo = APICallManager(
            namespace: namespace,
            attrApi: api,
            httpOperation: httpOpe,
          );
          String url = apiCallInfo.getURLfromNode(
            modelApi.nodeByMasterId[api.masterID!]!,
          );
          apiCallInfo.requestVariableValue['base_url'] =
              'http://localhost:1234/';
          url = apiCallInfo.replaceVarInRequest(url);
          appApi.add(url);
        }
      });
    });
  });
}

Future<Response> _echoRequest(Request request) async {
  //AttributInfo? apiInfo;

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
