import 'package:web/web.dart' as web;

Future<bool> resetSharedPreferencesFile() async {
  final storage = web.window.localStorage;
  final preferenceKeys = <String>[];

  for (var index = 0; index < storage.length; index++) {
    final key = storage.key(index);
    if (key != null && key.startsWith('flutter.')) {
      preferenceKeys.add(key);
    }
  }

  for (final key in preferenceKeys) {
    storage.removeItem(key);
  }

  return true;
}
