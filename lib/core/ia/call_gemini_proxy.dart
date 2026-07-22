import 'package:dio/dio.dart';

Future<String> callGeminiProxy(
  String prompt, {
  CancelToken? cancelToken,
}) async {
  const proxyUrl = 'http://localhost:3128/callGemini';

  final dio = Dio(
    BaseOptions(validateStatus: (_) => true, receiveDataWhenStatusError: true),
  );

  try {
    final response = await dio.post(
      proxyUrl,
      cancelToken: cancelToken,
      options: Options(headers: {'Content-Type': 'application/json'}),
      data: {'prompt': prompt},
    );

    final status = response.statusCode ?? 500;
    if (status < 200 || status >= 300) {
      throw StateError('Gemini proxy returned HTTP $status: ${response.data}');
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Gemini proxy returned an invalid JSON response.');
    }

    final answer = data['answer'];
    if (answer is String && answer.isNotEmpty) {
      return answer;
    }

    throw StateError('Gemini proxy response does not contain a valid answer.');
  } on DioException catch (e) {
    if (CancelToken.isCancel(e)) {
      print('Gemini proxy request cancelled');
      throw StateError('Gemini proxy request cancelled');
    }
    print('Unexpected error while calling Gemini proxy: $e');
    throw StateError('Unexpected error while calling Gemini proxy.');
  } catch (e) {
    print('Unexpected error while calling Gemini proxy: $e');
    throw StateError('Unexpected error while calling Gemini proxy.');
  }
}
