
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

  dynamic call(APICallInfo info) async {
    final options = BaseOptions(
      connectTimeout: Duration(seconds: 30),
      receiveTimeout: Duration(seconds: 30),
    );
    final aDio = Dio(options);

    String url = info.url;
    int nbPathParam = 0;
    for (var element in info.params) {
      if (element.type == 'path') {
        url = url.replaceAll('{${element.name}}', element.value ?? '');
      } else if (element.type == 'query') {
        if (nbPathParam == 0) {
          url = '$url?${element.name}=${element.value}';
        } else {
          url = '$url&${element.name}=${element.value}';
        }
        nbPathParam++;
      }
    }

    try {
      final response = await aDio.request(
        url,
        data: info.body,
        options: Options(
          method: info.httpOperation,
          contentType: 'application/json',
          validateStatus: (status) {
            return status != null && status >= 200 && status < 300;
          },
        ),
      );
      print('response $response');
      return response.data;
    } on DioException catch (e) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx and is also not 304.
      if (e.response != null) {
        // print(e.response!.data);
        // print(e.response!.headers);
        // print(e.response!.requestOptions);
        // print(e.response!.statusCode);
        // print(e.response!.statusMessage);
        return {
          'message': e.message,
          'statusCode': e.response!.statusCode,
          'statusMessage': e.response!.statusMessage,
        };
      } else {
        // Something happened in setting up or sending the request that triggered an Error
        print(e.requestOptions);
        print(e.message);
        return {'message': e.message};
      }
    }
  }
}
