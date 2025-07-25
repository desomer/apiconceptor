import 'dart:io';

import 'package:dio/dio.dart';
import 'package:jsonschema/feature/api/pan_api_editor.dart';

class CallerApi {
  dynamic callGraph() async {
    final options = BaseOptions(
      connectTimeout: Duration(seconds: 30),
      receiveTimeout: Duration(seconds: 30),
    );
    final aDio = Dio(options);
    try {
      final response = await aDio.request(
        'https://spacex-production.up.railway.app/',
        data:
            "{\"query\":\"query ExampleQuery {\\n  company {\\n    ceo\\n  }\\n  roadster {\\n    apoapsis_au\\n  }\\n}\\n\",\"variables\":{},\"operationName\":\"ExampleQuery\"}",
        options: Options(method: 'POST', contentType: 'application/json'),
      );
      print(response);
    } on DioException catch (e) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx and is also not 304.
      if (e.response != null) {
        print(e.response!.data);
        print(e.response!.headers);
        print(e.response!.requestOptions);
      } else {
        // Something happened in setting up or sending the request that triggered an Error
        print(e.requestOptions);
        print(e.message);
      }
    }
  }

  String? getEscapeUrl(String? param) {
    if (param == null) return null;
    return Uri.encodeComponent(param);
  }

  Future<APIResponse> call(APICallInfo info, CancelToken cancelToken) async {
    final options = BaseOptions(
      connectTimeout: Duration(seconds: 30),
      receiveTimeout: Duration(seconds: 30),
    );
    final aDio = Dio(options);

    String url = info.url;
    int nbPathParam = 0;
    for (var element in info.params) {
      if (element.type == 'path') {
        url = url.replaceAll('{${element.name}}', getEscapeUrl(element.value) ?? '');
      } else if (element.type == 'query' && element.toSend) {
        if (nbPathParam == 0) {
          url = '$url?${element.name}=${getEscapeUrl(element.value)}';
        } else {
          url = '$url&${element.name}=${getEscapeUrl(element.value)}';
        }
        nbPathParam++;
      }
    }

    var stopWatch = Stopwatch();
    stopWatch.start();
    late APIResponse apiResponse;
    int size = 0;
    try {
      final response = await aDio.request(
        url,
        data: info.body,
        cancelToken: cancelToken,
        onReceiveProgress: (actualBytes, totalBytes) {
          print('$actualBytes /  $totalBytes');
          size = actualBytes;
        },
        options: Options(
          method: info.httpOperation,
          contentType: 'application/json',
          //responseType: ResponseType.plain,
          validateStatus: (status) {
            return status != null && status >= 200 && status < 300;
          },
        ),
      );
      stopWatch.stop();
      apiResponse = APIResponse(reponse: response);
      apiResponse.size = size;
      apiResponse.duration = stopWatch.elapsed.inMilliseconds;
      print('h ${response.headers}');
      //return apiResponse;
    } on DioException catch (e) {
      stopWatch.stop();
      apiResponse = APIResponse(reponse: e.response);
      apiResponse.size = size;
      apiResponse.duration = stopWatch.elapsed.inMilliseconds;
      if (e.response != null) {
        // print(e.response!.data);
        // print(e.response!.headers);
        // print(e.response!.requestOptions);
        // print(e.response!.statusCode);
        // print(e.response!.statusMessage);
        // if (e.response!.data==null || e.response!.data=='') {
        //   apiResponse.toDisplay = {
        //   'message': 'this data is generated by me',
        //   'statusCode': e.response!.statusCode,
        //   'statusMessage': e.response!.statusMessage,
        // };
        // }
        // return apiResponse;
      } else {
        print(e.requestOptions);
        print(e.message);
        apiResponse.toDisplay = {'message': e.message};
        // return apiResponse;
      }
    }
    var contentTypeStr = apiResponse.reponse?.headers['content-type'];
    if (contentTypeStr != null && contentTypeStr.isNotEmpty) {
      var ct = ContentType.parse(contentTypeStr.first);
      apiResponse.contentType = ct;
    }
    return apiResponse;
  }
}

class APIResponse {
  final Response? reponse;
  dynamic toDisplay;
  int duration = 0;
  int size = 0;
  ContentType? contentType;

  APIResponse({required this.reponse});
}
