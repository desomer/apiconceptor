import 'package:dio/dio.dart';

Future<String> callGemini(String prompt, {CancelToken? cancelToken}) async {
  final apiKey = const String.fromEnvironment('GEMINI_API_KEY');
  if (apiKey.isEmpty) {
    throw Exception('GEMINI_API_KEY environment variable is not set');
  }
  const interactionsUrl =
      'https://generativelanguage.googleapis.com/v1beta/interactions';
  const models = <String>[
    'gemini-3.5-flash',
    'gemini-3.1-flash-lite',
    'gemini-flash-latest',
  ];
  // final generateContentUrls = models
  //     .map(
  //       (model) =>
  //           'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
  //     )
  //     .toList();

  final dio = Dio(
    BaseOptions(validateStatus: (_) => true, receiveDataWhenStatusError: true),
  );

  try {
    //Map<String, dynamic>? lastInteractionsError;

    for (final model in models) {
      final interactionsResponse = await dio.post(
        interactionsUrl,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            'x-goog-api-key': apiKey,
            'Content-Type': 'application/json',
            'Api-Revision': '2026-05-20',
          },
        ),
        data: {'model': model, 'input': prompt, 'store': false},
      );

      if ((interactionsResponse.statusCode ?? 500) >= 200 &&
          (interactionsResponse.statusCode ?? 500) < 300) {
        final data = interactionsResponse.data as Map<String, dynamic>;

        final outputText = data['output_text'];
        if (outputText is String && outputText.isNotEmpty) {
          return outputText;
        }

        final steps = data['steps'];
        if (steps is List) {
          for (var i = steps.length - 1; i >= 0; i--) {
            final step = steps[i];
            if (step is! Map<String, dynamic>) {
              continue;
            }
            final content = step['content'];
            if (content is! List) {
              continue;
            }
            for (var j = content.length - 1; j >= 0; j--) {
              final part = content[j];
              if (part is! Map<String, dynamic>) {
                continue;
              }
              if (part['type'] == 'text') {
                final text = part['text'];
                if (text is String && text.isNotEmpty) {
                  return text;
                }
              }
            }
          }
        }

        throw StateError('No text output found in Interactions API response.');
      }

      // lastInteractionsError = {
      //   'model': model,
      //   'status': interactionsResponse.statusCode,
      //   'body': interactionsResponse.data,
      // };
    }

    //   for (final url in generateContentUrls) {
    //     final fallbackResponse = await dio.post(
    //       url,
    //       options: Options(headers: {'Content-Type': 'application/json'}),
    //       data: {
    //         'contents': [
    //           {
    //             'parts': [
    //               {'text': prompt},
    //             ],
    //           },
    //         ],
    //       },
    //     );

    //     if ((fallbackResponse.statusCode ?? 500) >= 200 &&
    //         (fallbackResponse.statusCode ?? 500) < 300) {
    //       final fallbackData = fallbackResponse.data as Map<String, dynamic>;
    //       final text =
    //           fallbackData['candidates']?[0]?['content']?['parts']?[0]?['text'];
    //       if (text is String && text.isNotEmpty) {
    //         return text;
    //       }
    //     }
    //   }

    //   throw Exception(
    //     'Gemini API failed on Interactions and fallbacks. Last Interactions error: $lastInteractionsError',
    //   );
  } on DioException catch (e) {
    if (CancelToken.isCancel(e)) {
      print('Gemini request cancelled');
      throw StateError('Gemini request cancelled');
    }
    print('Unexpected error while calling Gemini API: $e');
    throw StateError('Unexpected error while calling Gemini API.');
  } catch (e) {
    print('Unexpected error while calling Gemini API: $e');
    throw StateError('Unexpected error while calling Gemini API.');
  }
  throw StateError('No text output found in Interactions API response.');
}
