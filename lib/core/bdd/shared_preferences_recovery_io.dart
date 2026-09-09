import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<bool> resetSharedPreferencesFile() async {
  final directory = await getApplicationSupportDirectory();
  final preferencesFile = File(
    '${directory.path}${Platform.pathSeparator}shared_preferences.json',
  );

  if (await preferencesFile.exists()) {
    await preferencesFile.delete();
  }

  return true;
}
